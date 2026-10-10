import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/map_route.dart';
import '../../../l10n/app_localizations.dart';

class RouteInfoCard extends StatelessWidget {
  final MapRoute route;
  final String? locale;
  final VoidCallback onStart;
  final VoidCallback? onCancel;

  const RouteInfoCard({
    super.key,
    required this.route,
    required this.onStart,
    this.locale,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveLocale =
        locale ?? Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.schedule_rounded,
                    label: l10n.duration,
                    value: Formatters.duration(
                      route.durationSeconds,
                      effectiveLocale,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    icon: Icons.straighten_rounded,
                    label: l10n.distance,
                    value: Formatters.distance(
                      route.distanceMeters,
                      effectiveLocale,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    icon: Icons.traffic_rounded,
                    label: _trafficTitle(effectiveLocale),
                    value: _trafficLabel(
                      route.trafficStatus,
                      l10n,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: onCancel == null ? 1 : 2,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(
                      Icons.navigation_rounded,
                      size: 20,
                    ),
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

  String _trafficLabel(
    String? status,
    AppLocalizations l10n,
  ) {
    switch (status?.toUpperCase()) {
      case 'LOW':
        return l10n.trafficLow;
      case 'MEDIUM':
        return l10n.trafficMedium;
      case 'HIGH':
        return l10n.trafficHigh;
      default:
        return '—';
    }
  }

  String _trafficTitle(String locale) {
    return switch (locale) {
      'fa' => 'ترافیک',
      'ar' => 'المرور',
      _ => 'Traffic',
    };
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
