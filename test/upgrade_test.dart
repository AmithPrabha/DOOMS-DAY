import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/app.dart';
import 'package:fieldkit/core/models.dart';
import 'package:fieldkit/core/providers.dart';
import 'package:fieldkit/data/database.dart';
import 'package:fieldkit/data/knowledge_repository.dart';
import 'package:fieldkit/services/wikipedia.dart';
import 'package:fieldkit/services/packs.dart';
import 'package:fieldkit/widgets/compass_dial.dart';
import 'package:fieldkit/features/handbook.dart';
import 'package:fieldkit/services/kiwix_catalog.dart';
import 'helpers.dart';

void main() {
  testWidgets(
    '[T12] first-run capacity probe supplies an existing native path',
    (tester) async {
      await tester.runAsync(() async {
        final parent = await Directory.systemTemp.createTemp('dooms-storage-');
        final root = Directory('${parent.path}/packs');
        final db = AppDatabase.memory();
        const channel = MethodChannel('org.fieldkit/storage');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            expect(call.method, 'availableBytes');
            expect(
              Directory((call.arguments as Map)['path'] as String).existsSync(),
              isTrue,
            );
            return 123456789;
          },
        );
        expect(await PackService(db, root).diskBytes(), 123456789);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await db.close();
        await parent.delete(recursive: true);
      });
    },
  );
  test(
    '[T21] real version-two table set upgrades without losing personal data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dooms-migration-',
      );
      final file = File('${directory.path}/fieldkit.sqlite');
      var db = AppDatabase.file(file);
      await db.savePreferences(
        const AppPreferences(language: 'ar', budgetMb: 16384),
      );
      await db.toggleBookmark(seedArticles().first);
      await db.savePlace('Fixture place', 0, 0);
      await db.customStatement('DROP TABLE archives');
      await db.customStatement('DROP TABLE download_jobs');
      await db.customStatement('PRAGMA user_version=2');
      await db.close();
      db = AppDatabase.file(file);
      expect((await db.preferences()).language, 'ar');
      expect((await db.preferences()).budgetMb, 16384);
      expect(await db.bookmarks(), contains(seedArticles().first.id));
      expect((await db.places()).single.name, 'Fixture place');
      expect(await db.customSelect('SELECT * FROM archives').get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM download_jobs').get(),
        isEmpty,
      );
      await db.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    '[T25] consecutive failed preference writes restore committed values',
    () async {
      final db = AppDatabase.memory();
      await db.customStatement('DROP TABLE preferences');
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(preferencesProvider.notifier);
      await Future.wait([
        controller
            .update(const AppPreferences(theme: 'dark'))
            .catchError((Object _) {}),
        controller
            .update(const AppPreferences(language: 'ar', theme: 'dark'))
            .catchError((Object _) {}),
      ]);
      expect(container.read(preferencesProvider).theme, 'system');
      expect(container.read(preferencesProvider).language, 'en');
      container.dispose();
      await db.close();
    },
  );
  test('[T30] catalog does not call mini editions complete', () {
    final editions = KiwixCatalog.parse('''<feed><entry>
      <id>mini</id><title>Wikipedia</title><language>eng</language>
      <updated>2026-01-01</updated><name>wikipedia_en_all_mini</name>
      <flavour>mini</flavour><link type="application/x-zim"
      href="https://download.kiwix.org/example.zim.meta4" length="12345"/>
      </entry></feed>''');
    expect(editions.single.introductoryOnly, isTrue);
    expect(editions.single.allArticles, isFalse);
    expect(editions.single.bytes, 12345);
    expect(editions.single.metalink, endsWith('.meta4'));
  });
  testWidgets(
    '[T33] structured reader renders code and contents at large text',
    (tester) async {
      final db = AppDatabase.memory();
      final data = jsonDecode(
        File('assets/content/practical.json').readAsStringSync(),
      );
      final article = Article(
        (data['articles'] as List).firstWhere(
          (a) => a['id'] == 'practical-python-json',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            stringsProvider.overrideWithValue(translations()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ArticleScreen(article: article),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contents'), findsOneWidget);
      expect(find.textContaining('json.dumps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
  test('[T26] compass shortest rotation and cardinal boundaries', () {
    expect(headingDelta(359, 0), 1);
    expect(headingDelta(0, 359), -1);
    for (final entry in {
      0.0: 'N',
      90.0: 'E',
      180.0: 'S',
      270.0: 'W',
      359.0: 'N',
    }.entries) {
      expect(compassDirection(entry.key), entry.value);
    }
  });
  testWidgets('[T26] unavailable compass has no invented bearing in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CompassDial(
            heading: null,
            magneticLabel: 'magnetic',
            unavailableLabel: 'Unavailable',
            unreliableLabel: 'Unreliable',
          ),
        ),
      ),
    );
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.textContaining('0°'), findsNothing);
    expect(find.byIcon(Icons.explore_off_outlined), findsOneWidget);
  });
  testWidgets(
    '[T25] quick controls synchronize Settings and persisted preferences',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.memory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            stringsProvider.overrideWithValue(translations()),
            packServiceProvider.overrideWithValue(WidgetPackService(db)),
            initialPreferencesProvider.overrideWithValue(
              const AppPreferences(textScale: 2),
            ),
          ],
          child: const FieldkitApp(),
        ),
      );
      await tester.pumpAndSettle();
      final themeButton = find.byKey(const ValueKey('quick-theme'));
      expect(tester.getSize(themeButton).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(themeButton).height, greaterThanOrEqualTo(48));
      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect((await db.preferences()).theme, 'dark');
      await tester.tap(find.byKey(const ValueKey('quick-language')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('العربية'),
          matching: find.byType(CheckedPopupMenuItem<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect((await db.preferences()).language, 'ar');
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('العربية'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      final englishReference = find.widgetWithText(
        FilterChip,
        translations()['ar']!['english_reference']!,
      );
      await tester.ensureVisible(englishReference);
      await tester.pumpAndSettle();
      await tester.tap(englishReference);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(englishReference).selected, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      await container
          .read(preferencesProvider.notifier)
          .update(container.read(preferencesProvider).copyWith(language: 'hi'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(
                FilterChip,
                translations()['hi']!['english_reference']!,
              ),
            )
            .selected,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
  test('[T27] questions retain brown rice and negative qualifiers', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final data = jsonDecode(
      File('assets/content/practical.json').readAsStringSync(),
    );
    final articles = (data['articles'] as List).map((a) => Article(a)).toList();
    await db.installArticles('essential', articles);
    final repo = KnowledgeRepository(db);
    final rice = await repo.search('How to cook brown rice?', 'en');
    expect(rice.articles.first.id, 'practical-brown-rice');
    expect(rice.reviewedAnswer, isNull);
    expect(
      normalizeQuestion('How to cook rice without electricity?', 'en'),
      'cook rice without electricity',
    );
    expect(normalizeQuestion('كيف طهي الأرز؟', 'ar'), 'طهي الأرز');
    final python = await repo.search('how to create python application', 'en');
    expect(
      python.articles.map((a) => a.id),
      contains('practical-python-inventory'),
    );
    final page1 = await repo.search('', 'en', pageSize: 10);
    final page2 = await repo.search('', 'en', pageSize: 10, page: 1);
    expect(page1.hasMore, isTrue);
    expect(
      page1.articles
          .map((a) => a.id)
          .toSet()
          .intersection(page2.articles.map((a) => a.id).toSet()),
      isEmpty,
    );
  });
  test(
    '[T28] Wikipedia importer keeps text, revision and attribution without executable content',
    () async {
      final article = WikipediaService.convertPage(
        'en',
        123,
        {
          'title': 'Example',
          'revid': 456,
          'text':
              '<p>First paragraph.</p><script>alert(1)</script>'
              '<h2>Method</h2><p>Detailed text <a href="/wiki/Rice">rice</a>.</p>'
              '<img src="https://tracker.invalid/pixel"><table><tr><td>A</td><td>B</td></tr></table>',
        },
        'CC BY-SA 4.0',
        'https://creativecommons.org/licenses/by-sa/4.0/',
      );
      expect(article.sourceKind, 'wikipedia');
      expect(article.reviewed, isFalse);
      expect(article.data['source_revision'], 456);
      expect(article.searchText, contains('Detailed text'));
      expect(article.searchText, isNot(contains('alert')));
      expect(article.searchText, isNot(contains('tracker')));
      expect(article.strings('internal_links'), ['Rice']);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.saveReference(article);
      await db.toggleBookmark(article);
      await db.saveReference(article);
      expect(await db.bookmarks(), contains('wiki:en:123'));
      expect(
        (await KnowledgeRepository(
          db,
        ).search('Detailed', 'en')).articles.single.id,
        article.id,
      );
    },
  );
  test('[T29] required food photos and specialist reviews fail closed', () {
    final original = seedArticles().first;
    final food = Article({
      ...original.data,
      'food_identification': true,
      'media': [],
    });
    expect(
      () => PackService.validateArticle(food, allowDrafts: true),
      throwsFormatException,
    );
  });
}
