import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../points/coordinate_parser.dart';
import '../points/mock_point.dart';
import '../points/point_store.dart';
import 'osm.dart';

/// Membuka sheet "+ Tambah titik" (FR-12). Kalau [editing] diisi, sheet
/// berfungsi sebagai form edit.
Future<MockPoint?> showAddPointSheet(
  BuildContext context, {
  required PointStore store,
  required String userAgentPackageName,
  MockPoint? editing,
  String? initialText,
  void Function(MockPoint point)? onActivate,
}) =>
    showModalBottomSheet<MockPoint>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddPointSheet(
        store: store,
        userAgentPackageName: userAgentPackageName,
        editing: editing,
        initialText: initialText,
        onActivate: onActivate,
      ),
    );

class AddPointSheet extends StatefulWidget {
  const AddPointSheet({
    super.key,
    required this.store,
    required this.userAgentPackageName,
    this.editing,
    this.initialText,
    this.onActivate,
  });

  final PointStore store;
  final String userAgentPackageName;
  final MockPoint? editing;
  final String? initialText;
  final void Function(MockPoint point)? onActivate;

  @override
  State<AddPointSheet> createState() => _AddPointSheetState();
}

class _AddPointSheetState extends State<AddPointSheet> {
  final _input = TextEditingController();
  final _name = TextEditingController();
  final _accuracy = TextEditingController(text: '10');
  String _group = mockGroups.last;
  ParsedPoint? _parsed;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _input.text = e.coordText;
      _name.text = e.name;
      _group = e.group;
      _accuracy.text = _fmt(e.accuracy);
    } else {
      _name.text = widget.store.nextDefaultName();
      if (widget.initialText != null) {
        _input.text = widget.initialText!;
      } else {
        _prefillFromClipboard();
      }
    }
    _parse();
  }

  Future<void> _prefillFromClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted || text == null || _input.text.isNotEmpty) return;
    if (parseCoordinate(text) != null) {
      _input.text = text.trim();
      _parse();
    }
  }

  void _parse() => setState(() => _parsed = parseCoordinate(_input.text));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save({required bool activate}) async {
    final p = _parsed;
    if (p == null) return;
    final name = _name.text.trim().isEmpty ? widget.store.nextDefaultName() : _name.text.trim();
    final accuracy = double.tryParse(_accuracy.text.replaceAll(',', '.')) ?? 10;
    final editing = widget.editing;
    final saved = editing == null
        ? await widget.store.add(name: name, group: _group, lat: p.lat, lng: p.lng, accuracy: accuracy)
        : await widget.store.update(
            editing.copyWith(name: name, group: _group, lat: p.lat, lng: p.lng, accuracy: accuracy));
    if (activate) widget.onActivate?.call(saved);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  void dispose() {
    _input.dispose();
    _name.dispose();
    _accuracy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _parsed;
    final theme = Theme.of(context);
    final warnings = [
      if (p != null && p.swapped) 'lat/lng tertukar, urutannya sudah ditukar otomatis',
      if (p != null && !isInIndonesia(p.lat, p.lng)) 'Titik di luar wilayah Indonesia',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.editing == null ? 'Tambah titik' : 'Edit titik', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              autofocus: widget.editing == null && _input.text.isEmpty,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => _parse(),
              decoration: InputDecoration(
                labelText: 'Koordinat atau link Google Maps',
                hintText: '-6.9761, 108.4830',
                border: const OutlineInputBorder(),
                errorText: p == null && _input.text.isNotEmpty ? parseFailureMessage(_input.text) : null,
                suffixIcon: IconButton(
                  tooltip: 'Tempel',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                    if (text == null) return;
                    _input.text = text.trim();
                    _parse();
                  },
                ),
              ),
            ),
            if (p != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                'lat ${p.lat.toStringAsFixed(6)}, lng ${p.lng.toStringAsFixed(6)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w, style: TextStyle(color: theme.colorScheme.tertiary))),
                  ]),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  child: FlutterMap(
                    key: ValueKey('${p.lat},${p.lng}'),
                    options: MapOptions(
                      initialCenter: LatLng(p.lat, p.lng),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      osmTileLayer(widget.userAgentPackageName),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on, size: 36, color: theme.colorScheme.error),
                        ),
                      ]),
                      osmAttribution(),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: [for (final g in mockGroups) ButtonSegment(value: g, label: Text(g))],
                  selected: {_group},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _group = s.first),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _accuracy,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Akurasi',
                    suffixText: 'm',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: p == null ? null : () => _save(activate: false),
                  child: const Text('Simpan'),
                ),
              ),
              if (widget.onActivate != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: p == null ? null : () => _save(activate: true),
                    child: const Text('Simpan & aktifkan'),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
