import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fieldkit/main_development.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Open installed handbook with airplane mode enabled before launch',
    (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('FIELDKIT'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'APAP');
      await tester.pumpAndSettle();
      expect(find.text('Paracetamol / acetaminophen'), findsOneWidget);
    },
  );
}
