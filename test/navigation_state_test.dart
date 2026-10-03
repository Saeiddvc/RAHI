import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/map_route.dart';
import 'package:rahi/data/models/place.dart';
import 'package:rahi/data/models/route_step.dart';
import 'package:rahi/features/navigation/providers/navigation_provider.dart';

void main() {
  group('NavigationState', () {
    final route = MapRoute(
      points: const [
        LatLng(35.70, 51.40),
        LatLng(35.71, 51.41),
      ],
      distanceMeters: 1000,
      durationSeconds: 120,
      steps: const [
        RouteStep(
          instruction: 'حرکت را آغاز کنید',
          distanceMeters: 700,
          durationSeconds: 80,
          maneuver: ManeuverType.depart,
          location: LatLng(35.70, 51.40),
        ),
        RouteStep(
          instruction: 'به راست بپیچید',
          distanceMeters: 300,
          durationSeconds: 40,
          maneuver: ManeuverType.turnRight,
          location: LatLng(35.705, 51.405),
        ),
        RouteStep(
          instruction: 'به مقصد رسیدید',
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: ManeuverType.arrive,
          location: LatLng(35.71, 51.41),
        ),
      ],
    );

    const destination = Place(
      title: 'مقصد',
      address: 'تهران',
      location: LatLng(35.71, 51.41),
    );

    test('currentStep and nextStep follow target index', () {
      final state = NavigationState(
        route: route,
        currentStepIndex: 1,
        isActive: true,
      );

      expect(state.currentStep?.maneuver, ManeuverType.turnRight);
      expect(state.nextStep?.maneuver, ManeuverType.arrive);
    });

    test('copyWith preserves route and updates progress', () {
      final state = NavigationState(
        route: route,
        currentStepIndex: 1,
        isActive: true,
      );

      final updated = state.copyWith(
        distanceToNextStepMeters: 180,
        remainingDistanceMeters: 480,
        remainingDurationSeconds: 65,
      );

      expect(updated.route, same(route));
      expect(updated.currentStepIndex, 1);
      expect(updated.distanceToNextStepMeters, 180);
      expect(updated.remainingDistanceMeters, 480);
      expect(updated.remainingDurationSeconds, 65);
    });

    test('route without steps exposes no maneuver state', () {
      final noStepsRoute = MapRoute(
        points: const [
          LatLng(35.70, 51.40),
          LatLng(35.80, 51.50),
        ],
        distanceMeters: 5000,
        durationSeconds: 600,
      );

      final state = NavigationState(
        route: noStepsRoute,
        remainingDistanceMeters: noStepsRoute.distanceMeters,
        remainingDurationSeconds: noStepsRoute.durationSeconds,
      );

      expect(state.currentStep, isNull);
      expect(state.nextStep, isNull);
      expect(state.remainingSteps, isEmpty);
      expect(state.remainingDistanceMeters, 5000);
      expect(state.remainingDurationSeconds, 600);
    });

    test('destination is preserved by copyWith', () {
      final state = NavigationState(
        route: route,
        destination: destination,
        isActive: true,
      );

      final updated = state.copyWith(isOffRoute: true);

      expect(updated.destination, same(destination));
      expect(updated.isOffRoute, isTrue);
    });
  });

  test('acceptReroute without destination is a no-op', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(navigationProvider);

    await container
        .read(navigationProvider.notifier)
        .acceptReroute(const LatLng(35.70, 51.40));

    final after = container.read(navigationProvider);

    expect(after.route, before.route);
    expect(after.destination, before.destination);
    expect(after.isRerouting, isFalse);
    expect(after.pendingRerouteConfirmation, isFalse);
  });
}
