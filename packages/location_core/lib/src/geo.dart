import 'dart:math' as math;

const _earthRadius = 6371008.8;

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Jarak great-circle (haversine) dalam meter.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1), dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

/// Arah awal dari titik 1 ke titik 2, 0–360° searah jarum jam dari utara.
double bearingDegrees(double lat1, double lng1, double lat2, double lng2) {
  final p1 = _rad(lat1), p2 = _rad(lat2), dl = _rad(lng2 - lng1);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Titik tujuan dari [lat],[lng] sejauh [meters] ke arah [bearing] derajat.
(double lat, double lng) offsetMeters(double lat, double lng, double meters, double bearing) {
  final d = meters / _earthRadius, b = _rad(bearing), p1 = _rad(lat), l1 = _rad(lng);
  final p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b));
  final l2 = l1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2));
  return (_deg(p2), (_deg(l2) + 540) % 360 - 180);
}
