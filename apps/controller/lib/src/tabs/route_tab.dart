import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller_model.dart';

class RouteTab extends StatelessWidget {
  const RouteTab({super.key, required this.model});

  final ControllerModel model;

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    final n = model.importRoute(utf8.decode(bytes, allowMalformed: true));
    if (context.mounted) _snack(context, n == 0 ? 'Tidak ada titik GPX/KML yang terbaca' : '$n titik rute diimpor');
  }

  Future<void> _importClipboard(BuildContext context) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final n = model.importRoute(text);
    if (context.mounted) _snack(context, n == 0 ? 'Clipboard tidak berisi rute' : '$n titik rute diimpor');
  }

  @override
  Widget build(BuildContext context) {
    final status = model.snapshot.route;
    final routeRunning = status.active && !status.isStatic;
    final textTheme = Theme.of(context).textTheme;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilterChip(
          selected: model.drawingRoute,
          onSelected: (_) => model.toggleDrawing(),
          avatar: const Icon(Icons.draw, size: 18),
          label: const Text('Gambar di peta'),
        ),
        IconButton(
          tooltip: 'Hapus titik terakhir',
          onPressed: model.route.isEmpty ? null : model.undoRoutePoint,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Kosongkan rute',
          onPressed: model.route.isEmpty ? null : model.clearRoute,
          icon: const Icon(Icons.delete_outline),
        ),
        OutlinedButton.icon(
          onPressed: () => _importFile(context),
          icon: const Icon(Icons.file_open),
          label: const Text('GPX/KML'),
        ),
        TextButton.icon(
          onPressed: () => _importClipboard(context),
          icon: const Icon(Icons.content_paste),
          label: const Text('Tempel'),
        ),
      ]),
      const SizedBox(height: 8),
      Text('${model.route.length} titik · ${(model.routeMeters / 1000).toStringAsFixed(2)} km',
          style: textTheme.bodyLarge),
      const SizedBox(height: 16),
      Text('Kecepatan: ${model.routeSpeedKmh.toStringAsFixed(0)} km/jam', style: textTheme.labelLarge),
      Slider(
        value: model.routeSpeedKmh,
        min: 5,
        max: 150,
        divisions: 29,
        label: '${model.routeSpeedKmh.toStringAsFixed(0)} km/jam',
        onChanged: model.setRouteSpeed,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Loop'),
        subtitle: const Text('Ulangi dari awal setelah sampai di titik akhir'),
        value: model.routeLoop,
        onChanged: model.setRouteLoop,
      ),
      if (routeRunning || status.state == 'finished') ...[
        LinearProgressIndicator(value: status.progress),
        const SizedBox(height: 4),
        Text(
          '${(status.traveled / 1000).toStringAsFixed(2)} / ${(status.total / 1000).toStringAsFixed(2)} km'
          '${status.state == 'finished' ? ' · selesai' : ''}',
        ),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: model.route.length < 2 ? null : model.startRoute,
            icon: const Icon(Icons.play_arrow),
            label: Text(routeRunning ? 'Mulai ulang' : 'Putar rute'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: status.state == 'paused' ? 'Lanjut' : 'Jeda',
          onPressed: !routeRunning
              ? null
              : status.state == 'paused'
                  ? model.bridge.resumeRoute
                  : model.bridge.pauseRoute,
          icon: Icon(status.state == 'paused' ? Icons.play_arrow : Icons.pause),
        ),
        IconButton.filledTonal(
          tooltip: 'Stop',
          onPressed: routeRunning ? model.bridge.stopRoute : null,
          icon: const Icon(Icons.stop),
        ),
      ]),
      const SizedBox(height: 12),
      Text(
        'Rute diputar oleh foreground service, jadi tetap jalan saat Controller di latar belakang. '
        'Akurasi, jitter, dan ketinggian diambil dari tab Parameter.',
        style: textTheme.bodySmall,
      ),
    ]);
  }
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
