import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:location_core/location_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controller_location_source.dart';
import 'panel_location_source.dart';

enum MockMode {
  real('Asli'),
  controller('Controller'),
  panel('Panel');

  const MockMode(this.label);
  final String label;
}

/// Sumber yang bisa dialihkan Real/Mock saat aplikasi berjalan.
///
/// Saat mode mock aktif, langganan ke [real] dibatalkan, jadi GPS asli
/// benar-benar tidak dibaca (bukan cuma disembunyikan).
class SwitchableLocationSource implements LocationSource {
  SwitchableLocationSource({
    required this.real,
    LocationSource? mock,
    PanelLocationSource? panel,
    MockMode initialMode = MockMode.real,
  })  : mock = mock ?? ControllerLocationSource(),
        panel = panel ?? PanelLocationSource(),
        mode = ValueNotifier(initialMode) {
    mode.addListener(_persistMode);
  }

  static const _prefsKey = 'mockloc.mode';

  /// Membuat sumber dengan mode dan titik panel terakhir yang tersimpan,
  /// supaya GPS asli tidak sempat dibaca kalau sebelumnya mode mock.
  static Future<SwitchableLocationSource> restore({
    required LocationSource real,
    LocationSource? mock,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = MockMode.values.asNameMap()[prefs.getString(_prefsKey)];
    final panel = PanelLocationSource();
    await panel.restore();
    return SwitchableLocationSource(
      real: real,
      mock: mock,
      panel: panel,
      initialMode: saved ?? MockMode.real,
    );
  }

  final LocationSource real;
  final LocationSource mock;
  final PanelLocationSource panel;
  final ValueNotifier<MockMode> mode;

  bool get isMock => mode.value != MockMode.real;

  LocationSource get active => switch (mode.value) {
        MockMode.real => real,
        MockMode.controller => mock,
        MockMode.panel => panel,
      };

  Future<void> _persistMode() async =>
      (await SharedPreferences.getInstance()).setString(_prefsKey, mode.value.name);

  @override
  Stream<LocationFix> watch() => Stream.multi((c) {
        StreamSubscription<LocationFix>? sub;
        void attach() {
          sub?.cancel();
          sub = active.watch().listen(c.add, onError: c.addError);
        }

        attach();
        mode.addListener(attach);
        c.onCancel = () {
          mode.removeListener(attach);
          return sub?.cancel();
        };
      });

  @override
  Future<LocationFix> current() => active.current();
}
