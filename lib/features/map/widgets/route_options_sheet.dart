import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/map_route.dart';
import '../../../l10n/app_localizations.dart';

class RouteOptionsSheet extends StatelessWidget {
  final List<MapRoute> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const RouteOptionsSheet({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      l10n.routeFound,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${routes.length}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    final isSelected = index == selectedIndex;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Material(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelected(index),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Formatters.duration(
                                          route.durationSeconds,
                                          locale,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Formatters.distance(
                                          route.distanceMeters,
                                          locale,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      if (route.summary != null &&
                                          route.summary!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          route.summary!,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
