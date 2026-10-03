class Formatters {
  Formatters._();

  static String distance(double meters, String locale) {
    if (meters < 1000) {
      return '${meters.round()} ${_m(locale)}';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} ${_km(locale)}';
  }

  static String duration(int seconds, String locale) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes ${_min(locale)}';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours ${_hour(locale)}';

    return '$hours ${_hour(locale)} ${_and(locale)} '
        '$remainingMinutes ${_min(locale)}';
  }

  static String _m(String locale) =>
      locale == 'fa' ? 'متر' : (locale == 'ar' ? 'م' : 'm');

  static String _km(String locale) =>
      locale == 'fa' ? 'کیلومتر' : (locale == 'ar' ? 'كم' : 'km');

  static String _min(String locale) =>
      locale == 'fa' ? 'دقیقه' : (locale == 'ar' ? 'دقيقة' : 'min');

  static String _hour(String locale) =>
      locale == 'fa' ? 'ساعت' : (locale == 'ar' ? 'ساعة' : 'h');

  static String _and(String locale) =>
      locale == 'fa' ? 'و' : (locale == 'ar' ? 'و' : 'and');
}
