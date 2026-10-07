import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/location_fix.dart';

void main() {
  group('LocationFix', () {
    test('fresh GPS fix within 10 seconds is fresh', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp:
            DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
        accuracyMeters: 20,
        source: LocationSource.gps,
      );

      expect(fix.isFresh(), isTrue);
      expect(fix.isGps, isTrue);
    });

    test('two-minute-old fix is stale', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp:
            DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
        accuracyMeters: 20,
        source: LocationSource.gps,
      );

      expect(fix.isFresh(), isFalse);
    });

    test('20 meter accuracy is accepted', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp: DateTime.now().toUtc(),
        accuracyMeters: 20,
        source: LocationSource.gps,
      );

      expect(fix.isAccurate(), isTrue);
    });

    test('80 meter accuracy is rejected for routing', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp: DateTime.now().toUtc(),
        accuracyMeters: 80,
        source: LocationSource.gps,
      );

      expect(fix.isAccurate(), isFalse);
    });

    test('200 meter accuracy is rejected', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp: DateTime.now().toUtc(),
        accuracyMeters: 200,
        source: LocationSource.gps,
      );

      expect(fix.isAccurate(), isFalse);
    });

    test('last-known fix is not GPS', () {
      final fix = LocationFix(
        location: const LatLng(35.7, 51.4),
        timestamp: DateTime.now().toUtc(),
        accuracyMeters: 20,
        source: LocationSource.lastKnown,
      );

      expect(fix.isGps, isFalse);
    });
  });
}
