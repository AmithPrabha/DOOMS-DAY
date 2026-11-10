import 'package:flutter_test/flutter_test.dart';
import 'package:fieldkit/services/navigation.dart';
import 'package:fieldkit/data/database.dart';

void main() {
  test('[T16] distance and bearing match known equatorial coordinates', () {
    expect(NavigationService.distance(0, 0, 0, 1), closeTo(111195, 2));
    expect(NavigationService.bearing(0, 0, 0, 1), closeTo(90, 0.001));
    expect(NavigationService.distance(0, 0, 0, 0), 0);
    expect(NavigationService.distance(0, 179.9, 0, -179.9), closeTo(22239, 2));
  });
  test('[T16] invalid coordinates cannot be persisted', () async {
    final db = AppDatabase.memory();
    try {
      await expectLater(db.savePlace('bad', 91, 0), throwsArgumentError);
      await expectLater(
        db.savePlace('bad', double.nan, 0),
        throwsArgumentError,
      );
      await expectLater(db.savePlace('', 0, 0), throwsArgumentError);
      await db.savePlace('valid', -90, 180);
      expect((await db.places()).length, 1);
    } finally {
      await db.close();
    }
  });
}
