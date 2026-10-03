import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/map_service_provider.dart';

class RahiMap extends ConsumerWidget {
  final LatLng center;
  final List<LatLng>? routePoints;
  final LatLng? destination;

  const RahiMap({
    super.key,
    required this.center,
    this.routePoints,
    this.destination,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(mapServiceProvider);
    final tileUrl = _buildTileUrl(
      service.tileUrlTemplate,
      service.tileUrlParams,
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: AppConstants.defaultZoom,
        minZoom: 4,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: AppConstants.userAgent,
          maxZoom: 19,
        ),
        if (routePoints != null && routePoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints!,
                strokeWidth: 6,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 44,
              height: 44,
              child: const _UserMarker(),
            ),
            if (destination != null)
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

  String _buildTileUrl(
    String template,
    Map<String, String> params,
  ) {
    if (params.isEmpty) return template;

    final encoded = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    return '$template${template.contains('?') ? '&' : '?'}$encoded';
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
