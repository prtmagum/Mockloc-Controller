import 'dart:convert';

class ParsedPoint {
  const ParsedPoint(this.lat, this.lng, {this.swapped = false, this.name, this.group, this.accuracy});
  final double lat, lng;
  final bool swapped;
  final String? name, group;
  final double? accuracy;
}

final _pin = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
final _decimal = RegExp(r'(-?\d{1,3}\.\d+)\s*[,\s]\s*(-?\d{1,3}\.\d+)');
final _dms = RegExp(
  r'''(\d+)°\s*(\d+)['′]\s*([\d.]+)["″]?\s*([NS])[,\s]+(\d+)°\s*(\d+)['′]\s*([\d.]+)["″]?\s*([EW])''',
  caseSensitive: false,
);

/// Mengenali "lat, lng", "lat lng", link Google Maps (pin `!3d!4d` diutamakan
/// dibanding `@`), `geo:` URI, dan derajat-menit-detik.
ParsedPoint? parseCoordinate(String input) {
  final raw = _extract(input);
  return raw == null ? null : _validate(raw.$1, raw.$2);
}

/// Pesan yang jelas kalau [parseCoordinate] mengembalikan null.
String parseFailureMessage(String input) {
  if (input.trim().isEmpty) return 'Tempel koordinat atau link Google Maps';
  if (input.contains('maps.app.goo.gl') || input.contains('goo.gl/maps')) {
    return 'Link pendek belum didukung. Buka di browser, lalu salin link panjangnya.';
  }
  if (_extract(input) != null) return 'Lat harus di antara -90 dan 90, lng di antara -180 dan 180';
  return 'Format tidak dikenali';
}

(double, double)? _extract(String input) {
  final s = input.trim();

  final pin = _pin.firstMatch(s);
  if (pin != null) return (double.parse(pin[1]!), double.parse(pin[2]!));

  final dms = _dms.firstMatch(s);
  if (dms != null) {
    return (
      _dmsToDecimal(dms[1]!, dms[2]!, dms[3]!, dms[4]!),
      _dmsToDecimal(dms[5]!, dms[6]!, dms[7]!, dms[8]!),
    );
  }

  // Menangkap "lat, lng", "lat lng", geo:lat,lng, dan @lat,lng di link Maps.
  final dec = _decimal.firstMatch(s);
  if (dec != null) return (double.parse(dec[1]!), double.parse(dec[2]!));

  return null;
}

double _dmsToDecimal(String d, String m, String sec, String hemi) {
  final v = double.parse(d) + double.parse(m) / 60 + double.parse(sec) / 3600;
  final h = hemi.toUpperCase();
  return (h == 'S' || h == 'W') ? -v : v;
}

ParsedPoint? _validate(double lat, double lng) {
  if (lat.abs() <= 90 && lng.abs() <= 180) return ParsedPoint(lat, lng);
  if (lng.abs() <= 90 && lat.abs() <= 180) return ParsedPoint(lng, lat, swapped: true);
  return null;
}

bool isInIndonesia(double lat, double lng) => lat >= -11 && lat <= 6 && lng >= 95 && lng <= 141;

class BulkResult {
  const BulkResult(this.points, this.badLines);
  final List<ParsedPoint> points;

  /// Nomor baris (mulai dari 1) yang rusak.
  final List<int> badLines;
}

/// Bulk: satu titik per baris, format `nama,lat,lng[,grup[,akurasi]]`.
/// Baris kosong dan header di baris pertama dilewati; baris rusak lainnya
/// dilaporkan per nomor baris.
BulkResult parseBulk(String text) {
  final points = <ParsedPoint>[];
  final bad = <int>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final p = _bulkPoint(line.split(',').map((f) => f.trim()).toList());
    if (p != null) {
      points.add(p);
    } else if (i > 0 || points.isNotEmpty) {
      bad.add(i + 1);
    }
  }
  return BulkResult(points, bad);
}

ParsedPoint? _bulkPoint(List<String> f) {
  if (f.length < 3 || f.length > 5 || f[0].isEmpty) return null;
  final a = double.tryParse(f[1]), b = double.tryParse(f[2]);
  if (a == null || b == null) return null;
  final p = _validate(a, b);
  if (p == null) return null;
  final group = f.length > 3 && f[3].isNotEmpty ? f[3] : null;
  final acc = f.length > 4 ? double.tryParse(f[4]) : null;
  return ParsedPoint(p.lat, p.lng, swapped: p.swapped, name: f[0], group: group, accuracy: acc);
}
