import 'dart:async';

import 'package:flutter/services.dart';
import 'package:location_core/location_core.dart';

import 'latest_fix.dart';

/// Membaca fix dari aplikasi Controller lewat EventChannel yang dipasang di
/// `android/app/src/dev/kotlin/.../MainActivity.kt` aplikasi target.
class ControllerLocationSource implements LocationSource {
  ControllerLocationSource({this.currentTimeout = const Duration(seconds: 10)});

  static const _events = EventChannel('mock_location_kit/fixes');

  final Duration currentTimeout;
  late final _latest = LatestFix(onStart: _start, onStop: _stop);
  StreamSubscription<Object?>? _native;

  void _start() {
    _native = _events.receiveBroadcastStream().listen(
      (e) {
        try {
          _latest.add(decodeControllerFix(e));
        } on LocationException catch (err) {
          _latest.addError(err);
        }
      },
      onError: (Object err) => _latest.addError(GpsUnavailableException(
        err is MissingPluginException
            ? 'EventChannel mock belum dipasang di MainActivity flavor dev'
            : 'Controller error: $err',
      )),
    );
  }

  void _stop() {
    _native?.cancel();
    _native = null;
    _latest.reset();
  }

  @override
  Stream<LocationFix> watch() => _latest.stream();

  @override
  Future<LocationFix> current() =>
      watch().first.timeout(currentTimeout, onTimeout: () => throw const GpsTimeoutException());
}

/// Mengubah satu baris dari ContentProvider Controller menjadi [LocationFix],
/// atau melempar [LocationException] untuk skenario error.
LocationFix decodeControllerFix(Object? event) {
  final m = Map<Object?, Object?>.from(event as Map);
  switch (m['error']) {
    case 'service_disabled':
      throw const GpsDisabledException();
    case 'permission_denied':
      throw const GpsPermissionDeniedException();
    case 'timeout':
      throw const GpsTimeoutException();
    case 'no_fix':
      throw const GpsUnavailableException('Controller belum mengirim lokasi');
    case 'controller_unavailable':
      throw const GpsUnavailableException(
          'Controller tidak terpasang atau tanda tangan APK berbeda');
    case 'not_allowed':
      throw const GpsUnavailableException('Aplikasi ini tidak ada di allowlist Controller');
    case final String code:
      throw GpsUnavailableException('Error Controller: $code');
  }
  return LocationFix(
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    accuracy: (m['accuracy'] as num).toDouble(),
    altitude: (m['altitude'] as num?)?.toDouble(),
    speed: (m['speed'] as num?)?.toDouble(),
    bearing: (m['bearing'] as num?)?.toDouble(),
    time: DateTime.fromMillisecondsSinceEpoch((m['time'] as num).toInt()),
    isMock: true,
  );
}
