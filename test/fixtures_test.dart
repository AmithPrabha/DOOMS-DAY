import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/core/providers.dart';
import 'package:fieldkit/data/database.dart';
import 'package:fieldkit/development/fixtures.dart';
import 'package:fieldkit/features/maps.dart';
import 'helpers.dart';

void main() {
  testWidgets(
    '[T24] denied location and missing sensor preserve map fallback',
    (tester) async {
      final db = AppDatabase.memory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            stringsProvider.overrideWithValue(translations()),
            navigationProvider.overrideWithValue(
              FixtureNavigation('missing sensor'),
            ),
            packServiceProvider.overrideWithValue(WidgetPackService(db)),
          ],
          child: const MaterialApp(home: Scaffold(body: MapScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Compass unavailable'), 250);
      expect(find.text('Compass unavailable'), findsOneWidget);
      await tester.scrollUntilVisible(find.byIcon(Icons.my_location), -200);
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Fixture: no GPS fix available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await db.close();
      await expectLater(
        FixtureNavigation('denied location').locate(),
        throwsStateError,
      );
    },
  );
  test('[T24] unavailable catalog leaves installed content readable', () async {
    final db = AppDatabase.memory();
    await db.installArticles('essential', seedArticles());
    final packs = FixturePacks(
      db,
      Directory('/unused-network-fixture'),
      'network unavailable',
    );
    await expectLater(packs.catalog(), throwsA(isA<SocketException>()));
    expect(await db.article('prepare', 'en'), isNotNull);
    await db.close();
  });
}
