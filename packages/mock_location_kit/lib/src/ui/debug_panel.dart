import 'package:flutter/material.dart';
import 'package:location_core/location_core.dart';

import '../points/mock_point.dart';
import '../points/point_store.dart';
import '../sources/switchable_location_source.dart';
import 'add_point_sheet.dart';
import 'preset_list.dart';

/// Panel debug in-app (FR-05): pilih mode, aktifkan preset, atau picu
/// skenario error tanpa membuka Controller.
class DebugPanel extends StatefulWidget {
  const DebugPanel({
    super.key,
    required this.source,
    required this.store,
    required this.userAgentPackageName,
    this.onClose,
  });

  final SwitchableLocationSource source;
  final PointStore store;
  final String userAgentPackageName;
  final VoidCallback? onClose;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late final _fixes = widget.source.watch();
  String? _activeId;

  void _activate(MockPoint p) {
    widget.source.panel.setPoint(p);
    widget.source.mode.value = MockMode.panel;
    setState(() => _activeId = p.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Mock aktif: ${p.name}')));
  }

  void _error(LocationException e) {
    widget.source.panel.setError(e);
    widget.source.mode.value = MockMode.panel;
    setState(() => _activeId = null);
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MockLoc Debug'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
        actions: [PresetMenuButton(store: widget.store)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Tambah titik'),
        onPressed: () => showAddPointSheet(
          context,
          store: widget.store,
          userAgentPackageName: widget.userAgentPackageName,
          onActivate: _activate,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ValueListenableBuilder(
              valueListenable: source.mode,
              builder: (context, mode, _) => SegmentedButton<MockMode>(
                segments: [
                  for (final m in MockMode.values) ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => source.mode.value = s.first,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<LocationFix>(
              stream: _fixes,
              builder: (context, snap) => _StatusCard(snap: snap),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              ActionChip(
                avatar: const Icon(Icons.location_disabled, size: 18),
                label: const Text('GPS mati'),
                onPressed: () => _error(const GpsDisabledException()),
              ),
              ActionChip(
                avatar: const Icon(Icons.block, size: 18),
                label: const Text('Izin ditolak'),
                onPressed: () => _error(const GpsPermissionDeniedException()),
              ),
              ActionChip(
                avatar: const Icon(Icons.timer_off, size: 18),
                label: const Text('Timeout'),
                onPressed: () => _error(const GpsTimeoutException()),
              ),
            ]),
          ),
          const Divider(height: 24),
          Expanded(
            child: PresetList(
              store: widget.store,
              userAgentPackageName: widget.userAgentPackageName,
              activeId: _activeId,
              onActivate: _activate,
              padding: const EdgeInsets.only(bottom: 88),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snap});

  final AsyncSnapshot<LocationFix> snap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, color) = switch (snap) {
      AsyncSnapshot(hasError: true, :final error) => (
          Icons.error_outline,
          error is LocationException ? error.message : '$error',
          scheme.error,
        ),
      AsyncSnapshot(hasData: true, data: final fix?) => (
          fix.isMock ? Icons.gps_not_fixed : Icons.gps_fixed,
          '${fix.lat.toStringAsFixed(6)}, ${fix.lng.toStringAsFixed(6)}\n'
              '±${fix.accuracy.toStringAsFixed(0)} m · ${fix.isMock ? 'MOCK' : 'asli'}',
          fix.isMock ? scheme.error : scheme.primary,
        ),
      _ => (Icons.hourglass_empty, 'Menunggu lokasi…', scheme.outline),
    };
    return Card.outlined(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text),
      ),
    );
  }
}
