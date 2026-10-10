import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/location_provider.dart';
import '../map/widgets/rahi_map.dart';
import 'providers/navigation_provider.dart';
import 'widgets/maneuver_banner.dart';
import 'widgets/nav_bottom_card.dart';
import 'widgets/remaining_steps_sheet.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() =>
      _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _rerouteDialogOpen = false;
  bool _followUser = true;

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
    final locale = Localizations.localeOf(context).languageCode;

    ref.listen<LocationMotion?>(locationMotionProvider, (previous, next) {
      if (next == null) return;

      unawaited(
        ref
            .read(navigationProvider.notifier)
            .updateUserLocation(next.location),
      );

      if (!_followUser) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          if (next.hasUsableHeading) {
            _mapController.moveAndRotate(
              next.location,
              17,
              next.headingDegrees,
            );
          } else {
            _mapController.move(next.location, 16);
          }
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

    final currentStep = navigation.currentStep;
    final distanceText = Formatters.distance(
      navigation.distanceToNextStepMeters,
      locale,
    );
    final instructionText = currentStep?.instruction ?? '';
    final remainingDistanceText = Formatters.distance(
      navigation.remainingDistanceMeters,
      locale,
    );
    final remainingDurationText = Formatters.duration(
      navigation.remainingDurationSeconds,
      locale,
    );
    final etaText = _computeEta(navigation.remainingDurationSeconds);

    return Scaffold(
      body: Stack(
        children: [
          RahiMap(
            mapController: _mapController,
            center: center,
            routes: [route],
            selectedRouteIndex: 0,
            destination: navigation.destination?.location ??
                (route.points.isNotEmpty ? route.points.last : null),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                ManeuverBanner(
                  step: currentStep,
                  distanceText: distanceText,
                  instructionText: instructionText,
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
              top: MediaQuery.paddingOf(context).top + 112,
              left: 12,
              right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.loading),
                    ],
                  ),
                ),
              ),
            ),
          if (navigation.isOffRoute && !navigation.isRerouting)
            Positioned(
              left: 12,
              right: 12,
              bottom: 174,
              child: _OffRouteBanner(
                title: l10n.offRoute,
                message: l10n.offRouteHint,
              ),
            ),
          if (!navigation.arrived && navigation.remainingSteps.isNotEmpty)
            PositionedDirectional(
              end: 16,
              bottom: 194,
              child: FloatingActionButton.small(
                heroTag: 'remaining_steps_fab',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 3,
                onPressed: _openRemainingSteps,
                tooltip: l10n.remainingSteps,
                child: const Icon(Icons.list_alt_rounded),
              ),
            ),
          if (!navigation.arrived)
            PositionedDirectional(
              end: 16,
              bottom: 252,
              child: FloatingActionButton.small(
                heroTag: 'follow_fab',
                backgroundColor:
                    _followUser ? AppColors.primary : Colors.white,
                foregroundColor:
                    _followUser ? Colors.white : AppColors.primary,
                elevation: 3,
                onPressed: () {
                  setState(() => _followUser = !_followUser);

                  if (_followUser && userLocation != null) {
                    final motion = ref.read(locationMotionProvider);
                    try {
                      if (motion != null && motion.hasUsableHeading) {
                        _mapController.moveAndRotate(
                          userLocation,
                          17,
                          motion.headingDegrees,
                        );
                      } else {
                        _mapController.move(userLocation, 16);
                      }
                    } catch (_) {
                      // Map may not yet be attached.
                    }
                  }
                },
                tooltip: l10n.myLocation,
                child: Icon(
                  _followUser
                      ? Icons.my_location_rounded
                      : Icons.explore_outlined,
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: NavBottomCard(
                remainingDistanceText: remainingDistanceText,
                durationText: remainingDurationText,
                etaText: etaText,
                exitLabel: l10n.exitNavigation,
                onExit: _exitNavigation,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _computeEta(int remainingSeconds) {
    final arrival = DateTime.now().add(
      Duration(seconds: remainingSeconds),
    );
    final hour = arrival.hour.toString().padLeft(2, '0');
    final minute = arrival.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.offRouteDismiss),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
          top: Radius.circular(AppTheme.radiusLarge),
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

class _VoiceWarning extends StatelessWidget {
  final String message;

  const _VoiceWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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

class _OffRouteBanner extends StatelessWidget {
  final String title;
  final String message;

  const _OffRouteBanner({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
