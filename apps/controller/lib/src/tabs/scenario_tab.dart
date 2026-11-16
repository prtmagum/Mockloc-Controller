import 'package:flutter/material.dart';

import '../controller_model.dart';

/// Skenario uji (FR-08), sesuai tabel skenario di PRD.
class ScenarioTab extends StatelessWidget {
  const ScenarioTab({super.key, required this.model});

  final ControllerModel model;

  @override
  Widget build(BuildContext context) {
    final hasPoint = model.lastSent != null;
    final error = model.snapshot.fix?.error;

    Widget tile(IconData icon, String title, String subtitle, VoidCallback? onTap, {bool selected = false}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          selected: selected,
          enabled: onTap != null,
          onTap: onTap,
        );

    return ListView(children: [
      if (!hasPoint)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Kirim satu titik dulu (preset atau tap peta) untuk skenario yang butuh posisi awal.'),
        ),
      tile(Icons.restart_alt, 'Kembali normal', 'Kirim ulang titik terakhir', hasPoint ? model.restore : null),
      tile(Icons.north, 'Geser 300 m', 'Uji pesan "di luar area"', hasPoint ? () => model.shift(300) : null),
      tile(Icons.signal_cellular_connected_no_internet_0_bar, 'Sinyal GPS buruk', 'Akurasi 150 m + jitter 60 m',
          hasPoint ? model.poorSignal : null),
      tile(
        Icons.flight_takeoff,
        model.teleported ? 'Teleport balik' : 'Teleport 20 km',
        'Lompatan lokasi dalam 1 detik (deteksi anomali)',
        hasPoint ? model.teleport : null,
        selected: model.teleported,
      ),
      const Divider(),
      tile(Icons.location_disabled, 'GPS mati', 'Aplikasi menerima GpsDisabledException',
          () => model.sendError('service_disabled'),
          selected: error == 'service_disabled'),
      tile(Icons.block, 'Izin ditolak', 'Aplikasi menerima GpsPermissionDeniedException',
          () => model.sendError('permission_denied'),
          selected: error == 'permission_denied'),
      tile(Icons.timer_off, 'Timeout', 'Aplikasi menerima GpsTimeoutException', () => model.sendError('timeout'),
          selected: error == 'timeout'),
    ]);
  }
}
