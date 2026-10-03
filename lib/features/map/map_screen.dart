import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/location_provider.dart';
import 'widgets/locate_fab.dart';
import 'widgets/rahi_map.dart';
import 'widgets/search_bar.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userLocation = ref.watch(locationProvider);

    final center = userLocation ??
        const LatLng(
          AppConstants.defaultLat,
          AppConstants.defaultLng,
        );

    return Scaffold(
      body: Stack(
        children: [
          RahiMap(
            mapController: _mapController,
            center: center,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: RahiSearchBar(
                    hint: l10n.searchPlaceholder,
                    onTap: () => _showSearchSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                _IconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => context.push('/settings'),
                  tooltip: l10n.settings,
                ),
              ],
            ),
          ),
          PositionedDirectional(
            bottom: 24,
            end: 16,
            child: LocateFab(
              isLoading: _locating,
              onTap: _locateUser,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _locateUser() async {
    if (_locating) return;

    setState(() => _locating = true);
    await ref.read(locationProvider.notifier).refresh();

    if (!mounted) return;

    final location = ref.read(locationProvider);
    if (location != null) {
      _mapController.move(location, AppConstants.defaultZoom);
    } else {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noLocationAccess)),
      );
    }

    if (mounted) {
      setState(() => _locating = false);
    }
  }

  void _showSearchSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(
              child: Text(
                l10n.comingSoon,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}
