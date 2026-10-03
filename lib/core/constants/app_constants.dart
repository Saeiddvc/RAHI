class AppConstants {
  AppConstants._();

  static const String neshanBaseUrl = 'https://api.neshan.org';
  static const String neshanSearchPath = '/v3/search';
  static const String neshanReversePath = '/v5/reverse';
  static const String neshanDirectionPath = '/v4/direction';

  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String userAgent = 'ir.rahi.app';
  static const double defaultZoom = 13;
  static const double defaultLatitude = 32.4279;
  static const double defaultLongitude = 53.6880;
}
