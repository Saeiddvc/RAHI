import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/voice_service.dart';
import '../../../data/models/map_route.dart';
import '../../../data/models/route_step.dart';
import '../../../providers/settings_provider.dart';

class NavigationState {
  final MapRoute? route;

  /// Index of the upcoming maneuver target in route.steps.
  final int currentStepIndex;
  final double distanceToNextStepMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final bool arrived;
  final bool isActive;
  final bool voiceUnavailable;

  const NavigationState({
    this.route,
    this.currentStepIndex = 0,
    this.distanceToNextStepMeters = 0,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
    this.arrived = false,
    this.isActive = false,
    this.voiceUnavailable = false,
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

  NavigationState copyWith({
    MapRoute? route,
    int? currentStepIndex,
    double? distanceToNextStepMeters,
    double? remainingDistanceMeters,
    int? remainingDurationSeconds,
    bool? arrived,
    bool? isActive,
    bool? voiceUnavailable,
    bool clearRoute = false,
  }) {
    return NavigationState(
      route: clearRoute ? null : (route ?? this.route),
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
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier(this._ref) : super(const NavigationState());

  final Ref _ref;
  final Distance _distance = const Distance();

  static const double _stepAdvanceThresholdMeters = 30;
  static const double _preAnnounceThresholdMeters = 250;

  int _preAnnouncedStepIndex = -1;
  bool _arrivalAnnounced = false;

  Future<void> start(
    MapRoute route, {
    LatLng? initialLocation,
  }) async {
    _preAnnouncedStepIndex = -1;
    _arrivalAnnounced = false;

    final firstTargetIndex = _initialTargetIndex(route);

    state = NavigationState(
      route: route,
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
    await _ref.read(voiceServiceProvider).stop();
    state = const NavigationState();
    _preAnnouncedStepIndex = -1;
    _arrivalAnnounced = false;
  }

  Future<void> updateUserLocation(LatLng userLocation) async {
    final route = state.route;
    if (!state.isActive || route == null || !route.hasSteps) return;
    if (state.arrived) return;

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
    state = state.copyWith(
      distanceToNextStepMeters: 0,
      remainingDistanceMeters: 0,
      remainingDurationSeconds: 0,
      arrived: true,
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
