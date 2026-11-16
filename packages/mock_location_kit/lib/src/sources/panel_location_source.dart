import 'dart:convert';

import 'package:location_core/location_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../points/mock_point.dart';
import 'latest_fix.dart';

/// Lokasi yang dipilih langsung dari panel debug in-app (tanpa Controller).
class PanelLocationSource implements LocationSource {
  static const _prefsKey = 'mockloc.panelFix';

  final _latest = LatestFix();

  LocationFix? get last => _latest.fix;
  Object? get lastError => _latest.error;

  void setPoint(MockPoint p) => setFix(LocationFix(
        lat: p.lat,
        lng: p.lng,
        accuracy: p.accuracy,
        time: DateTime.now(),
        isMock: true,
      ));

  void setFix(LocationFix fix) {
    _latest.add(fix);
    _persist(fix);
  }

  void setError(LocationException error) => _latest.addError(error);

  Future<void> restore() async {
    final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
    if (raw == null) return;
    final fix = LocationFix.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
    _latest.add(LocationFix(
      lat: fix.lat,
      lng: fix.lng,
      accuracy: fix.accuracy,
      time: DateTime.now(),
      isMock: true,
    ));
  }

  Future<void> _persist(LocationFix fix) async =>
      (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(fix.toJson()));

  @override
  Stream<LocationFix> watch() => _latest.stream();

  @override
  Future<LocationFix> current() async {
    final error = _latest.error;
    if (error != null) throw error;
    return _latest.fix ?? (throw const GpsUnavailableException('Belum ada titik dipilih di panel debug'));
  }
}
