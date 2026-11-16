import 'package:location_core/location_core.dart';
import 'package:test/test.dart';

void main() {
  test('distanceMeters: 1° lintang ≈ 111 km', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 50));
  });

  test('offsetMeters lalu distanceMeters kembali ke jarak semula', () {
    final (lat, lng) = offsetMeters(-6.9761, 108.4830, 20000, 90);
    expect(distanceMeters(-6.9761, 108.4830, lat, lng), closeTo(20000, 1));
    expect(bearingDegrees(-6.9761, 108.4830, lat, lng), closeTo(90, 0.5));
  });

  test('LocationFix toJson/fromJson membawa isMock', () {
    final fix = LocationFix(lat: 1, lng: 2, accuracy: 3, time: DateTime.utc(2026), isMock: true);
    final back = LocationFix.fromJson(fix.toJson());
    expect(back.isMock, isTrue);
    expect(back.lat, 1);
  });
}
