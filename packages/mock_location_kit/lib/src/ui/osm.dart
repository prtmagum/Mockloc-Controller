import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tile OpenStreetMap. flutter_map tidak pernah membaca GPS perangkat, jadi
/// peta hanya menampilkan titik yang kita berikan.
TileLayer osmTileLayer(String userAgentPackageName) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: userAgentPackageName,
    );

/// Atribusi wajib sesuai kebijakan tile server OSM.
Widget osmAttribution() => const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors'));
