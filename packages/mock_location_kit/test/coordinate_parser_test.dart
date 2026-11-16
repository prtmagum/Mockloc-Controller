import 'package:flutter_test/flutter_test.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

void main() {
  group('parseCoordinate: enam format menghasilkan titik yang sama', () {
    const lat = -6.9761, lng = 108.4830;
    final inputs = {
      'desimal koma': '-6.9761, 108.4830',
      'desimal spasi': '-6.9761 108.4830',
      'link panjang': 'https://www.google.com/maps/@-6.9761,108.4830,17z',
      'pin tempat': 'https://www.google.com/maps/place/X/@-6.5,108.1,17z/data=!3m1!4b1!3d-6.9761!4d108.4830',
      'geo URI': 'geo:-6.9761,108.4830',
      // Contoh PRD 6°58'34.0" = -6.976111 (selisih 0.0000111°); 33.96" = -6.9761 tepat.
      'DMS': '6°58\'33.96"S 108°28\'58.8"E',
    };
    for (final MapEntry(key: name, value: input) in inputs.entries) {
      test(name, () {
        final p = parseCoordinate(input)!;
        expect(p.lat, closeTo(lat, 0.00001));
        expect(p.lng, closeTo(lng, 0.00001));
        expect(p.swapped, isFalse);
      });
    }
  });

  test('lat/lng tertukar ditukar otomatis', () {
    final p = parseCoordinate('108.4830, -6.9761')!;
    expect(p.lat, closeTo(-6.9761, 1e-9));
    expect(p.lng, closeTo(108.4830, 1e-9));
    expect(p.swapped, isTrue);
  });

  test('di luar rentang ditolak dengan pesan jelas', () {
    expect(parseCoordinate('200.5, 300.5'), isNull);
    expect(parseFailureMessage('200.5, 300.5'), contains('-90'));
    expect(parseFailureMessage('halo'), 'Format tidak dikenali');
    expect(parseFailureMessage('https://maps.app.goo.gl/abc'), contains('Link pendek'));
  });

  test('isInIndonesia', () {
    expect(isInIndonesia(-6.9761, 108.4830), isTrue);
    expect(isInIndonesia(51.5, -0.12), isFalse);
  });

  test('parseBulk: header dilewati, baris rusak dilaporkan per nomor', () {
    final r = parseBulk('nama,lat,lng\nRumah,-6.9761,108.4830\nrusak\n\nKantor,107.6191,-6.9175,Kantor,25\n');
    expect(r.points.map((p) => p.name), ['Rumah', 'Kantor']);
    expect(r.points[1].swapped, isTrue);
    expect(r.points[1].group, 'Kantor');
    expect(r.points[1].accuracy, 25);
    expect(r.badLines, [3]);
  });

  test('parseBulk 200 baris cepat', () {
    final csv = [for (var i = 0; i < 200; i++) 'Titik $i,-6.${1000 + i},108.${2000 + i}'].join('\n');
    final sw = Stopwatch()..start();
    final r = parseBulk(csv);
    expect(r.points, hasLength(200));
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
