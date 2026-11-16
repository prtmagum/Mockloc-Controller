/// Error lokasi yang netral terhadap sumber. RealLocationSource memetakan
/// exception geolocator ke kelas-kelas ini, dan sumber mock melempar kelas
/// yang sama, sehingga UI cukup menangani satu jenis error.
sealed class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Layanan lokasi (GPS) di HP dimatikan.
class GpsDisabledException extends LocationException {
  const GpsDisabledException([super.message = 'Layanan lokasi mati']);
}

/// Izin lokasi ditolak pengguna.
class GpsPermissionDeniedException extends LocationException {
  const GpsPermissionDeniedException([super.message = 'Izin lokasi ditolak']);
}

/// Tidak ada fix dalam batas waktu.
class GpsTimeoutException extends LocationException {
  const GpsTimeoutException([super.message = 'Waktu tunggu lokasi habis']);
}

/// Sumber lokasi tidak tersedia sama sekali.
class GpsUnavailableException extends LocationException {
  const GpsUnavailableException([super.message = 'Lokasi tidak tersedia']);
}
