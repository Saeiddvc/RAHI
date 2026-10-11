import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/features/navigation/utils/route_progress_matcher.dart';

void main() {
  group('RouteProgressMatcher', () {
    const route = [
      LatLng(35.7000, 51.4000),
      LatLng(35.7000, 51.4100),
      LatLng(35.7100, 51.4100),
    ];

    test('projects point to nearest segment', () {
      const point = LatLng(35.7010, 51.4050);

      final projection = RouteProgressMatcher.project(point, route);

      expect(projection, isNotNull);
      expect(projection!.segmentIndex, 0);
      expect(projection.snappedPoint.latitude, closeTo(35.7000, 0.00001));
      expect(projection.snappedPoint.longitude, closeTo(51.4050, 0.00001));
      expect(projection.distanceToRouteMeters, closeTo(111.3, 2.0));
      expect(projection.progressFraction, greaterThan(0));
      expect(projection.progressFraction, lessThan(1));
    });

    test('progress increases along polyline', () {
      const first = LatLng(35.7000, 51.4020);
      const second = LatLng(35.7050, 51.4100);

      final firstProjection =
          RouteProgressMatcher.project(first, route)!;
      final secondProjection = RouteProgressMatcher.project(
        second,
        route,
        previousDistanceAlongMeters:
            firstProjection.distanceAlongPolylineMeters,
      )!;

      expect(
        secondProjection.distanceAlongPolylineMeters,
        greaterThan(firstProjection.distanceAlongPolylineMeters),
      );
      expect(
        secondProjection.remainingPolylineMeters,
        lessThan(firstProjection.remainingPolylineMeters),
      );
    });

    test('continuity avoids jumping backward to an earlier overlap', () {
      const loopRoute = [
        LatLng(35.7000, 51.4000),
        LatLng(35.7000, 51.4100),
        LatLng(35.7100, 51.4100),
        LatLng(35.7100, 51.4000),
        LatLng(35.7000, 51.4000),
      ];

      final nearEnd = RouteProgressMatcher.project(
        const LatLng(35.7000, 51.4001),
        loopRoute,
        previousDistanceAlongMeters: 2500,
      );

      expect(nearEnd, isNotNull);
      expect(nearEnd!.distanceAlongPolylineMeters, greaterThan(2000));
    });

    test('single-point route remains usable', () {
      const single = [LatLng(35.7000, 51.4000)];

      final projection = RouteProgressMatcher.project(
        const LatLng(35.7001, 51.4000),
        single,
      );

      expect(projection, isNotNull);
      expect(projection!.totalPolylineMeters, 0);
      expect(projection.progressFraction, 0);
      expect(projection.distanceToRouteMeters, greaterThan(0));
    });
  });
}
