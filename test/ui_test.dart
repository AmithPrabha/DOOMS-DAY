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
  for (final lang in languages.keys) {
    testWidgets('[T05] $lang all main screens at large text', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.memory();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('org.fieldkit/compass'),
        (_) async => null,
      );
      await db.installArticles('essential', seedArticles());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            stringsProvider.overrideWithValue(translations()),
            initialPreferencesProvider.overrideWithValue(
              AppPreferences(language: lang, textScale: 2, theme: 'dark'),
            ),
            packServiceProvider.overrideWithValue(WidgetPackService(db)),
          ],
          child: const FieldkitApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dooms Day App'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final icon in [
        Icons.menu_book_outlined,
        Icons.download_for_offline_outlined,
        Icons.explore_outlined,
        Icons.tune,
      ]) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang/$icon');
      }
      expect(find.text('Test Center'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await db.close();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('org.fieldkit/compass'),
        null,
      );
    });
  }
  testWidgets('[T03] search screen accepts medicine alias', (tester) async {
    final db = AppDatabase.memory();
    await db.installArticles('essential', seedArticles());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          stringsProvider.overrideWithValue(translations()),
          packServiceProvider.overrideWithValue(
            PackService(db, Directory.systemTemp),
          ),
        ],
        child: const FieldkitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'APAP');
    await tester.pumpAndSettle();
    expect(find.text('Paracetamol / acetaminophen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
