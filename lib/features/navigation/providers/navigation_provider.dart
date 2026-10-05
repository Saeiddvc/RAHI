import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/voice_service.dart';
import '../../../data/models/location_fix.dart';
import '../../../data/models/map_route.dart';
import '../../../data/models/place.dart';
import '../../../data/models/route_step.dart';
import '../../../providers/map_service_provider.dart';
import '../../../providers/settings_provider.dart';
import '../utils/off_route_detector.dart';

class NavigationState {
  final MapRoute? route;
  final Place? destination;

  /// Index of the upcoming maneuver target in route.steps.
  final int currentStepIndex;
  final double distanceToNextStepMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final bool arrived;
  final bool isActive;
  final bool voiceUnavailable;
  final bool isOffRoute;
  final bool isRerouting;
  final bool pendingRerouteConfirmation;
  final String? rerouteError;

  const NavigationState({
    this.route,
    this.destination,
    this.currentStepIndex = 0,
    this.distanceToNextStepMeters = 0,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
    this.arrived = false,
    this.isActive = false,
    this.voiceUnavailable = false,
    this.isOffRoute = false,
    this.isRerouting = false,
    this.pendingRerouteConfirmation = false,
    this.rerouteError,
  });

  RouteStep? get currentStep {
    final activeRoute = route;
    if (activeRoute == null || !activeRoute.hasSteps) return null;
    if (currentStepIndex < 0 ||
        currentStepIndex >= activeRoute.steps.length) {
      return null;
    }
    return activeRoute.steps[currentStepIndex];
  }

  RouteStep? get nextStep {
    final activeRoute = route;
    if (activeRoute == null || !activeRoute.hasSteps) return null;

    final nextIndex = currentStepIndex + 1;
    if (nextIndex >= activeRoute.steps.length) return null;
    return activeRoute.steps[nextIndex];
  }

  List<RouteStep> get remainingSteps {
    final activeRoute = route;
    if (activeRoute == null || !activeRoute.hasSteps) {
      return const [];
    }

    if (currentStepIndex < 0 ||
        currentStepIndex >= activeRoute.steps.length) {
      return const [];
    }

    return activeRoute.steps.sublist(currentStepIndex);
  }

