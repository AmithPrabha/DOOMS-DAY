import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/data/database.dart';
import 'package:fieldkit/core/models.dart';
import 'helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.memory();
    await db.installArticles('essential', seedArticles());
  });
  tearDown(() async {
    await db.close();
  });
  test('[T01] all nine languages have offline essential cards', () async {
    for (final lang in languages.keys) {
      expect(await db.article('prepare', lang), isNotNull);
      expect(await db.article('lost', lang), isNotNull);
    }
  });
  test('[T03] aliases, Unicode and punctuation are safe to search', () async {
    expect((await db.articles('en', query: 'APAP')).single.id, 'paracetamol');
    expect(await db.articles('ar', query: 'الطوارئ'), isNotEmpty);
    for (final query in [
      '"',
      'OR NOT *',
      "'; DROP TABLE articles; --",
      '%_',
      '🤔',
    ]) {
      await db.articles('en', query: query);
    }
    expect(await db.articles('en'), isNotEmpty);
  });
  test('[T04] removing a pack updates search but retains bookmark', () async {
    final a = Article({
      ...seedArticles().first.data,
      'id': 'optional-test',
      'title': 'Unique optional topic',
    });
    await db.installArticles('optional', [a]);
    await db.toggleBookmark(a);
    await db.removePack('optional');
    expect(await db.articles('en', query: 'Unique optional'), isEmpty);
    expect(await db.bookmarks(), contains('optional-test'));
    await db.installArticles('optional', [a]);
    expect(
      (await db.articles('en', bookmarksOnly: true)).single.id,
      'optional-test',
    );
    await expectLater(db.removePack('essential'), throwsStateError);
  });
  test('[T07] preferences and checklist use local data', () async {
    await db.savePreferences(
      const AppPreferences(language: 'ar', theme: 'dark', textScale: 1.75),
    );
    await db.checkItem('water', true);
    expect((await db.preferences()).language, 'ar');
    expect((await db.preferences()).textScale, 1.75);
    expect(await db.checkedItems(), contains('water'));
  });
  test('[T02] cold restart retains content and personal data', () async {
    final dir = Directory.systemTemp.createTempSync('fieldkit-db-');
    final file = File('${dir.path}/app.sqlite');
    var disk = AppDatabase.file(file);
    try {
      await disk.installArticles('essential', seedArticles());
      await disk.toggleBookmark(seedArticles().first);
      await disk.savePreferences(const AppPreferences(theme: 'dark'));
      await disk.close();
      disk = AppDatabase.file(file);
      expect(await disk.article('prepare', 'en'), isNotNull);
      expect(await disk.bookmarks(), contains('prepare'));
      expect((await disk.preferences()).theme, 'dark');
    } finally {
      await disk.close();
      dir.deleteSync(recursive: true);
    }
  });
  test('[T21] version-one upgrade preserves user and pack records', () async {
    final dir = Directory.systemTemp.createTempSync('fieldkit-migration-');
    var disk = AppDatabase.file(File('${dir.path}/app.sqlite'));
    try {
      await disk.savePreferences(const AppPreferences(language: 'ml'));
      await disk.savePlace('Meeting point', 25.285, 51.531);
      await disk.customStatement(
        "INSERT INTO packs VALUES('old','1','content','/sample',1,'abc')",
      );
      await disk.customStatement('DROP TABLE checklist');
      await disk.customStatement('PRAGMA user_version = 1');
      await disk.close();
      disk = AppDatabase.file(File('${dir.path}/app.sqlite'));
      expect((await disk.preferences()).language, 'ml');
      expect((await disk.places()).single.name, 'Meeting point');
      expect((await disk.installedPacks()).single['id'], 'old');
      await disk.checkItem('water', true);
      expect(await disk.checkedItems(), contains('water'));
    } finally {
      await disk.close();
      dir.deleteSync(recursive: true);
    }
  });
}
