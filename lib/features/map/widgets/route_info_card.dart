import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/map_route.dart';
import '../../../l10n/app_localizations.dart';

class RouteInfoCard extends StatelessWidget {
  final MapRoute route;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const RouteInfoCard({
    super.key,
    required this.route,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: l10n.duration,
                    value: Formatters.duration(
                      route.durationSeconds,
                      locale,
                    ),
                    icon: Icons.access_time,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: _Stat(
                    label: l10n.distance,
                    value: Formatters.distance(
                      route.distanceMeters,
                      locale,
                    ),
                    icon: Icons.straighten,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.navigation),
                    label: Text(l10n.start),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
