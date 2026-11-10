import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../core/models.dart';
import '../data/database.dart';

class PackCancelled implements Exception {}

class CancelDownload {
  bool cancelled = false;
  void cancel() => cancelled = true;
  void check() {
    if (cancelled) throw PackCancelled();
  }
}

/// Immutable version directories plus a transactional DB pointer provide atomic
/// activation. Partial downloads remain resumable, never searchable or "ready".
class PackService {
  final AppDatabase db;
  final Directory root;
  final bool allowDrafts;
  final Future<int> Function()? availableBytes;
  final HttpClient Function()? clientFactory;
  bool _busy = false;
  PackService(
    this.db,
    this.root, {
    this.allowDrafts = false,
    this.availableBytes,
    this.clientFactory,
  });

  static bool safeId(String id) =>
      RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(id) && !id.contains('..');
  static const maxArchiveBytes = 512 * 1024 * 1024;
  static const maxExpandedBytes = 1024 * 1024 * 1024;
  static void validatePack(Pack pack) {
    if (!safeId(pack.id) ||
        !safeId(pack.version) ||
        pack.id == 'essential' ||
        !['content', 'map'].contains(pack.kind) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(pack.sha256) ||
        pack.downloadBytes <= 0 ||
        pack.downloadBytes > maxArchiveBytes ||
        pack.installedBytes <= 0 ||
        pack.installedBytes > maxExpandedBytes) {
      throw const FormatException('Invalid pack manifest');
    }
  }

  Future<int> diskBytes() async {
    if (availableBytes != null) return availableBytes!();
    // iOS volume resource queries require an existing URL on first launch.
    await root.create(recursive: true);
    final bytes = await const MethodChannel(
      'org.fieldkit/storage',
    ).invokeMethod<int>('availableBytes', {'path': root.path});
    if (bytes == null) throw StateError('Cannot verify free storage');
    return bytes;
  }

