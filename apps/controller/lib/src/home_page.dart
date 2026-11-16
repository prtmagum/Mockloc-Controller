import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

import 'bridge.dart';
import 'controller_model.dart';
import 'map_view.dart';
import 'tabs/about_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/params_tab.dart';
import 'tabs/presets_tab.dart';
import 'tabs/route_tab.dart';
import 'tabs/scenario_tab.dart';
import 'tabs/system_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.model});

  final ControllerModel model;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 7, vsync: this);
  final _map = MapController();

  ControllerModel get model => widget.model;

  @override
  void dispose() {
    _tabs.dispose();
    _map.dispose();
    super.dispose();
  }

  void _addPoint({String? initialText}) => showAddPointSheet(
        context,
        store: model.store,
        userAgentPackageName: userAgentPackageName,
        initialText: initialText,
        onActivate: model.activatePreset,
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([model, model.store]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('MockLoc Controller'),
            actions: [
              IconButton(
                tooltip: 'Tambah titik',
                icon: const Icon(Icons.add_location_alt),
                onPressed: _addPoint,
              ),
              IconButton(
                tooltip: 'Hentikan mock',
                icon: const Icon(Icons.location_off),
                onPressed: model.stopMock,
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              flex: 5,
              child: MockMap(
                model: model,
                controller: _map,
                onSavePending: (text) => _addPoint(initialText: text),
              ),
            ),
            _StatusBar(snapshot: model.snapshot, system: model.system.enabled),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Titik'),
                Tab(text: 'Sistem'),
                Tab(text: 'Rute'),
                Tab(text: 'Parameter'),
                Tab(text: 'Skenario'),
                Tab(text: 'Lainnya'),
                Tab(text: 'Tentang'),
              ],
            ),
            Expanded(
              flex: 6,
              child: TabBarView(controller: _tabs, children: [
                PresetsTab(model: model, onAdd: _addPoint),
                SystemTab(model: model),
                RouteTab(model: model),
                ParamsTab(model: model),
                ScenarioTab(model: model),
                MoreTab(model: model),
                AboutTab(model: model),
              ]),
            ),
          ]),
        ),
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.snapshot, required this.system});

  final Snapshot snapshot;

  /// Mode Sistem aktif: Google Maps & aplikasi lain ikut melihat lokasi mock.
  final bool system;

  static const _errors = {
    'service_disabled': 'Skenario: GPS mati',
    'permission_denied': 'Skenario: izin ditolak',
    'timeout': 'Skenario: timeout',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fix = snapshot.fix;
    final route = snapshot.route;
    final (icon, text, color) = switch (fix) {
      null => (Icons.location_disabled, 'Tidak ada lokasi mock yang dibagikan', scheme.outline),
      SharedFix(error: final String code) => (Icons.error_outline, _errors[code] ?? 'Error: $code', scheme.error),
      SharedFix(:final lat?, :final lng?) => (
          Icons.gps_fixed,
          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)} · ±${fix.accuracy?.toStringAsFixed(0)} m'
              '${route.active ? route.isStatic ? ' · jitter' : ' · rute ${(route.progress * 100).toStringAsFixed(0)}%' : ''}'
              '${route.state == 'paused' ? ' (dijeda)' : ''}'
              '${system ? ' · SISTEM' : ''}',
          scheme.error,
        ),
      _ => (Icons.help_outline, 'Fix tidak lengkap', scheme.outline),
    };
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}
