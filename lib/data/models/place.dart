import 'package:latlong2/latlong.dart';

class Place {
  final String title;
  final String address;
  final LatLng location;
  final String? neighbourhood;
  final String? region;

  const Place({
    required this.title,
    required this.address,
    required this.location,
    this.neighbourhood,
    this.region,
  });

  factory Place.fromNeshanJson(Map<String, dynamic> json) {
    final rawLocation = json['location'];
    final location = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : <String, dynamic>{};

    return Place(
      title: json['title']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      location: LatLng(
        (location['y'] as num?)?.toDouble() ?? 0,
        (location['x'] as num?)?.toDouble() ?? 0,
      ),
      neighbourhood: json['neighbourhood']?.toString(),
      region: json['region']?.toString(),
    );
  }
}
