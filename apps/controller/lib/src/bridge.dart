import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Fix yang sedang dibagikan provider (atau kode error skenario).
class SharedFix {
  const SharedFix({
    this.lat,
    this.lng,
    this.accuracy,
    this.altitude,
    this.speed,
    this.bearing,
    required this.time,
    this.error,
  });

  final double? lat, lng, accuracy, altitude, speed, bearing;
  final DateTime time;
  final String? error;

  LatLng? get point => lat == null || lng == null ? null : LatLng(lat!, lng!);

  factory SharedFix.fromMap(Map<Object?, Object?> m) {
    double? d(String k) => (m[k] as num?)?.toDouble();
    return SharedFix(
      lat: d('lat'),
      lng: d('lng'),
      accuracy: d('accuracy'),
      altitude: d('altitude'),
      speed: d('speed'),
      bearing: d('bearing'),
      time: DateTime.fromMillisecondsSinceEpoch((m['time'] as num).toInt()),
      error: m['error'] as String?,
    );
  }
}

class RouteStatus {
  const RouteStatus({
    this.state = 'idle',
    this.traveled = 0,
    this.total = 0,
    this.speedKmh = 0,
    this.isStatic = false,
  });

  final String state; // idle, running, paused, finished
  final double traveled, total, speedKmh;
  final bool isStatic;

  bool get active => state == 'running' || state == 'paused';
  double get progress => total <= 0 ? 0 : (traveled / total).clamp(0, 1);

  factory RouteStatus.fromMap(Map<Object?, Object?> m) => RouteStatus(
        state: m['state'] as String? ?? 'idle',
        traveled: (m['traveled'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num?)?.toDouble() ?? 0,
        speedKmh: (m['speedKmh'] as num?)?.toDouble() ?? 0,
        isStatic: m['isStatic'] as bool? ?? false,
      );
}

/// Status mode Sistem (mock location Android lewat Opsi Pengembang / root).
class SystemStatus {
  const SystemStatus({
    this.enabled = false,
    this.active = false,
    this.devOptions = false,
    this.mockApp = false,
    this.locationPermission = false,
    this.playServices = false,
    this.lastError,
  });

  final bool enabled, active, devOptions, mockApp, locationPermission, playServices;
  final String? lastError;

  /// Siap dipakai: izin AppOps mock location sudah diberikan.
  bool get ready => mockApp;

  factory SystemStatus.fromMap(Map<Object?, Object?> m) => SystemStatus(
        enabled: m['enabled'] as bool? ?? false,
        active: m['active'] as bool? ?? false,
        devOptions: m['devOptions'] as bool? ?? false,
        mockApp: m['mockApp'] as bool? ?? false,
        locationPermission: m['locationPermission'] as bool? ?? false,
        playServices: m['playServices'] as bool? ?? false,
        lastError: m['lastError'] as String?,
      );
}

class Snapshot {
  const Snapshot({this.fix, this.route = const RouteStatus()});
  final SharedFix? fix;
  final RouteStatus route;

  factory Snapshot.fromEvent(Object? e) {
    final m = Map<Object?, Object?>.from(e as Map);
    final fix = m['fix'] as Map?;
    final route = m['route'] as Map?;
    return Snapshot(
      fix: fix == null ? null : SharedFix.fromMap(fix),
      route: route == null ? const RouteStatus() : RouteStatus.fromMap(route),
    );
  }
}

/// Jembatan ke MainActivity/RouteService/MockLocationProvider di sisi Android.
class MockBridge {
  static const _control = MethodChannel('mockloc/control');
  static const _state = EventChannel('mockloc/state');

  Stream<Snapshot> snapshots() => _state.receiveBroadcastStream().map(Snapshot.fromEvent);

  Future<void> setFix({
    required double lat,
    required double lng,
    required double accuracy,
    double? altitude,
    double? speed,
    double? bearing,
  }) =>
      _control.invokeMethod('setFix', {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'bearing': bearing,
      });

  /// `service_disabled`, `permission_denied`, atau `timeout`.
  Future<void> setError(String code) => _control.invokeMethod('setError', {'code': code});

  Future<void> clear() => _control.invokeMethod('clear');

  Future<void> startRoute(
    List<LatLng> points, {
    required double speedKmh,
    required bool loop,
    required double accuracy,
    double jitter = 0,
    double? altitude,
    double? bearing,
    double? speed,
  }) =>
      _control.invokeMethod('startRoute', {
        'points': Float64List.fromList([for (final p in points) ...[p.latitude, p.longitude]]),
        'speedKmh': speedKmh,
        'loop': loop,
        'accuracy': accuracy,
        'jitter': jitter,
        'altitude': altitude,
        'bearing': bearing,
        'speed': speed,
      });

  Future<void> pauseRoute() => _control.invokeMethod('pauseRoute');
  Future<void> resumeRoute() => _control.invokeMethod('resumeRoute');
  Future<void> stopRoute() => _control.invokeMethod('stopRoute');

  Future<String> historyCsv() async => await _control.invokeMethod<String>('history') ?? '';
  Future<void> clearHistory() => _control.invokeMethod('clearHistory');

  Future<SystemStatus> systemStatus() async =>
      SystemStatus.fromMap(await _control.invokeMapMethod<Object?, Object?>('systemStatus') ?? const {});

  Future<SystemStatus> setSystemMock(bool enabled) async => SystemStatus.fromMap(
      await _control.invokeMapMethod<Object?, Object?>('setSystemMock', {'enabled': enabled}) ?? const {});

  /// Null kalau berhasil, atau pesan error.
  Future<String?> grantViaRoot() => _control.invokeMethod<String>('grantViaRoot');

  Future<void> openDevSettings() => _control.invokeMethod('openDevSettings');

  /// Membuka link di aplikasi yang sesuai (WhatsApp, Instagram, browser).
  Future<bool> openUrl(String url) async => await _control.invokeMethod<bool>('openUrl', {'url': url}) ?? false;

  Future<String> appVersion() async => await _control.invokeMethod<String>('appVersion') ?? '';

  Future<List<String>> allowlist() async =>
      (await _control.invokeListMethod<String>('getAllowlist')) ?? const [];
  Future<void> setAllowlist(List<String> packages) =>
      _control.invokeMethod('setAllowlist', {'packages': packages});
}
