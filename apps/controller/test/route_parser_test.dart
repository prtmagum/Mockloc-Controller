import 'package:flutter_test/flutter_test.dart';
import 'package:mockloc_controller/src/route_parser.dart';

void main() {
  test('GPX: trkpt diutamakan, atribut lat/lon urutan bebas', () {
    const gpx = '''
<gpx><wpt lat="1" lon="1"/><trk><trkseg>
  <trkpt lat="-6.9761" lon="108.4830"><ele>10</ele></trkpt>
  <trkpt lon="108.4840" lat="-6.9771"></trkpt>
</trkseg></trk></gpx>''';
    final r = parseRoute(gpx);
    expect(r, hasLength(2));
    expect(r[1].latitude, -6.9771);
    expect(r[1].longitude, 108.4840);
  });

  test('KML: lng,lat,alt', () {
    const kml = '<kml><LineString><coordinates>108.4830,-6.9761,0 108.4840,-6.9771,0</coordinates></LineString></kml>';
    final r = parseRoute(kml);
    expect(r.first.latitude, -6.9761);
    expect(r.last.longitude, 108.4840);
  });

  test('teks: satu koordinat per baris', () {
    final r = parseRoute('-6.9761, 108.4830\n-6.9771, 108.4840');
    expect(r, hasLength(2));
    expect(routeLength(r), greaterThan(100));
  });
}
