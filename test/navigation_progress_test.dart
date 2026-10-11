import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/map_route.dart';
import 'package:rahi/data/models/route_step.dart';
import 'package:rahi/features/navigation/providers/navigation_provider.dart';
import 'package:rahi/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation route progress', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'voice': false,
      });

      container = ProviderContainer();
      await container
          .read(settingsProvider.notifier)
          .setVoice(false);
    });

    tearDown(() {
      container.dispose();
    });

    final route = MapRoute(
      points: const [
        LatLng(35.7000, 51.4000),
        LatLng(35.7000, 51.4050),
        LatLng(35.7000, 51.4100),
      ],
      distanceMeters: 1000,
      durationSeconds: 200,
      steps: const [
        RouteStep(
          instruction: 'ادامه دهید',
          distanceMeters: 500,
          durationSeconds: 100,
          maneuver: ManeuverType.straight,
          location: LatLng(35.7000, 51.4000),
        ),
        RouteStep(
          instruction: 'به راست بپیچید',
          distanceMeters: 500,
          durationSeconds: 100,
          maneuver: ManeuverType.turnRight,
          location: LatLng(35.7000, 51.4050),
        ),
        RouteStep(
          instruction: 'به مقصد رسیدید',
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: ManeuverType.arrive,
          location: LatLng(35.7000, 51.4100),
        ),
      ],
    );

    test('progress and remaining distance follow route projection', () async {
      final notifier = container.read(navigationProvider.notifier);
      await notifier.start(route);

      await notifier.updateUserLocation(
        const LatLng(35.7000, 51.4020),
      );

      final first = container.read(navigationProvider);

      expect(first.routeProgressFraction, closeTo(0.20, 0.03));
      expect(first.routeProgressMeters, closeTo(200, 30));
      expect(first.remainingDistanceMeters, closeTo(800, 30));
      expect(first.currentStepIndex, 1);
      expect(first.matchedLocation, isNotNull);
      expect(first.distanceFromRouteMeters, lessThan(1));
    });

    test('GPS jitter cannot move navigation progress backward', () async {
      final notifier = container.read(navigationProvider.notifier);
      await notifier.start(route);

      await notifier.updateUserLocation(
        const LatLng(35.7000, 51.4060),
      );
      final forward = container.read(navigationProvider);

      await notifier.updateUserLocation(
        const LatLng(35.7000, 51.4055),
      );
      final jittered = container.read(navigationProvider);

      expect(
        jittered.routeProgressMeters,
        greaterThanOrEqualTo(forward.routeProgressMeters),
      );
      expect(
        jittered.remainingDistanceMeters,
        lessThanOrEqualTo(forward.remainingDistanceMeters),
      );
    });

    test('off-route sample does not advance route progress', () async {
      final notifier = container.read(navigationProvider.notifier);
      await notifier.start(route);

      await notifier.updateUserLocation(
        const LatLng(35.7000, 51.4040),
      );
      final onRoute = container.read(navigationProvider);

      await notifier.updateUserLocation(
        const LatLng(35.7010, 51.4080),
      );
      final offRoute = container.read(navigationProvider);

      expect(offRoute.isOffRoute, isTrue);
      expect(
        offRoute.routeProgressMeters,
        closeTo(onRoute.routeProgressMeters, 0.01),
      );
      expect(offRoute.distanceFromRouteMeters, greaterThan(50));
    });

    test('progress advances maneuver target by route distance', () async {
      final notifier = container.read(navigationProvider.notifier);
      await notifier.start(route);

      await notifier.updateUserLocation(
        const LatLng(35.7000, 51.4060),
      );

      final state = container.read(navigationProvider);

      expect(state.currentStepIndex, 2);
      expect(state.currentStep?.maneuver, ManeuverType.arrive);
      expect(state.distanceToNextStepMeters, greaterThan(300));
      expect(state.distanceToNextStepMeters, lessThan(500));
    });
  });
}
