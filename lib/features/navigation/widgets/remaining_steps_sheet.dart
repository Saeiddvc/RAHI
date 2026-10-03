import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/route_step.dart';
import '../../../l10n/app_localizations.dart';

class RemainingStepsSheet extends StatelessWidget {
  final List<RouteStep> steps;

  const RemainingStepsSheet({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
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
                      l10n.remainingSteps,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${steps.length}',
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
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    final isCurrent = index == 0;

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _iconFor(step.maneuver),
                          size: 22,
                          color: isCurrent
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        step.instruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        Formatters.distance(
                          step.distanceMeters,
                          locale,
                        ),
                        style: const TextStyle(fontSize: 12),
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
