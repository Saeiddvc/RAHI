import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/map_route.dart';

void main() {
  group('MapRoute', () {
    test('creates with required values', () {
      final route = MapRoute(
        points: const [LatLng(35.7, 51.4)],
        distanceMeters: 1200,
        durationSeconds: 300,
      );

      expect(route.distanceMeters, 1200);
      expect(route.durationSeconds, 300);
      expect(route.points, hasLength(1));
      expect(route.trafficStatus, isNull);
    });

    test('copyWith changes only requested values', () {
      final route = MapRoute(
        points: const [LatLng(35.7, 51.4)],
        distanceMeters: 1200,
        durationSeconds: 300,
      );

      final updated = route.copyWith(durationSeconds: 400);

      expect(updated.durationSeconds, 400);
      expect(updated.distanceMeters, 1200);
      expect(updated.points, route.points);
    });
  });
}
