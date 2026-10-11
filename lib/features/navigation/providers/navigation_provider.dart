import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/voice_service.dart';
import '../../../data/models/map_route.dart';
import '../../../data/models/place.dart';
import '../../../data/models/route_step.dart';
import '../../../providers/map_service_provider.dart';
import '../../../providers/settings_provider.dart';
import '../utils/off_route_detector.dart';
import '../utils/route_progress_matcher.dart';

class NavigationState {
  final MapRoute? route;
  final Place? destination;

  /// Index of the upcoming maneuver target in route.steps.
  final int currentStepIndex;
  final double distanceToNextStepMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final LatLng? matchedLocation;
  final double distanceFromRouteMeters;
  final double routeProgressMeters;
  final double routeProgressFraction;
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
    this.matchedLocation,
    this.distanceFromRouteMeters = 0,
    this.routeProgressMeters = 0,
    this.routeProgressFraction = 0,
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
    LatLng? matchedLocation,
    double? distanceFromRouteMeters,
    double? routeProgressMeters,
    double? routeProgressFraction,
    bool? arrived,
    bool? isActive,
    bool? voiceUnavailable,
    bool? isOffRoute,
    bool? isRerouting,
    bool? pendingRerouteConfirmation,
    String? rerouteError,
    bool clearRoute = false,
    bool clearMatchedLocation = false,
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
      matchedLocation: clearMatchedLocation
          ? null
          : (matchedLocation ?? this.matchedLocation),
      distanceFromRouteMeters:
          distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      routeProgressMeters:
          routeProgressMeters ?? this.routeProgressMeters,
      routeProgressFraction:
          routeProgressFraction ?? this.routeProgressFraction,
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

  static const double _stepAdvanceThresholdMeters = 20;
  static const double _arrivalThresholdMeters = 25;
  static const double _preAnnounceThresholdMeters = 250;
  static const double _mapMatchThresholdMeters = 35;
  static const Duration _offRouteGrace = Duration(seconds: 6);

  int _preAnnouncedStepIndex = -1;
  bool _arrivalAnnounced = false;
  bool _rerouteOfferedForCurrentOffRoute = false;
  Timer? _offRouteGraceTimer;

  double? _lastPolylineProgressMeters;
  double? _lastRouteProgressMeters;
  double _routeMetricLengthMeters = 0;
  List<double> _stepTargetMeters = const [];

  Future<void> start(
    MapRoute route, {
    Place? destination,
    LatLng? initialLocation,
  }) async {
    _resetRerouteTracking();
    _preAnnouncedStepIndex = -1;
    _arrivalAnnounced = false;
    _prepareRouteProgress(route);

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
    _resetRouteProgress();
  }

