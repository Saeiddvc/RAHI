import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class RahiSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? currentValue;
  final bool showClear;

  const RahiSearchBar({
    super.key,
    required this.hint,
    required this.onTap,
    this.onClear,
    this.currentValue,
    this.showClear = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkText : AppColors.lightText;
    final hintColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final hasValue = currentValue?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? currentValue! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          hasValue ? FontWeight.w500 : FontWeight.w400,
                      color: hasValue ? textColor : hintColor,
                    ),
                  ),
                ),
                if (showClear && hasValue)
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.mic_none_rounded,
                    size: 20,
                    color: hintColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
