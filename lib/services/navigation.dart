import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class CompassReading {
  final double? heading, accuracy;
  final bool unreliable;
  CompassReading(this.heading, this.accuracy, {this.unreliable = false});
}

class NavigationService {
  Future<Position> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is unavailable. You can still read maps and save coordinates manually.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
  }

  Stream<CompassReading> get compass =>
      const EventChannel('org.fieldkit/compass').receiveBroadcastStream().map((
        event,
      ) {
        final values = event as Map;
        return CompassReading(
          (values['heading'] as num?)?.toDouble(),
          (values['accuracy'] as num?)?.toDouble(),
          unreliable: values['status'] == 'unreliable',
        );
      });
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    double rad(double n) => n * math.pi / 180;
    final a =
        math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(rad(lon2 - lon1) / 2), 2);
    return r *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
  }

  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    double rad(double n) => n * math.pi / 180;
    final y = math.sin(rad(lon2 - lon1)) * math.cos(rad(lat2));
    final x =
        math.cos(rad(lat1)) * math.sin(rad(lat2)) -
        math.sin(rad(lat1)) * math.cos(rad(lat2)) * math.cos(rad(lon2 - lon1));
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
