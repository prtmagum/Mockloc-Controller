import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

import 'controller_model.dart';

/// Peta Controller. Tap = pilih titik (atau tambah titik rute saat mode
/// gambar). Peta ini tidak pernah membaca GPS asli.
class MockMap extends StatelessWidget {
  const MockMap({
    super.key,
    required this.model,
    required this.controller,
    required this.onSavePending,
  });

  final ControllerModel model;
  final MapController controller;
  final void Function(String coordText) onSavePending;

  static const _indonesia = LatLng(-2.5, 118);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fix = model.snapshot.fix;
    final current = fix?.point;
    final pending = model.pending;

    return Stack(children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: current ?? _indonesia,
          initialZoom: current == null ? 5 : 16,
          onTap: (_, p) => model.onMapTap(p),
        ),
        children: [
          osmTileLayer(userAgentPackageName),
          if (model.route.length > 1)
            PolylineLayer(polylines: [
              Polyline(points: model.route, strokeWidth: 4, color: scheme.primary),
            ]),
          if (current != null && fix?.accuracy != null)
            CircleLayer(circles: [
              CircleMarker(
                point: current,
                radius: fix!.accuracy!,
                useRadiusInMeter: true,
                color: scheme.error.withValues(alpha: 0.15),
                borderColor: scheme.error,
                borderStrokeWidth: 1,
              ),
            ]),
          MarkerLayer(markers: [
            for (final p in model.store.points)
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 22,
                height: 22,
                alignment: Alignment.topCenter,
                child: Tooltip(
                  message: p.name,
                  child: Icon(Icons.place, size: 22, color: scheme.outline),
                ),
              ),
            if (model.drawingRoute)
              for (final p in model.route)
                Marker(
                  point: p,
                  width: 10,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  ),
                ),
            if (pending != null)
              Marker(
                point: pending,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_on, size: 40, color: scheme.primary),
              ),
            if (current != null)
              Marker(
                point: current,
                width: 30,
                height: 30,
                child: _FixDot(bearing: fix?.bearing, color: scheme.error),
              ),
          ]),
          osmAttribution(),
        ],
      ),
      Positioned(
        top: 8,
        right: 8,
        child: FloatingActionButton.small(
          heroTag: 'center',
          tooltip: 'Ke titik mock',
          onPressed: current == null
              ? null
              : () => controller.move(current, math.max(controller.camera.zoom, 15)),
          child: const Icon(Icons.center_focus_strong),
        ),
      ),
      if (model.drawingRoute)
        const Positioned(
          top: 8,
          left: 8,
          child: Chip(
            avatar: Icon(Icons.timeline, size: 18),
            label: Text('Tap peta untuk menambah titik rute'),
          ),
        ),
      if (pending != null)
        Positioned(
          left: 8,
          right: 8,
          bottom: 24,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${pending.latitude.toStringAsFixed(6)}, ${pending.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final text = '${pending.latitude}, ${pending.longitude}';
                    model.clearPending();
                    onSavePending(text);
                  },
                  child: const Text('Simpan'),
                ),
                FilledButton(onPressed: model.sendPending, child: const Text('Kirim')),
                IconButton(icon: const Icon(Icons.close), onPressed: model.clearPending),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _FixDot extends StatelessWidget {
  const _FixDot({required this.bearing, required this.color});

  final double? bearing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = bearing;
    if (b == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
      );
    }
    return Transform.rotate(
      angle: b * math.pi / 180,
      child: Icon(Icons.navigation, size: 30, color: color),
    );
  }
}
