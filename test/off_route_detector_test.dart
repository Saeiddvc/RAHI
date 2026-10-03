import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/features/navigation/utils/off_route_detector.dart';

void main() {
  group('OffRouteDetector', () {
    const start = LatLng(35.7000, 51.4000);
    const end = LatLng(35.7000, 51.4100);
    const route = [start, end];

    test('point on segment is approximately zero meters away', () {
      const point = LatLng(35.7000, 51.4050);

      final distance =
          OffRouteDetector.distanceToRoute(point, route);

      expect(distance, lessThan(0.5));
    });

    test('point north of segment has expected perpendicular distance', () {
      const point = LatLng(35.7010, 51.4050);

      final distance =
          OffRouteDetector.distanceToRoute(point, route);

      expect(distance, closeTo(111.32, 2.0));
    });

    test('point before segment uses distance to first endpoint', () {
      const point = LatLng(35.7000, 51.3990);

      final distance =
          OffRouteDetector.distanceToRoute(point, route);
      final expected = const Distance().as(
        LengthUnit.Meter,
        point,
        start,
      );

      expect(distance, closeTo(expected, 2.0));
    });

    test('point after segment uses distance to last endpoint', () {
      const point = LatLng(35.7000, 51.4110);

      final distance =
          OffRouteDetector.distanceToRoute(point, route);
      final expected = const Distance().as(
        LengthUnit.Meter,
        point,
        end,
      );

      expect(distance, closeTo(expected, 2.0));
    });
  });
}
