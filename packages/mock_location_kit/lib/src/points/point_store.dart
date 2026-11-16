import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinate_parser.dart';
import 'mock_point.dart';

class ImportReport {
  const ImportReport(this.added, this.badLines);
  final int added;
  final List<int> badLines;

  String get summary => badLines.isEmpty
      ? '$added titik diimpor'
      : '$added titik diimpor, baris rusak: ${badLines.join(', ')}';
}

/// Daftar preset, disimpan sebagai JSON di SharedPreferences.
class PointStore extends ChangeNotifier {
  PointStore({this.prefsKey = 'mockloc.points'});

  final String prefsKey;
  List<MockPoint> _points = [];

  List<MockPoint> get points => List.unmodifiable(_points);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw != null) {
      _points = [
        for (final m in jsonDecode(raw) as List) MockPoint.fromJson(Map<String, Object?>.from(m as Map)),
      ];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode([for (final p in _points) p.toJson()]));
  }

  /// "Titik N" dengan N terkecil yang belum dipakai.
  String nextDefaultName() {
    final used = _points.map((p) => p.name).toSet();
    var n = 1;
    while (used.contains('Titik $n')) {
      n++;
    }
    return 'Titik $n';
  }

  /// Nama duplikat di grup yang sama diberi akhiran " (2)", " (3)", dst.
  String uniqueName(String name, String group, {String? exceptId}) {
    final taken = {
      for (final p in _points)
        if (p.group == group && p.id != exceptId) p.name,
    };
    if (!taken.contains(name)) return name;
    var n = 2;
    while (taken.contains('$name ($n)')) {
      n++;
    }
    return '$name ($n)';
  }

  Future<MockPoint> add({
    required String name,
    required String group,
    required double lat,
    required double lng,
    double accuracy = 10,
  }) async {
    final p = MockPoint(
      id: newPointId(),
      name: uniqueName(name, group),
      group: group,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
    );
    _points = [..._points, p];
    await _save();
    return p;
  }

  Future<MockPoint> update(MockPoint point) async {
    final p = point.copyWith(name: uniqueName(point.name, point.group, exceptId: point.id));
    _points = [for (final old in _points) old.id == p.id ? p : old];
    await _save();
    return p;
  }

  Future<void> remove(String id) async {
    _points = _points.where((p) => p.id != id).toList();
    await _save();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert([for (final p in _points) p.toJson()]);

  String exportCsv() => [
        'nama,lat,lng,grup,akurasi',
        for (final p in _points)
          '${p.name.replaceAll(',', ' ')},${p.lat},${p.lng},${p.group},${p.accuracy}',
      ].join('\n');

  /// Menerima JSON hasil [exportJson] atau CSV `nama,lat,lng[,grup[,akurasi]]`.
  Future<ImportReport> importText(String text) async {
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('[')) {
      final list = jsonDecode(trimmed) as List;
      for (final m in list) {
        final p = MockPoint.fromJson(Map<String, Object?>.from(m as Map));
        _points = [..._points, p.copyWith(name: uniqueName(p.name, p.group))];
      }
      await _save();
      return ImportReport(list.length, const []);
    }
    final result = parseBulk(text);
    for (final p in result.points) {
      final group = mockGroups.contains(p.group) ? p.group! : 'Lainnya';
      _points = [
        ..._points,
        MockPoint(
          id: newPointId(),
          name: uniqueName(p.name!, group),
          group: group,
          lat: p.lat,
          lng: p.lng,
          accuracy: p.accuracy ?? 10,
        ),
      ];
    }
    await _save();
    return ImportReport(result.points.length, result.badLines);
  }
}
