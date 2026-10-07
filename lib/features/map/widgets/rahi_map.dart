import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/tile_diagnostics.dart';
import '../../../data/models/location_fix.dart';
import '../../../data/models/map_route.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/map_service_provider.dart';
import '../../../providers/tile_diagnostics_provider.dart';

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
    final locationFix = ref.watch(locationFixProvider);
    final tileTemplate = ref.watch(tileTemplateProvider);
    final resolvedTemplate = tileTemplate.asData?.value;
    final usingFallback =
        resolvedTemplate == null || resolvedTemplate.isEmpty;
    // A resolved Parsimap template is already fully authenticated by the
    // Style API. Use it verbatim; only fall back when resolution fails.
    final tileUrl =
        usingFallback ? AppConstants.osmTileUrl : resolvedTemplate;

    final diagnostics = kDebugMode
        ? ref.watch(
            tileDiagnosticsProvider(
              TileDiagnosticsRequest(
                activeUrlTemplate: tileUrl,
                usingFallback: usingFallback,
              ),
            ),
          )
        : null;

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
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
          urlTemplate: tileUrl,
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
    ),
        ),
        if (kDebugMode)
          Positioned(
            top: 104,
            left: 12,
            right: 12,
            child: _TileDiagnosticsOverlay(
              diagnostics: diagnostics!,
              locationFix: locationFix,
            ),
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


class _TileDiagnosticsOverlay extends StatelessWidget {
  final AsyncValue<TileDiagnosticsReport> diagnostics;
  final LocationFix? locationFix;

  const _TileDiagnosticsOverlay({
    required this.diagnostics,
    required this.locationFix,
  });

  @override
  Widget build(BuildContext context) {
    final tileLines = diagnostics.when(
      data: (report) => report.lines,
      loading: () => const ['TILE DIAG: running...'],
      error: (error, _) => [
        'TILE DIAG: provider error',
        error.runtimeType.toString(),
      ],
    );

    final fix = locationFix;
    final locationLine = fix == null
        ? 'loc: no fix'
        : 'loc: ${fix.source.name} | acc ${fix.accuracyMeters.round()}m | '
            'age ${fix.ageSeconds}s | mock ${fix.isMocked ? "YES" : "no"} | '
            'sat ${_fmt(fix.satellitesUsedInFix)}/${_fmt(fix.satelliteCount)}';

    final lines = [...tileLines, locationLine];

    return IgnorePointer(
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            lines.join('\n'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.35,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
  static String _fmt(double? value) {
    if (value == null) return '-';
    return value.round().toString();
  }

}
