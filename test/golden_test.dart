import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/app.dart';
import 'package:fieldkit/core/models.dart';
import 'package:fieldkit/core/providers.dart';
import 'package:fieldkit/data/database.dart';
import 'package:fieldkit/services/packs.dart';
import 'helpers.dart';

void main() {
  for (final item in [('en', 'light'), ('ar', 'dark')]) {
    testWidgets(
      '[T23] ${item.$1} ${item.$2} emergency visual baseline',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final family in ['NotoSans', 'NotoSansArabic']) {
          final loader = FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final db = AppDatabase.memory();
        await db.installArticles('essential', seedArticles());
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              stringsProvider.overrideWithValue(translations()),
              initialPreferencesProvider.overrideWithValue(
                AppPreferences(language: item.$1, theme: item.$2),
              ),
              packServiceProvider.overrideWithValue(
                PackService(db, Directory.systemTemp),
              ),
            ],
            child: RepaintBoundary(key: key, child: const FieldkitApp()),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('goldens/emergency_${item.$1}_${item.$2}.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await db.close();
      },
      skip: !Platform.isMacOS,
    );
  }
}
