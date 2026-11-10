import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/core/models.dart';
import 'package:fieldkit/data/database.dart';
import 'package:fieldkit/services/packs.dart';
import 'helpers.dart';

/// Test-only transport sends production-shaped HTTPS URLs to a local HTTP server.
/// Production never disables TLS or accepts HTTP URLs.
class LoopbackClient implements HttpClient {
  final HttpClient inner = HttpClient();
  final Uri uri;
  LoopbackClient(this.uri);
  @override
  Future<HttpClientRequest> getUrl(Uri _) => inner.getUrl(uri);
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

(Pack, File) fixture(
  Directory dir, {
  String id = 'sample',
  String version = '1',
  String? badPath,
  List<Article>? articles,
}) {
  final files = <String, List<int>>{
    'articles.json': utf8.encode(
      jsonEncode(
        (articles ??
                [
                  Article({...seedArticles().first.data, 'id': 'optional'}),
                ])
            .map((a) => a.data)
            .toList(),
      ),
    ),
  };
  if (badPath != null) files[badPath] = utf8.encode('unsafe');
  final manifest = {
    'schema_version': 1,
    'id': id,
    'version': version,
    'kind': 'content',
    'files': {
      for (final e in files.entries) e.key: sha256.convert(e.value).toString(),
    },
  };
  files['manifest.json'] = utf8.encode(jsonEncode(manifest));
  final archive = Archive();
  for (final e in files.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  final bytes = ZipEncoder().encode(archive);
  final file = File('${dir.path}/$id-$version.zip')..writeAsBytesSync(bytes);
  return (
    Pack(
      id: id,
      title: 'Fixture',
      version: version,
      language: 'en',
      kind: 'content',
      url: 'https://example.invalid/pack.zip',
      sha256: sha256.convert(bytes).toString(),
      downloadBytes: bytes.length,
      installedBytes: files.values.fold(0, (sum, b) => sum + b.length),
      description: 'Fixture',
    ),
    file,
  );
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late PackService service;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('fieldkit-pack-');
    db = AppDatabase.memory();
    service = PackService(
      db,
      Directory('${dir.path}/packs'),
      allowDrafts: true,
      availableBytes: () async => 100000000,
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });
  test('[T10] reject corrupt ZIP before activation', () async {
    final (pack, file) = fixture(dir);
    file.writeAsStringSync('corrupt');
    await expectLater(
      service.installVerified(pack, file),
      throwsFormatException,
    );
    expect(await db.installedPacks(), isEmpty);
  });
  test(
    '[T10] reject archive traversal and cross-pack article collisions',
    () async {
      final (pack, file) = fixture(dir, badPath: '../escape.json');
      await expectLater(
        service.installVerified(pack, file),
        throwsFormatException,
      );
      expect(File('${dir.path}/escape.json').existsSync(), false);
      await db.installArticles('essential', seedArticles());
      final (other, otherFile) = fixture(
        dir,
        id: 'collision',
        articles: [seedArticles().first],
      );
      await expectLater(
        service.installVerified(other, otherFile),
        throwsStateError,
      );
      expect(await db.article('prepare', 'en'), isNotNull);
    },
  );
  test('[T11] failed replacement leaves previous pack active', () async {
    final (first, file) = fixture(dir);
    await service.installVerified(first, file);
    final (next, bad) = fixture(
      dir,
      version: '2',
      articles: [
        Article({...seedArticles().first.data, 'id': 'optional', 'title': ''}),
      ],
    );
    await expectLater(
      service.installVerified(next, bad),
      throwsFormatException,
    );
    expect((await db.installedPacks()).single['version'], '1');
    expect(await db.article('optional', 'en'), isNotNull);
  });
  test('[T14] integrity reports missing resources', () async {
    final (pack, file) = fixture(dir);
    await service.installVerified(pack, file);
    final root = (await db.installedPacks()).single['path'] as String;
    expect(await service.verifyInstalled(root), true);
    File('$root/articles.json').deleteSync();
    expect(await service.verifyInstalled(root), false);
  });
  test('[T17] production refuses draft pack', () async {
    final production = PackService(db, Directory('${dir.path}/production'));
    final (pack, file) = fixture(dir);
    await expectLater(production.installVerified(pack, file), throwsStateError);
  });
  test('[T17] changing reviewed text invalidates production approval', () {
    final article = Article({
      ...seedArticles().first.data,
      'review_status': 'approved',
      'translation_review': 'approved',
      'reviewer': 'Automated fixture, not a clinical review',
      'reviewed_at': '2026-10-20',
      'license': 'Test fixture',
    });
    article.data['reviewed_content_sha256'] = PackService.reviewDigest(article);
    PackService.validateArticle(article, allowDrafts: false);
    article.data['title'] = 'Changed after review';
    expect(
      () => PackService.validateArticle(article, allowDrafts: false),
      throwsStateError,
    );
  });
  test(
    '[T11] cleanup removes stale versions but preserves the active pack',
    () async {
      final (first, firstFile) = fixture(dir);
      await service.installVerified(first, firstFile);
      final oldPath = (await db.installedPacks()).single['path'] as String;
      final (next, nextFile) = fixture(dir, version: '2');
      await service.installVerified(next, nextFile);
      final activePath = (await db.installedPacks()).single['path'] as String;
      expect(await service.clearUnused(), greaterThan(0));
      expect(Directory(oldPath).existsSync(), false);
      expect(await service.verifyInstalled(activePath), true);
      expect(await db.article('optional', 'en'), isNotNull);
    },
  );
  test(
    '[T08] HTTP range resumes a partial archive and verifies full content',
    () async {
      final (pack, file) = fixture(dir);
      final bytes = await file.readAsBytes();
      await service.root.create(recursive: true);
      final offset = bytes.length ~/ 2;
      final partial = File(
        '${service.root.path}/${pack.id}-${pack.version}-${pack.sha256}.part',
      );
      await partial.writeAsBytes(bytes.sublist(0, offset));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? requestedRange;
      server.listen((request) async {
        requestedRange = request.headers.value('range');
        request.response.statusCode = 206;
        request.response.headers.set(
          'content-range',
          'bytes $offset-${bytes.length - 1}/${bytes.length}',
        );
        request.response.add(bytes.sublist(offset));
        await request.response.close();
      });
      final network = PackService(
        db,
        service.root,
        allowDrafts: true,
        availableBytes: () async => 100000000,
        clientFactory: () =>
            LoopbackClient(Uri.parse('http://127.0.0.1:${server.port}/pack')),
      );
      try {
        await network.download(
          pack,
          budgetBytes: 100000000,
          cancel: CancelDownload(),
          progress: (_) {},
          networkAllowed: () async => true,
        );
        expect(requestedRange, 'bytes=$offset-');
        expect((await db.installedPacks()).single['id'], 'sample');
        expect(await partial.exists(), false);
      } finally {
        await server.close(force: true);
      }
    },
  );
  test('[T08] server ignoring Range restarts safely', () async {
    final (pack, file) = fixture(dir);
    final bytes = await file.readAsBytes();
    await service.root.create(recursive: true);
    await File(
      '${service.root.path}/${pack.id}-${pack.version}-${pack.sha256}.part',
    ).writeAsBytes(bytes.sublist(0, 20));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(bytes);
      await request.response.close();
    });
    final network = PackService(
      db,
      service.root,
      allowDrafts: true,
      availableBytes: () async => 100000000,
      clientFactory: () =>
          LoopbackClient(Uri.parse('http://127.0.0.1:${server.port}/pack')),
    );
    try {
      await network.download(
        pack,
        budgetBytes: 100000000,
        cancel: CancelDownload(),
        progress: (_) {},
        networkAllowed: () async => true,
      );
      expect((await db.installedPacks()).length, 1);
    } finally {
      await server.close(force: true);
    }
  });
  test('[T09] network restriction prevents download', () async {
    final (pack, _) = fixture(dir);
    await expectLater(
      service.download(
        pack,
        budgetBytes: 100000000,
        cancel: CancelDownload(),
        progress: (_) {},
        networkAllowed: () async => false,
      ),
      throwsStateError,
    );
    expect(await db.installedPacks(), isEmpty);
  });
  test('[T09] cancellation never activates an incomplete package', () async {
    final (pack, file) = fixture(dir);
    final bytes = await file.readAsBytes();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(bytes);
      await request.response.close();
    });
    final network = PackService(
      db,
      service.root,
      allowDrafts: true,
      availableBytes: () async => 100000000,
      clientFactory: () =>
          LoopbackClient(Uri.parse('http://127.0.0.1:${server.port}/pack')),
    );
    final cancel = CancelDownload()..cancel();
    try {
      await expectLater(
        network.download(
          pack,
          budgetBytes: 100000000,
          cancel: cancel,
          progress: (_) {},
          networkAllowed: () async => true,
        ),
        throwsA(isA<PackCancelled>()),
      );
      expect(await db.installedPacks(), isEmpty);
    } finally {
      await server.close(force: true);
    }
  });
  test(
    '[T12] insufficient free space or budget rejects before network write',
    () async {
      final (pack, _) = fixture(dir);
      final low = PackService(
        db,
        service.root,
        allowDrafts: true,
        availableBytes: () async => 0,
      );
      await expectLater(
        low.download(
          pack,
          budgetBytes: 100000000,
          cancel: CancelDownload(),
          progress: (_) {},
          networkAllowed: () async => true,
        ),
        throwsStateError,
      );
      await expectLater(
        service.download(
          pack,
          budgetBytes: 1,
          cancel: CancelDownload(),
          progress: (_) {},
          networkAllowed: () async => true,
        ),
        throwsStateError,
      );
      expect(await db.installedPacks(), isEmpty);
    },
  );
}
