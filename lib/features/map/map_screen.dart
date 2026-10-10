import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/map_route.dart';
import '../../data/models/place.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../navigation/providers/navigation_provider.dart';
import 'providers/routing_provider.dart';
import 'providers/search_provider.dart';
import 'widgets/locate_fab.dart';
import 'widgets/rahi_map.dart';
import 'widgets/route_info_card.dart';
import 'widgets/route_options_sheet.dart';
import 'widgets/search_bar.dart';
import 'widgets/search_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();

  LatLng _mapCenter = const LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );
  bool _locating = false;
  bool _didAutoCenterOnLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userLocation = ref.watch(locationProvider);
    final accessStatus = ref.watch(locationAccessProvider);
    final locationError = ref.watch(locationErrorProvider);
    final routing = ref.watch(routingProvider);

    final center = userLocation ?? _mapCenter;
    final selectedRoute = routing.selectedRoute;

    ref.listen<LatLng?>(locationProvider, (previous, next) {
      if (next == null || _didAutoCenterOnLocation || routing.hasRoutes) {
        return;
      }

      _didAutoCenterOnLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(next, 15);
        _mapCenter = next;
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          RahiMap(
            mapController: _mapController,
            center: center,
            routes: routing.routes,
            selectedRouteIndex: routing.selectedIndex,
            destination: routing.destination?.location,
            onCenterChanged: (newCenter) {
              _mapCenter = newCenter;
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                if (accessStatus == LocationAccessStatus.deniedForever)
                  _PermissionBanner(
                    icon: Icons.location_off_rounded,
                    message: l10n.locationPermissionPermanentlyDenied,
                    actionLabel: l10n.openSettings,
                    onAction: _openAppSettings,
                  ),
                if (accessStatus == LocationAccessStatus.serviceDisabled)
                  _PermissionBanner(
                    icon: Icons.location_disabled_rounded,
                    message: l10n.locationServiceDisabled,
                    actionLabel: l10n.openLocationSettings,
                    onAction: _openLocationSettings,
                  ),
                if (accessStatus == LocationAccessStatus.reducedAccuracy)
                  _PermissionBanner(
                    icon: Icons.gps_off_rounded,
                    message: locationError ?? l10n.noLocationAccess,
                    actionLabel: l10n.openSettings,
                    onAction: _openAppSettings,
                  ),
                if (accessStatus == LocationAccessStatus.deniedForever ||
                    accessStatus == LocationAccessStatus.serviceDisabled ||
                    accessStatus == LocationAccessStatus.reducedAccuracy)
                  const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RahiSearchBar(
                        hint: l10n.searchPlaceholder,
                        currentValue: routing.destination?.title,
                        showClear: routing.destination != null,
                        onClear: () {
                          ref.read(routingProvider.notifier).clear();
                        },
                        onTap: _openSearchSheet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.settings_outlined,
                      onTap: () => context.push('/settings'),
                      tooltip: l10n.settings,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!routing.hasRoutes)
            PositionedDirectional(
              bottom: 24,
              end: 16,
              child: LocateFab(
                isLoading: _locating,
                onTap: _locateUser,
              ),
            ),
          if (routing.routes.length > 1 && !routing.isLoading)
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + 80,
              end: 12,
              child: _RoundIconButton(
                icon: Icons.alt_route,
                onTap: _openRouteOptionsSheet,
                tooltip: l10n.routeType,
              ),
            ),
          if (selectedRoute != null && !routing.isLoading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RouteInfoCard(
                route: selectedRoute,
                locale: Localizations.localeOf(context).languageCode,
                onStart: () => _onStartNavigation(selectedRoute),
                onCancel: () {
                  ref.read(routingProvider.notifier).clear();
                },
              ),
            ),
          if (routing.isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          if (routing.error != null && routing.routes.isEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 80,
              left: 12,
              right: 12,
              child: _ErrorCard(
                message: routing.error!,
                actionLabel: l10n.cancel,
                onDismiss: () {
                  ref.read(routingProvider.notifier).clear();
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _locateUser() async {
    if (_locating) return;

    setState(() => _locating = true);

    final location = await ref
        .read(locationProvider.notifier)
        .acquireFreshLocation();

    if (!mounted) return;

    if (location != null) {
      _mapController.move(location, 16);
      _mapCenter = location;
      _didAutoCenterOnLocation = true;
    } else {
      _showLocationError();
    }

    if (mounted) {
      setState(() => _locating = false);
    }
  }

  void _showLocationError() {
    final message = ref.read(locationErrorProvider) ??
        AppLocalizations.of(context)!.noLocationAccess;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAppSettings() async {
    ref.read(locationProvider.notifier).markWentToSettings();
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    ref.read(locationProvider.notifier).markWentToSettings();
    await Geolocator.openLocationSettings();
  }

  Future<void> _openSearchSheet() async {
    ref.read(searchProvider.notifier).clear();

    final searchCenter = ref.read(locationProvider) ?? _mapCenter;

    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return SearchSheet(
          searchCenter: searchCenter,
          onPlaceSelected: (selectedPlace) {
            Navigator.of(sheetContext).pop(selectedPlace);
          },
        );
      },
    );

    if (!mounted || place == null) return;
    await _onDestinationSelected(place);
  }

  Future<void> _onDestinationSelected(Place place) async {
    final userLocation = await ref
        .read(locationProvider.notifier)
        .acquireFreshLocation();

    if (!mounted) return;

    if (userLocation == null) {
      _showLocationError();
      return;
    }

    final settings = ref.read(settingsProvider);

    await ref.read(routingProvider.notifier).calculateRoute(
          origin: userLocation,
          destination: place,
          type: settings.routeType,
        );

    if (!mounted) return;

    final routing = ref.read(routingProvider);
    final selectedRoute = routing.selectedRoute;

    if (selectedRoute != null) {
      _zoomToRoute(selectedRoute.points);
    }
  }

  Future<void> _openRouteOptionsSheet() async {
    final routing = ref.read(routingProvider);

    final index = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return RouteOptionsSheet(
          routes: routing.routes,
          selectedIndex: routing.selectedIndex,
          onSelected: (selectedIndex) {
            Navigator.of(sheetContext).pop(selectedIndex);
          },
        );
      },
    );

    if (!mounted || index == null) return;

    ref.read(routingProvider.notifier).selectRoute(index);
    final selectedRoute = ref.read(routingProvider).selectedRoute;

    if (selectedRoute != null) {
      _zoomToRoute(selectedRoute.points);
    }
  }

  void _zoomToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 220),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _onStartNavigation(MapRoute route) async {
    if (!route.hasSteps) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.serviceNotAvailable,
          ),
        ),
      );
      return;
    }

    final routing = ref.read(routingProvider);
    final userLocation = await ref
        .read(locationProvider.notifier)
        .acquireFreshLocation();

    if (!mounted) return;

    if (userLocation == null) {
      _showLocationError();
      return;
    }

    await ref.read(navigationProvider.notifier).start(
          route,
          destination: routing.destination,
          initialLocation: userLocation,
        );

    if (!mounted) return;
    context.push('/navigation');
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onDismiss;

  const _ErrorCard({
    required this.message,
    required this.actionLabel,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          12,
          8,
          12,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionBanner({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: scheme.onErrorContainer,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
