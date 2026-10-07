import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/map_route.dart';
import '../../../providers/location_provider.dart';

class RahiMap extends ConsumerWidget {
  final MapController mapController;
  final LatLng center;
  final List<MapRoute> routes;
  final int selectedRouteIndex;
  final LatLng? destination;
  final ValueChanged<LatLng>? onCenterChanged;

  const RahiMap({
    super.key,
    required this.mapController,
    required this.center,
    this.routes = const [],
    this.selectedRouteIndex = 0,
    this.destination,
    this.onCenterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLocation = ref.watch(locationProvider);
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: AppConstants.defaultZoom,
        minZoom: 4,
        maxZoom: 19,
        onPositionChanged: (camera, _) {
          onCenterChanged?.call(camera.center);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: AppConstants.userAgent,
          maxZoom: 19,
        ),
        if (routes.isNotEmpty)
          PolylineLayer(
            polylines: _buildRoutePolylines(context),
          ),
        if (userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation,
                width: 44,
                height: 44,
                child: const _UserMarker(),
              ),
            ],
          ),
        if (destination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: destination!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Polyline> _buildRoutePolylines(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final alternate = Theme.of(context)
        .colorScheme
        .secondary
        .withValues(alpha: 0.50);

    final polylines = <Polyline>[];

    for (var index = 0; index < routes.length; index++) {
      if (index == selectedRouteIndex || routes[index].points.isEmpty) {
        continue;
      }

      polylines.add(
        Polyline(
          points: routes[index].points,
          strokeWidth: 4,
          color: alternate,
        ),
      );
    }

    if (selectedRouteIndex >= 0 &&
        selectedRouteIndex < routes.length &&
        routes[selectedRouteIndex].points.isNotEmpty) {
      polylines.add(
        Polyline(
          points: routes[selectedRouteIndex].points,
          strokeWidth: 6,
          color: primary,
        ),
      );
    }

    return polylines;
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.22),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}
