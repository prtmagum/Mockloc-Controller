import 'location_fix.dart';

/// Satu-satunya pintu aplikasi untuk membaca lokasi.
///
/// Error dikirim sebagai [LocationException] (lihat `errors.dart`), baik dari
/// GPS asli maupun dari mock, supaya alur error di UI sama persis.
abstract interface class LocationSource {
  Stream<LocationFix> watch();
  Future<LocationFix> current();
}
