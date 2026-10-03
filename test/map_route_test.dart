import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/map_route.dart';
import 'package:rahi/data/models/route_step.dart';

void main() {
  group('MapRoute', () {
    test('creates with required values and empty steps', () {
      final route = MapRoute(
        points: const [LatLng(35.7, 51.4)],
        distanceMeters: 1200,
        durationSeconds: 300,
      );

      expect(route.distanceMeters, 1200);
      expect(route.durationSeconds, 300);
      expect(route.points, hasLength(1));
      expect(route.trafficStatus, isNull);
      expect(route.steps, isEmpty);
      expect(route.hasSteps, isFalse);
    });

    test('hasSteps is true and copyWith preserves steps', () {
      const step = RouteStep(
        instruction: 'به راست بپیچید',
        distanceMeters: 100,
        durationSeconds: 20,
        maneuver: ManeuverType.turnRight,
        location: LatLng(35.7, 51.4),
      );

      final route = MapRoute(
        points: const [LatLng(35.7, 51.4)],
        distanceMeters: 1200,
        durationSeconds: 300,
        steps: const [step],
      );

      final updated = route.copyWith(durationSeconds: 400);

      expect(route.hasSteps, isTrue);
      expect(route.steps, hasLength(1));
      expect(updated.durationSeconds, 400);
      expect(updated.steps, same(route.steps));
    });
  });

  group('RouteStep Neshan parsing', () {
    test('parses documented turn step and [lng, lat] location', () {
      final step = RouteStep.tryFromNeshanJson({
        'name': 'روانمهر',
        'instruction': 'به سمت روانمهر، به چپ بپیچید',
        'type': 'turn',
        'modifier': 'left',
        'distance': {'value': 983.0},
        'duration': {'value': 261.0},
        'polyline': 'encoded-step',
        'start_location': [51.391498, 35.698122],
      });

      expect(step, isNotNull);
      expect(step!.maneuver, ManeuverType.turnLeft);
      expect(step.distanceMeters, 983);
      expect(step.durationSeconds, 261);
      expect(step.location.latitude, closeTo(35.698122, 0.000001));
      expect(step.location.longitude, closeTo(51.391498, 0.000001));
      expect(step.roadName, 'روانمهر');
      expect(step.rawType, 'turn');
      expect(step.rawModifier, 'left');
      expect(step.encodedPolyline, 'encoded-step');
    });

    test('parses exit rotary as roundabout', () {
      expect(
        RouteStep.parseManeuver(
          type: 'exit rotary',
          modifier: 'slight right',
        ),
        ManeuverType.roundabout,
      );
    });

    test('parses uturn modifier', () {
      expect(
        RouteStep.parseManeuver(
          type: 'turn',
          modifier: 'uturn',
        ),
        ManeuverType.uTurn,
      );
    });

    test('returns null for unusable step without location', () {
      final step = RouteStep.tryFromNeshanJson({
        'instruction': 'به راست بپیچید',
        'type': 'turn',
        'modifier': 'right',
      });

      expect(step, isNull);
    });
  });
}
