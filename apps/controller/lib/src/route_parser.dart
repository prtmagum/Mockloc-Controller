import 'package:latlong2/latlong.dart';
import 'package:location_core/location_core.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

final _gpxPoint = RegExp(r'<(trkpt|rtept|wpt)\b([^>]*)>');
final _lat = RegExp(r'''\blat\s*=\s*["'](-?[\d.]+)["']''');
final _lon = RegExp(r'''\blon\s*=\s*["'](-?[\d.]+)["']''');
final _kmlCoords = RegExp(r'<coordinates>([\s\S]*?)</coordinates>');

/// Membaca rute dari GPX (`trkpt` > `rtept` > `wpt`), KML (`<coordinates>`),
/// atau teks biasa satu koordinat per baris.
List<LatLng> parseRoute(String text) {
  final gpx = <String, List<LatLng>>{};
  for (final m in _gpxPoint.allMatches(text)) {
    final lat = _lat.firstMatch(m[2]!), lon = _lon.firstMatch(m[2]!);
    if (lat == null || lon == null) continue;
    (gpx[m[1]!] ??= []).add(LatLng(double.parse(lat[1]!), double.parse(lon[1]!)));
  }
  for (final tag in const ['trkpt', 'rtept', 'wpt']) {
    if (gpx[tag]?.isNotEmpty ?? false) return gpx[tag]!;
  }

  final kml = [
    for (final m in _kmlCoords.allMatches(text))
      for (final tuple in m[1]!.trim().split(RegExp(r'\s+')))
        if (tuple.split(',') case [final lng, final lat, ...])
          if ((double.tryParse(lat), double.tryParse(lng)) case (final double a, final double b)) LatLng(a, b),
  ];
  if (kml.isNotEmpty) return kml;

  return [
    for (final line in text.split('\n'))
      if (parseCoordinate(line) case final p?) LatLng(p.lat, p.lng),
  ];
}

/// Panjang polyline dalam meter.
double routeLength(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    total += distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
  }
  return total;
}
