import 'dart:io';
import 'package:geolocator/geolocator.dart';
import '../core/models.dart';
import '../services/navigation.dart';
import '../services/packs.dart';

/// Development-only fixtures. They never call native location or network APIs.
class FixtureNavigation extends NavigationService {
  final String scenario;
  FixtureNavigation(this.scenario);
  @override
  Stream<CompassReading> get compass => Stream.multi((controller) {
    controller.add(
      CompassReading(scenario == 'missing sensor' ? null : 45, null),
    );
    controller.close();
  }, isBroadcast: true);
  @override
  Future<Position> locate() async {
    throw StateError(
      scenario == 'denied location'
          ? 'Fixture: location permission denied. Saved coordinates remain usable.'
          : 'Fixture: no GPS fix available. No device permission was requested.',
    );
  }
}

class FixturePacks extends PackService {
  final String scenario;
  FixturePacks(super.db, super.root, this.scenario)
    : super(allowDrafts: true, availableBytes: () async => 0);
  @override
  Future<List<Pack>> catalog() async {
    if (scenario == 'network unavailable') {
      throw const SocketException('Fixture: network unavailable');
    }
    return [];
  }
}