  Future<int> usedBytes() async {
    // JSON stored in SQLite also consumes the user's offline-content budget.
    final saved = await db
        .customSelect(
          "SELECT COALESCE(SUM(length(CAST(body AS BLOB))),0) AS bytes FROM articles WHERE pack_id LIKE 'wiki:%'",
        )
        .getSingle();
    var total = saved.read<int>('bytes');
    if (!root.existsSync()) return total;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<List<Pack>> catalog() async {
    const url = String.fromEnvironment('PACK_CATALOG_URL');
    if (url.isEmpty) {
      final j = jsonDecode(
        await rootBundle.loadString('assets/content/catalog.json'),
      );
      return (j['packs'] as List).map((e) => Pack.fromJson(e)).toList();
    }
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') throw StateError('Catalog requires HTTPS');
    final client = (clientFactory?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException('Catalog HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(part);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('Catalog too large');
        }
      }
      final j = jsonDecode(utf8.decode(bytes));
      if (j['schema_version'] != 1) {
        throw const FormatException('Unsupported catalog');
      }
      final result = (j['packs'] as List).map((e) => Pack.fromJson(e)).toList();
      for (final pack in result) {
        validatePack(pack);
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> download(
    Pack pack, {
    required int budgetBytes,
    required CancelDownload cancel,
    required void Function(double) progress,
    required Future<bool> Function() networkAllowed,
  }) async {
    validatePack(pack);
    if (_busy) throw StateError('Another pack operation is active');
    _busy = true;
    final client = (clientFactory?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      cancel.check();
      if (!await networkAllowed()) {
        throw StateError('Connect to Wi-Fi or change download settings');
      }
      final uri = Uri.parse(pack.url);
      if (uri.scheme != 'https') {
        throw const FormatException('Downloads require HTTPS');
      }
      await root.create(recursive: true);
      final partial = File(
        p.join(root.path, '${pack.id}-${pack.version}-${pack.sha256}.part'),
      );
      var offset = partial.existsSync() ? await partial.length() : 0;
      if (offset > pack.downloadBytes) {
        await partial.delete();
        offset = 0;
      }
      final used = await usedBytes();
      final needed =
          pack.downloadBytes - offset + pack.installedBytes + 8 * 1024 * 1024;
      if (used + needed > budgetBytes) {
        throw StateError('Storage budget exceeded, including update workspace');
      }
      if (await diskBytes() < needed) {
        throw StateError('Not enough free device storage');
      }
      if (offset < pack.downloadBytes) {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        if (offset > 0) request.headers.set('Range', 'bytes=$offset-');
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw HttpException('Download HTTP ${response.statusCode}');
        }
        if (response.statusCode == 206 &&
            !(response.headers.value('content-range') ?? '').startsWith(
              'bytes $offset-',
            )) {
          throw const FormatException('Invalid resumed range');
        }
        if (response.statusCode == 200) offset = 0;
        final sink = partial.openWrite(
          mode: offset == 0 ? FileMode.write : FileMode.append,
        );
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            cancel.check();
            if (!await networkAllowed()) {
              throw StateError('Download paused: network changed');
            }
            offset += chunk.length;
            if (offset > pack.downloadBytes) {
              throw const FormatException('Unexpected download length');
            }
            sink.add(chunk);
            progress(offset / pack.downloadBytes);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }
      cancel.check();
      if (await partial.length() != pack.downloadBytes ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              pack.sha256) {
        await partial.delete();
        throw const FormatException('Package checksum or length mismatch');
      }
      await installVerified(pack, partial, cancel: cancel);
      await partial.delete();
    } finally {
      client.close(force: true);
      _busy = false;
    }
  }

  /// Also used by fixtures and tests. Always verifies bytes independently.
  Future<void> installVerified(
    Pack pack,
    File file, {
    CancelDownload? cancel,
  }) async {
    validatePack(pack);
    if (await file.length() != pack.downloadBytes ||
        (await sha256.bind(file.openRead()).first).toString() != pack.sha256) {
      throw const FormatException('Package checksum mismatch');
    }
    // Decode from disk without keeping large map archives in memory.
    final input = InputFileStream(file.path);
    final stage = Directory(p.join(root.path, '.staging-${pack.id}'));
    if (stage.existsSync()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var expanded = 0;
      final names = <String>{};
      for (final entry in archive) {
        cancel?.check();
        final name = entry.name;
        if (!entry.isFile || entry.isSymbolicLink) {
          throw const FormatException('Only regular files allowed');
        }
        if (p.isAbsolute(name) ||
            name.contains('\\') ||
            name.split('/').any((v) => v == '..' || v.isEmpty) ||
            name.contains(':') ||
            !names.add(name)) {
          throw const FormatException('Unsafe archive path');
        }
        if (![
          '.json',
          '.svg',
          '.png',
          '.webp',
          '.jpg',
          '.pmtiles',
          '.pbf',
        ].contains(p.extension(name))) {
          throw const FormatException('Unsupported package file');
        }
        expanded += entry.size;
        if (expanded > pack.installedBytes || expanded > maxExpandedBytes) {
          throw const FormatException('Archive expansion limit');
        }
        final out = OutputFileStream(p.join(stage.path, name));
        try {
          entry.writeContent(out);
        } finally {
          out.closeSync();
        }
        if (await File(p.join(stage.path, name)).length() != entry.size) {
          throw const FormatException('Expanded size mismatch');
        }
      }
      if (expanded != pack.installedBytes) {
        throw const FormatException('Incorrect installed size');
      }
      final manifestFile = File(p.join(stage.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString());
      if (manifest['schema_version'] != 1 ||
          manifest['id'] != pack.id ||
          manifest['version'] != pack.version ||
          manifest['kind'] != pack.kind) {
        throw const FormatException('Package identity mismatch');
      }
      final fileHashes = manifest['files'] as Map<String, dynamic>?;
      if (fileHashes == null ||
          fileHashes.length != names.length - 1 ||
          !fileHashes.keys.every(
            (name) => name != 'manifest.json' && names.contains(name),
          ) ||
          !await verifyInstalled(stage.path)) {
        throw const FormatException(
          'Package resource manifest is incomplete or invalid',
        );
      }
      var articles = <Article>[];
      if (pack.kind == 'content') {
        final articleFile = File(p.join(stage.path, 'articles.json'));
        if (await articleFile.length() > 8 * 1024 * 1024) {
          throw const FormatException('Article file too large');
        }
        final body = jsonDecode(await articleFile.readAsString()) as List;
        articles = body.map((j) => Article(j as Map<String, dynamic>)).toList();
        final ids = <String>{};
        for (final a in articles) {
          validateArticle(a, allowDrafts: allowDrafts);
          if (a.language != pack.language ||
              !ids.add('${a.id}:${a.language}')) {
            throw const FormatException('Duplicate article or wrong language');
          }
          for (final asset in a.strings('illustrations')) {
            if (asset.startsWith('assets/')) continue;
            if (!names.contains(asset)) {
              throw const FormatException('Missing illustration');
            }
          }
          for (final media in a.data['media'] as List? ?? []) {
            if (media['required'] == true &&
                (fileHashes[media['path']] != media['sha256'] ||
                    media['sha256'] == null)) {
              throw const FormatException(
                'Required photograph does not match reviewed bytes',
              );
            }
          }
        }
      } else {
        final archiveFile = await File(
          p.join(stage.path, 'map.pmtiles'),
        ).open();
        final header = await archiveFile.read(127);
        await archiveFile.close();
        if (header.length != 127 ||
            utf8.decode(header.sublist(0, 7), allowMalformed: true) !=
                'PMTiles' ||
            header[7] != 3) {
          throw const FormatException('PMTiles v3 archive required');
        }
        final style =
            jsonDecode(
                  await File(p.join(stage.path, 'style.json')).readAsString(),
                )
                as Map<String, dynamic>;
        validateMapStyle(style, names);
      }
      cancel?.check();
      final target = Directory(
        p.join(root.path, '${pack.id}-${pack.version}-${pack.sha256}'),
      );
      if (target.existsSync()) {
        // Never overwrite an installed or rollback directory.
        throw StateError('This pack version already exists');
      }
      await stage.rename(target.path);
      try {
        await db.transaction(() async {
          if (pack.kind == 'content') {
            await db.installArticles(pack.id, articles);
          }
          await db.recordPack(pack, target.path, expanded);
        });
      } catch (_) {
        await target.delete(recursive: true);
        rethrow;
      }
    } finally {
      input.closeSync();
      if (stage.existsSync()) await stage.delete(recursive: true);
    }
  }

  static void validateArticle(Article a, {required bool allowDrafts}) {
    if (!safeId(a.id) ||
        !languages.containsKey(a.language) ||
        a.title.trim().isEmpty ||
        a.summary.trim().isEmpty ||
        a.sections.isEmpty ||
        a.strings('sources').isEmpty ||
        a.data['license'] == null ||
        a.data['region'] == null ||
        a.data['review_status'] == null) {
      throw const FormatException('Incomplete article');
    }
    for (final section in a.sections) {
      if (section['heading'] is! String ||
          section['steps'] is! List ||
          (section['steps'] as List).isEmpty ||
          !(section['steps'] as List).every(
            (s) => s is String && s.trim().isNotEmpty,
          )) {
        throw const FormatException('Invalid article section');
      }
      if (section['table'] != null) {
        final rows = section['table'];
        if (rows is! List ||
            rows.isEmpty ||
            rows.first is! List ||
            (rows.first as List).isEmpty ||
            !rows.every(
              (row) =>
                  row is List &&
                  row.length == (rows.first as List).length &&
                  row.every((cell) => cell is String),
            )) {
          throw const FormatException('Invalid article table');
        }
      }
    }
    if (a.data['food_identification'] == true) {
      final media = a.data['media'] as List? ?? [];
      if (media.isEmpty ||
          !media.every(
            (m) =>
                m is Map &&
                m['required'] == true &&
                m['kind'] == 'photograph' &&
                m['ai_generated'] == false &&
                (m['caption'] as String? ?? '').isNotEmpty &&
                (m['attribution'] as String? ?? '').isNotEmpty &&
                (m['license'] as String? ?? '').isNotEmpty &&
                RegExp(
                  r'^[a-f0-9]{64}$',
                ).hasMatch(m['sha256'] as String? ?? '') &&
                (m['source'] as String? ?? '').startsWith('https://') &&
                a.strings('illustrations').contains(m['path']),
          )) {
        throw const FormatException(
          'Food identification requires attributed reference photographs',
        );
      }
      if (!allowDrafts &&
          (a.data['photo_review'] != 'approved' ||
              a.data['specialist_review'] != 'approved' ||
              [
                'photo_reviewer',
                'photo_reviewed_at',
                'specialist_reviewer',
                'specialist_reviewed_at',
                'translation_reviewer',
                'translation_reviewed_at',
              ].any((key) => (a.data[key] as String? ?? '').trim().isEmpty))) {
        throw StateError(
          'Food reference requires specialist and photograph review',
        );
      }
    }
    if (!allowDrafts &&
        (a.review != 'approved' ||
            a.data['reviewer'] == null ||
            a.data['reviewed_at'] == null ||
            a.data['translation_review'] != 'approved' ||
            a.data['license'].toString().toLowerCase().contains('pending') ||
            a.data['reviewed_content_sha256'] != reviewDigest(a))) {
      throw StateError('Content requires independent review');
    }
  }

  /// Binds a human review record to its exact article version, not its ID alone.
  static String reviewDigest(Article article) {
    const metadata = {
      'review_status',
      'translation_review',
      'reviewer',
      'reviewed_at',
      'reviewed_content_sha256',
    };
    dynamic canonical(dynamic value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    final content = {
      for (final entry in article.data.entries)
        if (!metadata.contains(entry.key)) entry.key: entry.value,
    };
    return sha256
        .convert(utf8.encode(jsonEncode(canonical(content))))
        .toString();
  }

  static void validateMapStyle(Map<String, dynamic> style, Set<String> names) {
    if (style['version'] != 8 ||
        style['sources'] is! Map ||
        style['layers'] is! List) {
      throw const FormatException('Invalid map style');
    }
    for (final value in (style['sources'] as Map).values) {
      if (value is! Map ||
          value['type'] != 'vector' ||
          value['url'] != 'pmtiles://map.pmtiles' ||
          (value['attribution'] as String? ?? '').isEmpty) {
        throw const FormatException(
          'Map sources must use local attributed map.pmtiles',
        );
      }
    }
    if (!names.contains('map.pmtiles')) {
      throw const FormatException('Missing map archive');
    }
    if (style.containsKey('glyphs') || style.containsKey('sprite')) {
      // Explicit packaging contract: glyph/sprite sets must be local and complete.
      if (style.containsKey('glyphs') &&
          style['glyphs'] != 'glyphs/{fontstack}/{range}.pbf') {
        throw const FormatException('Glyphs must be local');
      }
      if (style.containsKey('sprite') && style['sprite'] != 'sprites/sprite') {
        throw const FormatException('Sprites must be local');
      }
      if (style.containsKey('glyphs') &&
          !names.any((n) => n.startsWith('glyphs/'))) {
        throw const FormatException('Missing glyphs');
      }
      if (style.containsKey('sprite') &&
          (!names.contains('sprites/sprite.json') ||
              !names.contains('sprites/sprite.png'))) {
        throw const FormatException('Missing sprites');
      }
    }
  }

  Future<void> remove(String id) async {
    if (_busy) throw StateError('A download is active');
    if (id == 'essential') {
      throw StateError('Essential handbook cannot be removed');
    }
    final packs = await db.installedPacks();
    final matches = packs.where((e) => e['id'] == id);
    if (matches.isEmpty) return;
    final path = matches.first['path'] as String;
    await db.removePack(id);
    if (p.isWithin(root.path, path) && Directory(path).existsSync()) {
      await Directory(path).delete(recursive: true);
    }
  }

  Future<int> clearUnused() async {
    if (_busy) throw StateError('A download is active');
    if (!await root.exists()) return 0;
    final active = (await db.installedPacks())
        .map((e) => p.normalize(e['path'] as String))
        .toSet();
    final before = await usedBytes();
    await for (final item in root.list(followLinks: false)) {
      if (active.contains(p.normalize(item.path))) continue;
      if (item is Directory) {
        await item.delete(recursive: true);
      } else if (item is File && item.path.endsWith('.part')) {
        await item.delete();
      }
    }
    return before - await usedBytes();
  }

  Future<bool> verifyInstalled(String directory) async {
    try {
      if (!p.isWithin(root.path, directory)) return false;
      final manifest = jsonDecode(
        await File(p.join(directory, 'manifest.json')).readAsString(),
      );
      final files = manifest['files'] as Map<String, dynamic>;
      if (files.isEmpty) return false;
      for (final entry in files.entries) {
        final path = p.normalize(p.join(directory, entry.key));
        if (!p.isWithin(directory, path)) return false;
        final file = File(path);
        if (!await file.exists() ||
            (await sha256.bind(file.openRead()).first).toString() !=
                entry.value) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
