import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../points/mock_point.dart';
import '../points/point_store.dart';
import 'add_point_sheet.dart';

/// Daftar preset per grup. Tap = aktifkan; menu = edit, salin, hapus.
class PresetList extends StatelessWidget {
  const PresetList({
    super.key,
    required this.store,
    required this.userAgentPackageName,
    required this.onActivate,
    this.activeId,
    this.padding,
  });

  final PointStore store;
  final String userAgentPackageName;
  final void Function(MockPoint point) onActivate;
  final String? activeId;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final points = store.points;
          if (points.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada preset.\nTap "+ Tambah titik" lalu tempel koordinat.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final groups = {
            for (final g in mockGroups) g: <MockPoint>[],
            for (final p in points) p.group: <MockPoint>[],
          };
          for (final p in points) {
            groups[p.group]!.add(p);
          }
          return ListView(
            padding: padding,
            children: [
              for (final MapEntry(key: group, value: items) in groups.entries)
                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(group, style: Theme.of(context).textTheme.labelLarge),
                  ),
                  for (final p in items) _tile(context, p),
                ],
            ],
          );
        },
      );

  Widget _tile(BuildContext context, MockPoint p) {
    final active = p.id == activeId;
    return ListTile(
      selected: active,
      leading: Icon(active ? Icons.my_location : Icons.place_outlined),
      title: Text(p.name),
      subtitle: Text('${p.coordText} · ±${p.accuracy.toStringAsFixed(0)} m'),
      onTap: () => onActivate(p),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'edit':
              await showAddPointSheet(context,
                  store: store, userAgentPackageName: userAgentPackageName, editing: p);
            case 'copy':
              await Clipboard.setData(ClipboardData(text: p.coordText));
              if (context.mounted) _snack(context, 'Koordinat disalin');
            case 'delete':
              await store.remove(p.id);
              if (context.mounted) _snack(context, '${p.name} dihapus');
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'copy', child: Text('Salin koordinat')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    );
  }
}

/// Menu impor/ekspor preset lewat clipboard (JSON atau CSV).
class PresetMenuButton extends StatelessWidget {
  const PresetMenuButton({super.key, required this.store});

  final PointStore store;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Impor/ekspor',
        icon: const Icon(Icons.import_export),
        onSelected: (action) async {
          switch (action) {
            case 'import':
              await showImportDialog(context, store);
            case 'json':
              await Clipboard.setData(ClipboardData(text: store.exportJson()));
              if (context.mounted) _snack(context, 'JSON preset disalin ke clipboard');
            case 'csv':
              await Clipboard.setData(ClipboardData(text: store.exportCsv()));
              if (context.mounted) _snack(context, 'CSV preset disalin ke clipboard');
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'import', child: Text('Impor CSV / JSON…')),
          PopupMenuItem(value: 'json', child: Text('Ekspor JSON (salin)')),
          PopupMenuItem(value: 'csv', child: Text('Ekspor CSV (salin)')),
        ],
      );
}

/// Dialog tempel CSV `nama,lat,lng` atau JSON hasil ekspor (FR-13).
Future<void> showImportDialog(BuildContext context, PointStore store) async {
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return;
  final controller = TextEditingController(text: clip.contains(',') ? clip : '');
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Impor titik'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: controller,
          maxLines: 10,
          minLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'nama,lat,lng\nRumah,-6.9761,108.4830\nKantor,-6.9175,107.6191',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Impor')),
      ],
    ),
  );
  controller.dispose();
  if (text == null || text.trim().isEmpty) return;
  try {
    final report = await store.importText(text);
    if (context.mounted) _snack(context, report.summary);
  } catch (e) {
    if (context.mounted) _snack(context, 'Gagal impor: $e');
  }
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
