import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class LocateFab extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const LocateFab({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: Tooltip(
        message: l10n.myLocation,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: isLoading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                  ),
          ),
        ),
      ),
    );
  }
}
