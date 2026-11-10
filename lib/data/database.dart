import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../core/models.dart';

/// Drift owns transactions, lifecycle and migrations; SQL is explicit and
/// searchable in this file instead of relying on generated table classes.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);
  factory AppDatabase.file(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final sql in _schema) {
        await customStatement(sql);
      }
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) {
        await customStatement(
          'CREATE TABLE IF NOT EXISTS checklist (id TEXT PRIMARY KEY, done INTEGER NOT NULL)',
        );
      }
      if (from < 3) {
        for (final sql in _extensionSchema) {
          await customStatement(sql);
        }
      }
    },
  );

  static const _schema = [
    'CREATE TABLE articles (id TEXT NOT NULL, language TEXT NOT NULL, pack_id TEXT NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, level TEXT NOT NULL, body TEXT NOT NULL, PRIMARY KEY(id,language))',
    "CREATE VIRTUAL TABLE article_search USING fts5(id UNINDEXED, language UNINDEXED, text, tokenize='unicode61 remove_diacritics 2')",
    'CREATE TABLE bookmarks (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
    'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE TABLE packs (id TEXT PRIMARY KEY, version TEXT NOT NULL, kind TEXT NOT NULL, path TEXT NOT NULL, bytes INTEGER NOT NULL, hash TEXT NOT NULL)',
    'CREATE TABLE places (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL)',
    'CREATE TABLE checklist (id TEXT PRIMARY KEY, done INTEGER NOT NULL)',
    ..._extensionSchema,
  ];
  static const _extensionSchema = [
    'CREATE TABLE IF NOT EXISTS archives (id TEXT PRIMARY KEY, language TEXT NOT NULL, title TEXT NOT NULL, path TEXT NOT NULL, bytes INTEGER NOT NULL, metadata TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS download_jobs (id TEXT PRIMARY KEY, state TEXT NOT NULL, url TEXT NOT NULL, target TEXT NOT NULL, received INTEGER NOT NULL DEFAULT 0, total INTEGER, etag TEXT, error TEXT, updated_at TEXT NOT NULL)',
  ];

  Future<void> installArticles(String packId, List<Article> articles) =>
      transaction(() async {
        // Cross-pack identifiers may not overwrite another pack or the core.
        for (final a in articles) {
          final existing = await customSelect(
            'SELECT pack_id FROM articles WHERE id=? AND language=?',
            variables: [Variable(a.id), Variable(a.language)],
          ).getSingleOrNull();
          if (existing != null && existing.read<String>('pack_id') != packId) {
            throw StateError('Article ${a.id} belongs to another pack');
          }
        }
        await _removeArticles(packId);
        for (final a in articles) {
          await customStatement('INSERT INTO articles VALUES(?,?,?,?,?,?,?)', [
            a.id,
            a.language,
            packId,
            a.title,
            a.category,
            a.level,
            jsonEncode(a.data),
          ]);
          await customStatement(
            'INSERT INTO article_search(id,language,text) VALUES(?,?,?)',
            [a.id, a.language, a.searchText],
          );
        }
      });

  Future<void> _removeArticles(String id) async {
    await customStatement(
      'DELETE FROM article_search WHERE (id,language) IN (SELECT id,language FROM articles WHERE pack_id=?)',
      [id],
    );
    await customStatement('DELETE FROM articles WHERE pack_id=?', [id]);
  }

  Future<void> removePack(String id) async {
    if (id == 'essential') {
      throw StateError('Essential handbook cannot be removed');
    }
    await transaction(() async {
      await _removeArticles(id);
      await customStatement('DELETE FROM packs WHERE id=?', [id]);
    });
  }

  Future<List<Article>> articles(
    String language, {
    String query = '',
    String? category,
    String? level,
    bool bookmarksOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final words = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final clauses = <String>['a.language = ?'];
    final args = <Variable>[Variable(language)];
    if (words.isNotEmpty) {
      final match = words
          .map((w) => '"${w.replaceAll('"', '""')}"*')
          .join(' AND ');
      final escaped = query
          .trim()
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      clauses.add(
        "(a.id IN (SELECT id FROM article_search WHERE language=? AND article_search MATCH ?) OR a.title LIKE ? ESCAPE '\\')",
      );
      args.addAll([
        Variable(language),
        Variable(match),
        Variable('%$escaped%'),
      ]);
    }
    if (category != null) {
      clauses.add('a.category=?');
      args.add(Variable(category));
    }
    if (level != null) {
      clauses.add('a.level=?');
      args.add(Variable(level));
    }
    if (bookmarksOnly) clauses.add('a.id IN (SELECT id FROM bookmarks)');
    final rows = await customSelect(
      'SELECT a.body FROM articles a WHERE ${clauses.join(' AND ')} ORDER BY a.title LIMIT ? OFFSET ?',
      variables: [
        ...args,
        Variable(limit.clamp(1, 200)),
        Variable(offset < 0 ? 0 : offset),
      ],
    ).get();
    return rows.map((r) => Article.decode(r.read<String>('body'))).toList();
  }

  /// Atomic single-reference upsert. Other saved pages and personal bookmarks
  /// are never replaced when a Wikipedia revision changes.
  Future<void> saveReference(Article article) async {
    if (article.sourceKind != 'wikipedia' || !article.id.startsWith('wiki:')) {
      throw ArgumentError('Invalid external reference identity');
    }
    await installArticles(article.id, [article]);
  }

  Future<List<Article>> rankedArticles(
    String language,
    String query, {
    String? category,
    String? level,
    bool bookmarksOnly = false,
    int limit = 21,
    int offset = 0,
  }) async {
    final terms = query
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => '"${s.replaceAll('"', '""')}"*')
        .join(' AND ');
    if (terms.isEmpty) {
      return articles(
        language,
        category: category,
        level: level,
        bookmarksOnly: bookmarksOnly,
        limit: limit,
        offset: offset,
      );
    }
    final conditions = ['a.language=?', 'article_search MATCH ?'];
    final variables = <Variable>[Variable(language), Variable(terms)];
    if (category != null) {
      conditions.add('a.category=?');
      variables.add(Variable(category));
    }
    if (level != null) {
      conditions.add('a.level=?');
      variables.add(Variable(level));
    }
    if (bookmarksOnly) conditions.add('a.id IN (SELECT id FROM bookmarks)');
    final rows = await customSelect(
      'SELECT a.body FROM article_search JOIN articles a '
      'ON a.id=article_search.id AND a.language=article_search.language '
      'WHERE ${conditions.join(' AND ')} '
      'ORDER BY bm25(article_search), a.title LIMIT ? OFFSET ?',
      variables: [
        ...variables,
        Variable(limit.clamp(1, 200)),
        Variable(offset < 0 ? 0 : offset),
      ],
    ).get();
    return rows.map((r) => Article.decode(r.read<String>('body'))).toList();
  }

  Future<Article?> article(String id, String language) async {
    final row = await customSelect(
      'SELECT body FROM articles WHERE id=? AND language=?',
      variables: [Variable(id), Variable(language)],
    ).getSingleOrNull();
    return row == null ? null : Article.decode(row.read<String>('body'));
  }

  Future<Set<String>> bookmarks() async => (await customSelect(
    'SELECT id FROM bookmarks',
  ).get()).map((r) => r.read<String>('id')).toSet();
  Future<void> toggleBookmark(Article a) async {
    if ((await bookmarks()).contains(a.id)) {
      await customStatement('DELETE FROM bookmarks WHERE id=?', [a.id]);
    } else {
      await customStatement('INSERT INTO bookmarks VALUES(?,?)', [
        a.id,
        a.title,
      ]);
    }
  }

  Future<AppPreferences> preferences() async {
    final row = await customSelect(
      "SELECT value FROM preferences WHERE key='app'",
    ).getSingleOrNull();
    return row == null
        ? const AppPreferences()
        : AppPreferences.fromJson(jsonDecode(row.read<String>('value')));
  }

  Future<void> savePreferences(AppPreferences p) => customStatement(
    "INSERT OR REPLACE INTO preferences VALUES('app',?)",
    [jsonEncode(p.toJson())],
  );
  Future<List<Map<String, Object?>>> installedPacks() async =>
      (await customSelect(
        'SELECT * FROM packs',
      ).get()).map((r) => r.data).toList();
  Future<void> recordPack(Pack p, String path, int size) => customStatement(
    'INSERT OR REPLACE INTO packs VALUES(?,?,?,?,?,?)',
    [p.id, p.version, p.kind, path, size, p.sha256],
  );
  Future<List<SavedPlace>> places() async =>
      (await customSelect('SELECT * FROM places ORDER BY id DESC').get())
          .map(
            (r) => SavedPlace(
              r.read<int>('id'),
              r.read<String>('name'),
              r.read<double>('latitude'),
              r.read<double>('longitude'),
            ),
          )
          .toList();
  Future<void> savePlace(String name, double lat, double lon) async {
    if (name.trim().isEmpty ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      throw ArgumentError('Invalid place');
    }
    await customStatement(
      'INSERT INTO places(name,latitude,longitude) VALUES(?,?,?)',
      [name.trim(), lat, lon],
    );
  }

  Future<void> deletePlace(int id) =>
      customStatement('DELETE FROM places WHERE id=?', [id]);
  Future<Set<String>> checkedItems() async => (await customSelect(
    'SELECT id FROM checklist WHERE done=1',
  ).get()).map((r) => r.read<String>('id')).toSet();
  Future<void> checkItem(String id, bool done) => customStatement(
    'INSERT OR REPLACE INTO checklist VALUES(?,?)',
    [id, done ? 1 : 0],
  );
}