  Future<void> updateUserLocation(LatLng userLocation) async {
    final route = state.route;
    if (!state.isActive || route == null) return;
    if (state.arrived) return;

    final projection = RouteProgressMatcher.project(
      userLocation,
      route.points,
      previousDistanceAlongMeters: _lastPolylineProgressMeters,
    );

    if (projection == null || projection.totalPolylineMeters <= 0) {
      await _updateLegacyProgress(userLocation, route);
      return;
    }

    final distanceFromRoute = projection.distanceToRouteMeters;
    _updateOffRouteDistance(distanceFromRoute);

    final canAdvanceProgress =
        distanceFromRoute <= OffRouteDetector.offRouteThresholdMeters;

    if (canAdvanceProgress) {
      final candidateRouteProgress =
          projection.progressFraction * _routeMetricLengthMeters;

      if (_lastRouteProgressMeters == null ||
          candidateRouteProgress > _lastRouteProgressMeters!) {
        _lastRouteProgressMeters = candidateRouteProgress;
      }

      if (_lastPolylineProgressMeters == null ||
          projection.distanceAlongPolylineMeters >
              _lastPolylineProgressMeters!) {
        _lastPolylineProgressMeters =
            projection.distanceAlongPolylineMeters;
      }
    }

    final routeProgress = (_lastRouteProgressMeters ?? 0)
        .clamp(0.0, _routeMetricLengthMeters);
    final progressFraction = _routeMetricLengthMeters <= 0
        ? projection.progressFraction
        : (routeProgress / _routeMetricLengthMeters)
            .clamp(0.0, 1.0);
    final remainingDistance =
        (_routeMetricLengthMeters - routeProgress)
            .clamp(0.0, _routeMetricLengthMeters);

    final matchedLocation =
        distanceFromRoute <= _mapMatchThresholdMeters
            ? projection.snappedPoint
            : userLocation;

    if (routeProgress > 0 &&
        remainingDistance <= _arrivalThresholdMeters) {
      state = state.copyWith(
        matchedLocation: matchedLocation,
        distanceFromRouteMeters: distanceFromRoute,
        routeProgressMeters: routeProgress,
        routeProgressFraction: progressFraction,
        remainingDistanceMeters: remainingDistance,
      );
      await _onArrived();
      return;
    }

    if (!route.hasSteps) {
      state = state.copyWith(
        matchedLocation: matchedLocation,
        distanceFromRouteMeters: distanceFromRoute,
        routeProgressMeters: routeProgress,
        routeProgressFraction: progressFraction,
        remainingDistanceMeters: remainingDistance,
        remainingDurationSeconds: _proportionalDuration(
          route,
          remainingDistance,
        ),
      );
      return;
    }

    var stepIndex = state.currentStepIndex.clamp(
      0,
      route.steps.length - 1,
    );

    while (stepIndex < route.steps.length) {
      final targetMeters = _targetMetersForStep(
        route,
        stepIndex,
      );
      final distanceToTarget =
          (targetMeters - routeProgress).clamp(0.0, double.infinity);

      if (distanceToTarget > _stepAdvanceThresholdMeters) {
        break;
      }

      if (_isArrivalTarget(route, stepIndex)) {
        if (remainingDistance <= _arrivalThresholdMeters) {
          state = state.copyWith(
            matchedLocation: matchedLocation,
            distanceFromRouteMeters: distanceFromRoute,
            routeProgressMeters: routeProgress,
            routeProgressFraction: progressFraction,
            remainingDistanceMeters: remainingDistance,
          );
          await _onArrived();
          return;
        }
        break;
      }

      if (stepIndex >= route.steps.length - 1) {
        break;
      }

      stepIndex++;
      _preAnnouncedStepIndex = -1;
    }

    final targetMeters = _targetMetersForStep(
      route,
      stepIndex,
    );
    final distanceToTarget =
        (targetMeters - routeProgress).clamp(0.0, double.infinity);

    final remainingDuration = _remainingDurationFromProgress(
      route: route,
      stepIndex: stepIndex,
      routeProgressMeters: routeProgress,
      remainingDistanceMeters: remainingDistance,
    );

    state = state.copyWith(
      currentStepIndex: stepIndex,
      distanceToNextStepMeters: distanceToTarget,
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds: remainingDuration,
      matchedLocation: matchedLocation,
      distanceFromRouteMeters: distanceFromRoute,
      routeProgressMeters: routeProgress,
      routeProgressFraction: progressFraction,
    );

    if (distanceToTarget <= _preAnnounceThresholdMeters) {
      await _preAnnounceCurrentStep();
    }
  }

  Future<void> _updateLegacyProgress(
    LatLng userLocation,
    MapRoute route,
  ) async {
    final distanceToRoute = OffRouteDetector.distanceToRoute(
      userLocation,
      route.points,
    );
    _updateOffRouteDistance(distanceToRoute);

    if (!route.hasSteps) {
      state = state.copyWith(
        matchedLocation: userLocation,
        distanceFromRouteMeters: distanceToRoute,
      );
      return;
    }

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
      matchedLocation: userLocation,
      distanceFromRouteMeters: distanceToRoute,
    );