  NavigationState copyWith({
    MapRoute? route,
    Place? destination,
    int? currentStepIndex,
    double? distanceToNextStepMeters,
    double? remainingDistanceMeters,
    int? remainingDurationSeconds,
    bool? arrived,
    bool? isActive,
    bool? voiceUnavailable,
    bool? isOffRoute,
    bool? isRerouting,
    bool? pendingRerouteConfirmation,
    String? rerouteError,
    bool clearRoute = false,
    bool clearRerouteError = false,
  }) {
    return NavigationState(
      route: clearRoute ? null : (route ?? this.route),
      destination: destination ?? this.destination,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      distanceToNextStepMeters:
          distanceToNextStepMeters ?? this.distanceToNextStepMeters,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      arrived: arrived ?? this.arrived,
      isActive: isActive ?? this.isActive,
      voiceUnavailable: voiceUnavailable ?? this.voiceUnavailable,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      pendingRerouteConfirmation:
          pendingRerouteConfirmation ?? this.pendingRerouteConfirmation,
      rerouteError:
          clearRerouteError ? null : (rerouteError ?? this.rerouteError),
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier(this._ref) : super(const NavigationState());

  final Ref _ref;
  final Distance _distance = const Distance();

  static const double _stepAdvanceThresholdMeters = 30;
  static const double _preAnnounceThresholdMeters = 250;
  static const Duration _offRouteGrace = Duration(seconds: 6);

  int _preAnnouncedStepIndex = -1;
  bool _arrivalAnnounced = false;
  bool _rerouteOfferedForCurrentOffRoute = false;
  Timer? _offRouteGraceTimer;

  Future<void> start(
    MapRoute route, {
    Place? destination,
    LatLng? initialLocation,
  }) async {
    _resetRerouteTracking();
    _preAnnouncedStepIndex = -1;
    _arrivalAnnounced = false;

    final firstTargetIndex = _initialTargetIndex(route);

    state = NavigationState(
      route: route,
      destination: destination,
      currentStepIndex: firstTargetIndex,
      remainingDistanceMeters: route.distanceMeters,
      remainingDurationSeconds: route.durationSeconds,
      isActive: true,
    );

    await _announceDepartureIfPresent(route);

    if (initialLocation != null) {
      await updateUserLocation(initialLocation);
    }
  }

  Future<void> stop() async {
    _offRouteGraceTimer?.cancel();
    await _ref.read(voiceServiceProvider).stop();
    state = const NavigationState();
    _preAnnouncedStepIndex = -1;
    _arrivalAnnounced = false;
    _rerouteOfferedForCurrentOffRoute = false;
  }

  Future<void> updateUserLocationFromFix(LocationFix fix) async {
    if (!fix.isGps ||
        !fix.isFresh() ||
        !fix.isAccurate()) {
      return;
    }

    await updateUserLocation(fix.location);
  }

  Future<void> updateUserLocation(LatLng userLocation) async {
    final route = state.route;
    if (!state.isActive || route == null) return;
    if (state.arrived) return;

    _updateOffRoute(userLocation, route);

    if (!route.hasSteps) return;

    var stepIndex = state.currentStepIndex;
    var target = route.steps[stepIndex];
    var distanceToTarget = _metersBetween(
      userLocation,
      target.location,
    );

    if (distanceToTarget <= _stepAdvanceThresholdMeters) {
      if (_isArrivalTarget(route, stepIndex)) {
        await _onArrived();
        return;
      }

      stepIndex++;
      _preAnnouncedStepIndex = -1;
      target = route.steps[stepIndex];
      distanceToTarget = _metersBetween(
        userLocation,
        target.location,
      );
    }

    final remaining = _remainingEstimate(
      route: route,
      stepIndex: stepIndex,
      distanceToTarget: distanceToTarget,
    );

    state = state.copyWith(
      currentStepIndex: stepIndex,
      distanceToNextStepMeters: distanceToTarget,
      remainingDistanceMeters: remaining.distanceMeters,
      remainingDurationSeconds: remaining.durationSeconds,
    );

    if (distanceToTarget <= _preAnnounceThresholdMeters) {
      await _preAnnounceCurrentStep();
    }
  }

  void _updateOffRoute(
    LatLng userLocation,
    MapRoute route,
  ) {
    final distanceToRoute = OffRouteDetector.distanceToRoute(
      userLocation,
      route.points,
    );
    final isOffRoute =
        distanceToRoute > OffRouteDetector.offRouteThresholdMeters;

    if (!isOffRoute) {
      _offRouteGraceTimer?.cancel();
      _offRouteGraceTimer = null;
      _rerouteOfferedForCurrentOffRoute = false;

      if (state.isOffRoute || state.pendingRerouteConfirmation) {
        state = state.copyWith(
          isOffRoute: false,
          pendingRerouteConfirmation: false,
        );
      }
      return;
    }

    if (!state.isOffRoute) {
      state = state.copyWith(isOffRoute: true);
    }

    if (_rerouteOfferedForCurrentOffRoute ||
        state.pendingRerouteConfirmation ||
        state.isRerouting ||
        state.destination == null ||
        _offRouteGraceTimer != null) {
      return;
    }

    _offRouteGraceTimer = Timer(_offRouteGrace, () {
      _offRouteGraceTimer = null;

      if (!mounted ||
          !state.isActive ||
          !state.isOffRoute ||
          state.arrived ||
          state.destination == null ||
          state.isRerouting ||
          _rerouteOfferedForCurrentOffRoute) {
        return;
      }

      _rerouteOfferedForCurrentOffRoute = true;
      state = state.copyWith(
        pendingRerouteConfirmation: true,
      );
    });
  }

  void dismissReroute() {
    _offRouteGraceTimer?.cancel();
    _offRouteGraceTimer = null;
    _rerouteOfferedForCurrentOffRoute = true;

    state = state.copyWith(
      pendingRerouteConfirmation: false,
    );
  }

  Future<void> acceptReroute(LatLng currentLocation) async {
    final destination = state.destination;
    if (destination == null || !state.isActive) {
      return;
    }

    _offRouteGraceTimer?.cancel();
    _offRouteGraceTimer = null;

    state = state.copyWith(
      pendingRerouteConfirmation: false,
      isRerouting: true,
      clearRerouteError: true,
    );

    try {
      final service = _ref.read(mapServiceProvider);
      final routeType = _ref.read(settingsProvider).routeType;

      if (!service.supportedRouteTypes.contains(routeType)) {
        throw StateError(
          'Route type ${routeType.name} is not supported by '
          '${service.displayName}.',
        );
      }

      final routes = await service.direction(
        origin: currentLocation,
        destination: destination.location,
        type: routeType,
      );

      if (!mounted) return;

      if (routes.isEmpty) {
        state = state.copyWith(
          isRerouting: false,
          rerouteError: 'No route returned by the active map service.',
        );
        _rerouteOfferedForCurrentOffRoute = true;
        return;
      }

      final newRoute = routes.first;
      final firstTargetIndex = _initialTargetIndex(newRoute);

      _preAnnouncedStepIndex = -1;
      _arrivalAnnounced = false;
      _rerouteOfferedForCurrentOffRoute = false;

      state = state.copyWith(
        route: newRoute,
        currentStepIndex: firstTargetIndex,
        distanceToNextStepMeters: 0,
        remainingDistanceMeters: newRoute.distanceMeters,
        remainingDurationSeconds: newRoute.durationSeconds,
        arrived: false,
        isRerouting: false,
        isOffRoute: false,
        pendingRerouteConfirmation: false,
        clearRerouteError: true,
      );

      await _announceDepartureIfPresent(newRoute);

      if (mounted) {
        await updateUserLocation(currentLocation);
      }
    } catch (error) {
      if (!mounted) return;

      _rerouteOfferedForCurrentOffRoute = true;
      state = state.copyWith(
        isRerouting: false,
        pendingRerouteConfirmation: false,
        rerouteError: error.toString(),
      );
    }
  }

  void clearRerouteError() {
    if (state.rerouteError == null) return;
    state = state.copyWith(clearRerouteError: true);
  }

  void _resetRerouteTracking() {
    _offRouteGraceTimer?.cancel();
    _offRouteGraceTimer = null;
    _rerouteOfferedForCurrentOffRoute = false;
  }

  int _initialTargetIndex(MapRoute route) {
    if (!route.hasSteps) return 0;

    if (route.steps.length > 1 &&
        route.steps.first.maneuver == ManeuverType.depart) {
      return 1;
    }

    return 0;
  }

  bool _isArrivalTarget(MapRoute route, int stepIndex) {
    if (stepIndex >= route.steps.length - 1) return true;
    return route.steps[stepIndex].maneuver == ManeuverType.arrive;
  }

  double _metersBetween(LatLng from, LatLng to) {
    return _distance.as(
      LengthUnit.Meter,
      from,
      to,
    );
  }

  _RemainingEstimate _remainingEstimate({
    required MapRoute route,
    required int stepIndex,
    required double distanceToTarget,
  }) {
    var remainingDistance = distanceToTarget;
    var remainingDuration = 0.0;

    if (stepIndex > 0) {
      final activeSegment = route.steps[stepIndex - 1];
      final segmentDistance = activeSegment.distanceMeters;

      if (segmentDistance > 0) {
        final ratio =
            (distanceToTarget / segmentDistance).clamp(0.0, 1.0);
        remainingDuration += activeSegment.durationSeconds * ratio;
      }
    }

    for (var index = stepIndex; index < route.steps.length; index++) {
      remainingDistance += route.steps[index].distanceMeters;
      remainingDuration += route.steps[index].durationSeconds;
    }

    return _RemainingEstimate(
      distanceMeters: remainingDistance,
      durationSeconds: remainingDuration.round(),
    );
  }

  Future<void> _announceDepartureIfPresent(MapRoute route) async {
    if (!_voiceEnabled || route.steps.isEmpty) return;

    final departure = route.steps.first;
    if (departure.maneuver != ManeuverType.depart) return;

    await _speak(departure.instruction);
  }

  Future<void> _preAnnounceCurrentStep() async {
    if (!_voiceEnabled) return;
    if (_preAnnouncedStepIndex == state.currentStepIndex) return;

    final step = state.currentStep;
    if (step == null) return;

    _preAnnouncedStepIndex = state.currentStepIndex;

    final language = _languageCode;
    final meters = state.distanceToNextStepMeters.round();
    final text =
        '${_preAnnouncePrefix(language)} $meters '
        '${_metersWord(language)}: ${step.instruction}';

    await _speak(text);
  }

  Future<void> _onArrived() async {
    _offRouteGraceTimer?.cancel();
    _offRouteGraceTimer = null;

    state = state.copyWith(
      distanceToNextStepMeters: 0,
      remainingDistanceMeters: 0,
      remainingDurationSeconds: 0,
      arrived: true,
      isOffRoute: false,
      pendingRerouteConfirmation: false,
    );

    if (_arrivalAnnounced || !_voiceEnabled) return;
    _arrivalAnnounced = true;

    await _speak(_arrivedText(_languageCode));
  }

  Future<void> _speak(String text) async {
    final spoken = await _ref
        .read(voiceServiceProvider)
        .speak(text, _languageCode);

    if (!spoken && mounted) {
      state = state.copyWith(voiceUnavailable: true);
    }
  }

  bool get _voiceEnabled =>
      _ref.read(settingsProvider).voiceEnabled;

  String get _languageCode =>
      _ref.read(settingsProvider).locale.languageCode;

  String _preAnnouncePrefix(String language) {
    return switch (language) {
      'fa' => 'در',
      'ar' => 'بعد',
      _ => 'In',
    };
  }

  String _metersWord(String language) {
    return switch (language) {
      'fa' => 'متر',
      'ar' => 'متر',
      _ => 'meters',
    };
  }

  String _arrivedText(String language) {
    return switch (language) {
      'fa' => 'به مقصد رسیدید',
      'ar' => 'لقد وصلت إلى وجهتك',
      _ => 'You have arrived at your destination',
    };
  }

  @override
  void dispose() {
    _offRouteGraceTimer?.cancel();
    super.dispose();
  }
}

class _RemainingEstimate {
  final double distanceMeters;
  final int durationSeconds;

  const _RemainingEstimate({
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ref);
});
