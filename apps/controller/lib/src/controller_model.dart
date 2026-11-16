import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_core/location_core.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

import 'bridge.dart';
import 'route_parser.dart';

const userAgentPackageName = 'id.replay.mockloc.controller';

/// Parameter fix (FR-07), dipakai untuk titik dari peta dan preset.
class FixParams {
  const FixParams({
    this.accuracy = 10,
    this.altitude,
    this.bearing,
    this.speedKmh = 0,
    this.jitter = 0,
  });

  final double accuracy;
  final double? altitude, bearing;
  final double speedKmh, jitter;

  FixParams copyWith({
    double? accuracy,
    double? Function()? altitude,
    double? Function()? bearing,
    double? speedKmh,
    double? jitter,
  }) =>
      FixParams(
        accuracy: accuracy ?? this.accuracy,
        altitude: altitude == null ? this.altitude : altitude(),
        bearing: bearing == null ? this.bearing : bearing(),
        speedKmh: speedKmh ?? this.speedKmh,
        jitter: jitter ?? this.jitter,
      );
}

class ControllerModel extends ChangeNotifier {
  ControllerModel({MockBridge? bridge, PointStore? store})
      : bridge = bridge ?? MockBridge(),
        store = store ?? PointStore();

  final MockBridge bridge;
  final PointStore store;

  Snapshot snapshot = const Snapshot();
  FixParams params = const FixParams();

  /// Titik hasil tap di peta yang belum dikirim.
  LatLng? pending;
  String? activePresetId;

  /// Titik terakhir yang dikirim (tanpa jitter), untuk skenario & "terapkan ulang".
  LatLng? lastSent;
  double lastAccuracy = 10;
  LatLng? _teleportOrigin;
  bool get teleported => _teleportOrigin != null;

  List<LatLng> route = [];
  bool drawingRoute = false;
  double routeSpeedKmh = 40;
  bool routeLoop = false;

  SystemStatus system = const SystemStatus();

  StreamSubscription<Snapshot>? _sub;

  void init() {
    store.load();
    refreshSystem();
    _sub = bridge.snapshots().listen((s) {
      snapshot = s;
      final p = s.fix?.point;
      if (lastSent == null && p != null && !s.route.active) {
        lastSent = p;
        lastAccuracy = s.fix?.accuracy ?? 10;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // --- Titik diam ---------------------------------------------------------

  void onMapTap(LatLng p) {
    if (drawingRoute) {
      route = [...route, p];
    } else {
      pending = p;
    }
    notifyListeners();
  }

  void clearPending() {
    pending = null;
    notifyListeners();
  }

  Future<void> sendPending() async {
    final p = pending;
    if (p == null) return;
    pending = null;
    activePresetId = null;
    await sendPoint(p, accuracy: params.accuracy);
  }

  Future<void> activatePreset(MockPoint point) async {
    activePresetId = point.id;
    await sendPoint(LatLng(point.lat, point.lng), accuracy: point.accuracy);
  }

  /// Mengirim titik diam. Kalau jitter > 0, RouteService dipakai dengan rute
  /// satu titik supaya posisi bergoyang tiap detik.
  Future<void> sendPoint(LatLng p, {required double accuracy, double? jitter}) async {
    lastSent = p;
    lastAccuracy = accuracy;
    _teleportOrigin = null;
    notifyListeners();
    final j = jitter ?? params.jitter;
    final speed = params.speedKmh > 0 ? params.speedKmh / 3.6 : null;
    if (j > 0) {
      await bridge.startRoute(
        [p],
        speedKmh: 0,
        loop: true,
        accuracy: accuracy,
        jitter: j,
        altitude: params.altitude,
        bearing: params.bearing,
        speed: speed,
      );
    } else {
      await bridge.setFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: accuracy,
        altitude: params.altitude,
        speed: speed,
        bearing: params.bearing,
      );
    }
  }

  void setParams(FixParams value) {
    params = value;
    notifyListeners();
  }

  Future<void> resendWithParams() async {
    final p = lastSent;
    if (p != null) await sendPoint(p, accuracy: params.accuracy);
  }

  // --- Skenario (FR-08) ---------------------------------------------------

  Future<void> sendError(String code) async {
    activePresetId = null;
    notifyListeners();
    await bridge.setError(code);
  }

  /// Kembali ke titik terakhir setelah skenario error.
  Future<void> restore() async {
    final p = lastSent;
    if (p != null) await sendPoint(p, accuracy: lastAccuracy);
  }

  Future<void> poorSignal() async {
    final p = lastSent;
    if (p != null) await sendPoint(p, accuracy: 150, jitter: 60);
  }

  /// Geser titik [meters] ke utara, mis. untuk uji "di luar area".
  Future<void> shift(double meters) async {
    final p = lastSent;
    if (p == null) return;
    final (lat, lng) = offsetMeters(p.latitude, p.longitude, meters, 0);
    activePresetId = null;
    await sendPoint(LatLng(lat, lng), accuracy: lastAccuracy);
  }

  /// Lompat 20 km ke timur dalam satu fix; tap lagi untuk kembali.
  Future<void> teleport() async {
    final origin = _teleportOrigin;
    if (origin != null) {
      await sendPoint(origin, accuracy: lastAccuracy);
      return;
    }
    final p = lastSent;
    if (p == null) return;
    final (lat, lng) = offsetMeters(p.latitude, p.longitude, 20000, 90);
    await bridge.setFix(lat: lat, lng: lng, accuracy: lastAccuracy);
    _teleportOrigin = p;
    notifyListeners();
  }

  Future<void> stopMock() async {
    activePresetId = null;
    lastSent = null;
    _teleportOrigin = null;
    notifyListeners();
    await bridge.clear();
  }

  // --- Mode Sistem --------------------------------------------------------

  Future<void> refreshSystem() async {
    system = await bridge.systemStatus();
    notifyListeners();
  }

  Future<void> setSystemMock(bool enabled) async {
    system = await bridge.setSystemMock(enabled);
    notifyListeners();
  }

  /// Null kalau berhasil, atau pesan error.
  Future<String?> grantViaRoot() async {
    final error = await bridge.grantViaRoot();
    await refreshSystem();
    return error;
  }

  // --- Rute (FR-06) -------------------------------------------------------

  double get routeMeters => routeLength(route);

  void toggleDrawing() {
    drawingRoute = !drawingRoute;
    pending = null;
    notifyListeners();
  }

  void undoRoutePoint() {
    if (route.isEmpty) return;
    route = route.sublist(0, route.length - 1);
    notifyListeners();
  }

  void clearRoute() {
    route = [];
    notifyListeners();
  }

  /// Mengembalikan jumlah titik yang terbaca.
  int importRoute(String text) {
    final points = parseRoute(text);
    if (points.isNotEmpty) {
      route = points;
      drawingRoute = false;
      notifyListeners();
    }
    return points.length;
  }

  void setRouteSpeed(double kmh) {
    routeSpeedKmh = kmh;
    notifyListeners();
  }

  void setRouteLoop(bool value) {
    routeLoop = value;
    notifyListeners();
  }

  Future<void> startRoute() async {
    if (route.length < 2) return;
    drawingRoute = false;
    activePresetId = null;
    lastSent = route.last;
    lastAccuracy = params.accuracy;
    notifyListeners();
    await bridge.startRoute(
      route,
      speedKmh: routeSpeedKmh,
      loop: routeLoop,
      accuracy: params.accuracy,
      jitter: params.jitter,
      altitude: params.altitude,
    );
  }
}