    if (distanceToTarget <= _preAnnounceThresholdMeters) {
      await _preAnnounceCurrentStep();
    }
  }

  void _updateOffRouteDistance(double distanceToRoute) {
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
      final service = _ref.read(routingServiceProvider);
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
      _prepareRouteProgress(newRoute);

      state = state.copyWith(
        route: newRoute,
        currentStepIndex: firstTargetIndex,
        distanceToNextStepMeters: 0,
        remainingDistanceMeters: newRoute.distanceMeters,
        remainingDurationSeconds: newRoute.durationSeconds,
        routeProgressMeters: 0,
        routeProgressFraction: 0,
        distanceFromRouteMeters: 0,
        arrived: false,
        isRerouting: false,
        isOffRoute: false,
        pendingRerouteConfirmation: false,
        clearMatchedLocation: true,
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

  void _prepareRouteProgress(MapRoute route) {
    _lastPolylineProgressMeters = null;
    _lastRouteProgressMeters = null;

    final polylineLength = _polylineLength(route.points);
    _routeMetricLengthMeters =
        route.distanceMeters > 0 ? route.distanceMeters : polylineLength;

    if (!route.hasSteps) {
      _stepTargetMeters = const [];
      return;
    }

    final targets = <double>[];
    var cumulative = 0.0;

    for (var index = 0; index < route.steps.length; index++) {
      if (index > 0) {
        cumulative += route.steps[index - 1].distanceMeters;
      }

      targets.add(
        _routeMetricLengthMeters > 0
            ? cumulative.clamp(0.0, _routeMetricLengthMeters)
            : cumulative,
      );
    }

    if (targets.isNotEmpty &&
        route.steps.last.maneuver == ManeuverType.arrive &&
        _routeMetricLengthMeters > 0) {
      targets[targets.length - 1] = _routeMetricLengthMeters;
    }

    _stepTargetMeters = List<double>.unmodifiable(targets);
  }

  void _resetRouteProgress() {
    _lastPolylineProgressMeters = null;
    _lastRouteProgressMeters = null;
    _routeMetricLengthMeters = 0;
    _stepTargetMeters = const [];
  }

  double _polylineLength(List<LatLng> points) {
    if (points.length < 2) return 0;

    var total = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      total += _metersBetween(points[index], points[index + 1]);
    }
    return total;
  }

  double _targetMetersForStep(
    MapRoute route,
    int stepIndex,
  ) {
    if (stepIndex >= 0 && stepIndex < _stepTargetMeters.length) {
      return _stepTargetMeters[stepIndex];
    }

    if (_routeMetricLengthMeters > 0 &&
        stepIndex >= route.steps.length - 1) {
      return _routeMetricLengthMeters;
    }

    return 0;
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

  int _remainingDurationFromProgress({
    required MapRoute route,
    required int stepIndex,
    required double routeProgressMeters,
    required double remainingDistanceMeters,
  }) {
    if (!route.hasSteps ||
        stepIndex <= 0 ||
        stepIndex >= route.steps.length ||
        _stepTargetMeters.length != route.steps.length) {
      return _proportionalDuration(route, remainingDistanceMeters);
    }

    var remainingDuration = 0.0;
    final activeStepIndex = stepIndex - 1;
    final activeStep = route.steps[activeStepIndex];
    final segmentStart = _stepTargetMeters[activeStepIndex];
    final segmentEnd = _stepTargetMeters[stepIndex];
    final segmentLength = segmentEnd - segmentStart;

    if (segmentLength > 0 && activeStep.durationSeconds > 0) {
      final remainingSegment =
          (segmentEnd - routeProgressMeters)
              .clamp(0.0, segmentLength);
      final ratio = remainingSegment / segmentLength;
      remainingDuration += activeStep.durationSeconds * ratio;
    }

    for (var index = stepIndex;
        index < route.steps.length;
        index++) {
      remainingDuration += route.steps[index].durationSeconds;
    }

    if (remainingDuration <= 0 && remainingDistanceMeters > 0) {
      return _proportionalDuration(route, remainingDistanceMeters);
    }

    return remainingDuration.round();
  }

  int _proportionalDuration(
    MapRoute route,
    double remainingDistanceMeters,
  ) {
    if (route.durationSeconds <= 0 ||
        route.distanceMeters <= 0 ||
        remainingDistanceMeters <= 0) {
      return 0;
    }

    final ratio =
        (remainingDistanceMeters / route.distanceMeters)
            .clamp(0.0, 1.0);
    return (route.durationSeconds * ratio).round();
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
      routeProgressMeters: _routeMetricLengthMeters,
      routeProgressFraction: 1,
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
