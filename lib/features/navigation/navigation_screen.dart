import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/route_step.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/location_provider.dart';
import '../map/widgets/rahi_map.dart';
import 'providers/navigation_provider.dart';
import 'widgets/remaining_steps_sheet.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() =>
      _NavigationScreenState();
}

class _NavigationScreenState
    extends ConsumerState<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _rerouteDialogOpen = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navigation = ref.watch(navigationProvider);
    final userLocation = ref.watch(locationProvider);
    final route = navigation.route;

    ref.listen<LatLng?>(locationProvider, (previous, next) {
      if (next == null) return;

      unawaited(
        ref.read(navigationProvider.notifier).updateUserLocation(next),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          _mapController.move(next, 16);
        } catch (_) {
          // The map controller may not yet be attached on the first frame.
        }
      });
    });

    ref.listen<bool>(
      navigationProvider.select(
        (state) => state.pendingRerouteConfirmation,
      ),
      (previous, next) {
        if (next && !_rerouteDialogOpen) {
          unawaited(_showRerouteDialog());
        }
      },
    );

    ref.listen<String?>(
      navigationProvider.select((state) => state.rerouteError),
      (previous, next) {
        if (next == null || next == previous) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.errorOccurred}: $next'),
            ),
          );

          ref
              .read(navigationProvider.notifier)
              .clearRerouteError();
        });
      },
    );

    if (route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const SizedBox.shrink();
    }

    final center = userLocation ??
        (route.points.isNotEmpty
            ? route.points.first
            : const LatLng(
                AppConstants.defaultLat,
                AppConstants.defaultLng,
              ));

    return Scaffold(
      body: Stack(
        children: [
          RahiMap(
            mapController: _mapController,
            center: center,
            routes: [route],
            selectedRouteIndex: 0,
            destination:
                navigation.destination?.location ??
                (route.points.isNotEmpty ? route.points.last : null),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            right: 8,
            child: Column(
              children: [
                _ManeuverBanner(
                  step: navigation.currentStep,
                  distance: navigation.distanceToNextStepMeters,
                  locale: Localizations.localeOf(context).languageCode,
                  arrived: navigation.arrived,
                ),
                if (navigation.voiceUnavailable) ...[
                  const SizedBox(height: 8),
                  _VoiceWarning(message: l10n.voiceNotAvailable),
                ],
              ],
            ),
          ),
          if (navigation.isRerouting)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 86,
              left: 12,
              right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.loading),
                    ],
                  ),
                ),
              ),
            ),
          if (!navigation.arrived && navigation.remainingSteps.isNotEmpty)
            PositionedDirectional(
              end: 16,
              bottom: 210,
              child: FloatingActionButton.small(
                heroTag: 'remaining_steps_fab',
                onPressed: _openRemainingSteps,
                tooltip: l10n.remainingSteps,
                child: const Icon(Icons.list_alt),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _NavigationBottomCard(
              remainingDistanceMeters:
                  navigation.remainingDistanceMeters,
              remainingDurationSeconds:
                  navigation.remainingDurationSeconds,
              isOffRoute:
                  navigation.isOffRoute && !navigation.isRerouting,
              onExit: _exitNavigation,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRerouteDialog() async {
    if (_rerouteDialogOpen || !mounted) return;

    _rerouteDialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    final userLocation = ref.read(locationProvider);

    if (userLocation == null) {
      ref.read(navigationProvider.notifier).dismissReroute();
      _rerouteDialogOpen = false;
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.alt_route, size: 32),
          title: Text(l10n.offRouteTitle),
          content: Text(l10n.offRouteMessage),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: Text(l10n.offRouteDismiss),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: Text(l10n.offRouteReroute),
            ),
          ],
        );
      },
    );

    _rerouteDialogOpen = false;

    if (!mounted) return;

    if (confirmed == true) {
      await ref
          .read(navigationProvider.notifier)
          .acceptReroute(userLocation);
    } else {
      ref.read(navigationProvider.notifier).dismissReroute();
    }
  }

  Future<void> _openRemainingSteps() async {
    final steps = ref.read(navigationProvider).remainingSteps;
    if (steps.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) => RemainingStepsSheet(steps: steps),
    );
  }

  Future<void> _exitNavigation() async {
    await ref.read(navigationProvider.notifier).stop();

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _ManeuverBanner extends StatelessWidget {
  final RouteStep? step;
  final double distance;
  final String locale;
  final bool arrived;

  const _ManeuverBanner({
    required this.step,
    required this.distance,
    required this.locale,
    required this.arrived,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    if (arrived) {
      return Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        color: colors.secondary,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.arrived,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (step == null) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: colors.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _iconFor(step!.maneuver),
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.distance(distance, locale),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step!.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ManeuverType maneuver) {
    return switch (maneuver) {
      ManeuverType.turnLeft => Icons.turn_left,
      ManeuverType.turnRight => Icons.turn_right,
      ManeuverType.turnSlightLeft => Icons.turn_slight_left,
      ManeuverType.turnSlightRight => Icons.turn_slight_right,
      ManeuverType.turnSharpLeft => Icons.turn_sharp_left,
      ManeuverType.turnSharpRight => Icons.turn_sharp_right,
      ManeuverType.uTurn => Icons.u_turn_left,
      ManeuverType.straight => Icons.straight,
      ManeuverType.roundabout => Icons.roundabout_left,
      ManeuverType.merge => Icons.merge,
      ManeuverType.fork => Icons.fork_left,
      ManeuverType.onRamp => Icons.ramp_right,
      ManeuverType.offRamp => Icons.ramp_left,
      ManeuverType.arrive => Icons.flag,
      ManeuverType.depart => Icons.navigation,
      ManeuverType.unknown => Icons.navigation_outlined,
    };
  }
}

class _VoiceWarning extends StatelessWidget {
  final String message;

  const _VoiceWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              Icons.volume_off_outlined,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBottomCard extends StatelessWidget {
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final bool isOffRoute;
  final VoidCallback onExit;

  const _NavigationBottomCard({
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.isOffRoute,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return SafeArea(
      top: false,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOffRoute) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.offRoute,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.offRouteHint,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.straighten,
                      label: l10n.remaining,
                      value: Formatters.distance(
                        remainingDistanceMeters,
                        locale,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.access_time,
                      label: l10n.duration,
                      value: Formatters.duration(
                        remainingDurationSeconds,
                        locale,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onExit,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.exitNavigation),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
