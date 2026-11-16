import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:location_core/location_core.dart';

/// GPS asli. Satu-satunya file yang boleh memakai `Geolocator`.
class RealLocationSource implements LocationSource {
  @override
  Stream<LocationFix> watch() async* {
    await _ensureReady();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map(_toFix).transform(StreamTransformer.fromHandlers(
          handleError: (e, st, sink) => sink.addError(_mapError(e), st),
        ));
  }

  @override
  Future<LocationFix> current() async {
    await _ensureReady();
    try {
      return _toFix(await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ));
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// Membuka pengaturan lokasi HP (untuk tombol di layar error).
  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Membuka pengaturan izin aplikasi.
  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<void> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const GpsDisabledException();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const GpsPermissionDeniedException();
    }
  }

  /// Error geolocator → error netral dari location_core, supaya UI
  /// menangani GPS asli dan mock dengan cara yang sama.
  static Object _mapError(Object e) => switch (e) {
        LocationServiceDisabledException() => const GpsDisabledException(),
        PermissionDeniedException() => const GpsPermissionDeniedException(),
        TimeoutException() => const GpsTimeoutException(),
        _ => e,
      };

  LocationFix _toFix(Position p) => LocationFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: p.accuracy,
        altitude: p.altitude,
        speed: p.speed,
        bearing: p.heading,
        time: p.timestamp,
        isMock: p.isMocked,
      );
}
