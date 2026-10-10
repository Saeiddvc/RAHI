import 'package:flutter/material.dart';

/// پالت رنگی راهی — طراحی‌شده برای هماهنگی با نقشه و UI مدرن.
class AppColors {
  AppColors._();

  // رنگ‌های اصلی
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primarySurface = Color(0xFFEFF6FF);

  // رنگ‌های معنایی
  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEE2E2);

  // Compatibility alias for the previous palette API.
  static const Color secondary = success;

  // ترافیک
  static const Color trafficLow = Color(0xFF16A34A);
  static const Color trafficMedium = Color(0xFFF59E0B);
  static const Color trafficHigh = Color(0xFFDC2626);

  // تم روشن
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Compatibility alias for the previous palette API.
  static const Color lightBg = lightBackground;

  // تم تاریک
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Compatibility alias for the previous palette API.
  static const Color darkBg = darkBackground;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
