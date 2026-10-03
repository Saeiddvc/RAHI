import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'core/constants/app_constants.dart';
import 'features/map/widgets/rahi_map.dart';

void main() {
  runApp(const ProviderScope(child: RahiApp()));
}

class RahiApp extends StatelessWidget {
  const RahiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAHI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
      ),
      home: const RahiHomePage(),
    );
  }
}

class RahiHomePage extends StatelessWidget {
  const RahiHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const center = LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('RAHI | راهی'),
      ),
      body: const RahiMap(center: center),
    );
  }
}
