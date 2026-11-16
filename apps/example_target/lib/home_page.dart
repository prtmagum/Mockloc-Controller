import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_core/location_core.dart';

import 'app.dart';
import 'location/location_providers.dart';
import 'location/real_location_source.dart';

/// Layar demo fitur berbasis lokasi: geofence, tracking jarak, deteksi
/// lompatan, dan payload `isMock` ke backend. Semua lokasi dibaca dari
/// `locationStreamProvider`, tidak pernah dari Geolocator langsung.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.flavor});

  final String flavor;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _geofenceRadius = 100.0;
  static const _anomalyMeters = 1000.0;
  static const _anomalyWindow = Duration(seconds: 5);

  final _map = MapController();
  final _path = <LatLng>[];
  double _traveled = 0;
  LocationFix? _last;
  LatLng? _target;
  String? _anomaly;
  bool _follow = true;

  void _onFix(LocationFix fix) {
    final prev = _last;
    final p = LatLng(fix.lat, fix.lng);
    setState(() {
      if (prev != null) {
        final d = distanceMeters(prev.lat, prev.lng, fix.lat, fix.lng);
        final dt = fix.time.difference(prev.time).abs();
        if (d > _anomalyMeters && dt < _anomalyWindow) {
          _anomaly = 'Lompatan ${(d / 1000).toStringAsFixed(1)} km dalam ${dt.inMilliseconds / 1000} s';
        } else {
          _traveled += d;
        }
      }
      _last = fix;
      _path.add(p);
      if (_path.length > 1000) _path.removeAt(0);
    });
    if (_follow) {
      try {
        _map.move(p, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
      } catch (_) {
        // Peta belum ter-render (frame pertama).
      }
    }
  }

  void _resetTrack() => setState(() {
        _path.clear();
        _traveled = 0;
        _anomaly = null;
      });

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LocationFix>>(locationStreamProvider, (_, next) {
      if (next case AsyncData(:final value)) _onFix(value);
    });
    final async = ref.watch(locationStreamProvider);
    final fix = async.valueOrNull;
    final error = async.hasError ? async.error : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sample Target (${widget.flavor})'),
        actions: [
          IconButton(
            tooltip: 'Reset tracking',
            onPressed: _resetTrack,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: _buildMap(context, fix)),
        if (error != null)
          _ErrorCard(error: error, onRetry: () => ref.invalidate(locationStreamProvider))
        else if (fix == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Menunggu lokasi…'),
            ]),
          )
        else
          _buildInfo(context, fix),
      ]),
    );
  }

  Widget _buildMap(BuildContext context, LocationFix? fix) {
    final scheme = Theme.of(context).colorScheme;
    final here = fix == null ? null : LatLng(fix.lat, fix.lng);
    final target = _target;
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: here ?? const LatLng(-2.5, 118),
          initialZoom: here == null ? 5 : 16,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture && _follow) setState(() => _follow = false);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: appPackageName,
          ),
          if (target != null)
            CircleLayer(circles: [
              CircleMarker(
                point: target,
                radius: _geofenceRadius,
                useRadiusInMeter: true,
                color: scheme.tertiary.withValues(alpha: 0.15),
                borderColor: scheme.tertiary,
                borderStrokeWidth: 2,
              ),
            ]),
          if (_path.length > 1)
            PolylineLayer(polylines: [Polyline(points: _path, strokeWidth: 3, color: scheme.primary)]),
          if (here != null && fix != null)
            CircleLayer(circles: [
              CircleMarker(
                point: here,
                radius: fix.accuracy,
                useRadiusInMeter: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ]),
          if (here != null)
            MarkerLayer(markers: [
              Marker(
                point: here,
                width: 22,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ]),
          const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
        ],
      ),
      Positioned(
        top: 8,
        right: 8,
        child: FloatingActionButton.small(
          tooltip: 'Ikuti posisi',
          onPressed: here == null
              ? null
              : () {
                  setState(() => _follow = true);
                  _map.move(here, 16);
                },
          child: Icon(_follow ? Icons.gps_fixed : Icons.gps_not_fixed),
        ),
      ),
    ]);
  }

  Widget _buildInfo(BuildContext context, LocationFix fix) {
    final theme = Theme.of(context);
    final target = _target;
    final distance = target == null ? null : distanceMeters(target.latitude, target.longitude, fix.lat, fix.lng);
    final inside = distance != null && distance <= _geofenceRadius;
    const mono = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return Material(
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text('${fix.lat.toStringAsFixed(6)}, ${fix.lng.toStringAsFixed(6)}',
                    style: theme.textTheme.titleMedium?.merge(mono)),
              ),
              if (fix.isMock)
                Chip(
                  label: const Text('isMock'),
                  backgroundColor: theme.colorScheme.errorContainer,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            Text(
              '±${fix.accuracy.toStringAsFixed(0)} m'
              '${fix.speed != null ? ' · ${(fix.speed! * 3.6).toStringAsFixed(0)} km/jam' : ''}'
              '${fix.bearing != null ? ' · ${fix.bearing!.toStringAsFixed(0)}°' : ''}'
              ' · tempuh ${(_traveled / 1000).toStringAsFixed(2)} km',
              style: mono,
            ),
            if (fix.accuracy > 50)
              Text('Sinyal GPS lemah, menunggu fix yang lebih akurat…',
                  style: TextStyle(color: theme.colorScheme.tertiary)),
            if (_anomaly != null)
              Text('Anomali: $_anomaly', style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  switch (distance) {
                    null => 'Belum ada tujuan (geofence 100 m).',
                    _ when inside => 'Di dalam area tujuan (${distance.toStringAsFixed(0)} m)',
                    _ => 'Di luar area tujuan: ${distance.toStringAsFixed(0)} m',
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: distance == null
                        ? null
                        : inside
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _target = LatLng(fix.lat, fix.lng)),
                child: const Text('Jadikan tujuan'),
              ),
            ]),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Payload ke backend'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(fix.toJson()),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, action) = switch (error) {
      GpsDisabledException() => ('GPS mati. Nyalakan layanan lokasi.', RealLocationSource.openLocationSettings),
      GpsPermissionDeniedException() => ('Izin lokasi ditolak.', RealLocationSource.openAppSettings),
      GpsTimeoutException() => ('Lokasi tidak didapat dalam batas waktu.', null),
      LocationException(:final message) => (message, null),
      _ => ('Error lokasi: $error', null),
    };
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            if (action != null) OutlinedButton(onPressed: action, child: const Text('Buka pengaturan')),
          ]),
        ]),
      ),
    );
  }
}
