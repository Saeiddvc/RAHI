import 'package:flutter/material.dart';

class RahiSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  const RahiSearchBar({
    super.key,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: colors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
