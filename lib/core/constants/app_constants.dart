class AppConstants {
  AppConstants._();

  static const String appName = 'راهی';
  static const String appNameEn = 'RAHI';
  static const String tagline = 'Smart Navigation';

  static const String neshanBaseUrl = 'https://api.neshan.org';
  static const String neshanSearchPath = '/v3/search';
  static const String neshanReversePath = '/v5/reverse';
  static const String neshanDirectionPath = '/v4/direction';
  static const String neshanTileUrl =
      'https://api.neshan.org/v4/static/tile/{z}/{x}/{y}';

  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String parsimapBaseUrl = 'https://api.parsimap.ir';
  static const String parsimapReversePath = '/geocode/reverse';
  static const String parsimapRasterStylePath =
      '/styles/parsimap-streets-v11-raster';
  static const String parsimapTileUrl =
      'https://api.parsimap.ir/tile/parsimap-streets-v11-raster/{z}/{x}/{y}';

  static const String userAgent = 'ir.rahi.app';

  static const double defaultLat = 35.6892;
  static const double defaultLng = 51.3890;
  static const double defaultLatitude = defaultLat;
  static const double defaultLongitude = defaultLng;
  static const double defaultZoom = 13;
}
