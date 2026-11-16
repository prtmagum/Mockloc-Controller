import 'package:flutter/material.dart';

import '../controller_model.dart';

/// Mode Sistem: lokasi mock juga dipakai Google Maps dan aplikasi lain, lewat
/// API mock location resmi Android. Butuh Opsi Pengembang atau root.
class SystemTab extends StatefulWidget {
  const SystemTab({super.key, required this.model});

  final ControllerModel model;

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> with WidgetsBindingObserver {
  bool _rooting = false;

  ControllerModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.refreshSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kembali dari Opsi Pengembang / dialog izin → cek ulang status.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model.refreshSystem();
  }

  Future<void> _grantViaRoot() async {
    setState(() => _rooting = true);
    final error = await model.grantViaRoot();
    if (!mounted) return;
    setState(() => _rooting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Izin mock location diberikan lewat root'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = model.system;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget check(bool ok, String title, String subtitle, {bool optional = false}) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            ok ? Icons.check_circle : (optional ? Icons.info_outline : Icons.cancel),
            color: ok ? Colors.green : (optional ? scheme.outline : scheme.error),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card.filled(
        child: SwitchListTile(
          title: const Text('Terapkan ke sistem'),
          subtitle: Text(
            !s.ready
                ? 'Selesaikan syarat di bawah dulu'
                : s.enabled
                    ? 'Google Maps & aplikasi lain melihat lokasi mock'
                    : 'Mati: hanya aplikasi dengan MockLoc kit yang terpengaruh',
          ),
          value: s.enabled,
          onChanged: s.ready || s.enabled ? model.setSystemMock : null,
        ),
      ),
      if (s.lastError != null && s.enabled)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(s.lastError!, style: TextStyle(color: scheme.error)),
        ),
      const SizedBox(height: 16),
      Text('Syarat', style: textTheme.titleMedium),
      check(
        s.mockApp,
        'MockLoc dipilih sebagai aplikasi lokasi palsu',
        'Opsi Pengembang → Pilih aplikasi lokasi palsu → MockLoc Controller. '
            'Atau tombol root di bawah.',
      ),
      check(
        s.devOptions,
        'Opsi Pengembang aktif',
        'Tidak wajib kalau izin diberikan lewat root',
        optional: true,
      ),
      check(
        s.locationPermission,
        'Izin lokasi',
        'Hanya untuk API mock Google Play Services (dipakai Google Maps). '
            'Controller tidak membaca lokasimu. Diminta saat sakelar dinyalakan.',
        optional: true,
      ),
      check(
        s.playServices,
        'Google Play Services',
        'Kalau tidak ada, provider GPS/network Android tetap di-mock',
        optional: true,
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(
          onPressed: model.bridge.openDevSettings,
          icon: const Icon(Icons.developer_mode),
          label: const Text('Buka Opsi Pengembang'),
        ),
        OutlinedButton.icon(
          onPressed: _rooting ? null : _grantViaRoot,
          icon: _rooting
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.admin_panel_settings),
          label: const Text('Izinkan via root'),
        ),
      ]),
      const Divider(height: 32),
      Text('Cara mengaktifkan Opsi Pengembang', style: textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text(
        '1. Setelan → Tentang ponsel → tap "Nomor build" 7 kali.\n'
        '   (Xiaomi: "Versi MIUI/HyperOS"; Samsung: Informasi perangkat lunak → Nomor build.)\n'
        '2. Kembali ke Setelan → Opsi Pengembang → "Pilih aplikasi lokasi palsu".\n'
        '3. Pilih MockLoc Controller, lalu kembali ke sini dan nyalakan sakelar.\n\n'
        'HP root: cukup tap "Izinkan via root" lalu izinkan di Magisk/KernelSU. '
        'Opsi Pengembang tidak perlu dinyalakan.',
      ),
      const SizedBox(height: 12),
      Text(
        'Android tetap menandai lokasi ini sebagai mock, dan aplikasi lain bisa mendeteksinya. '
        'Matikan sakelar atau tekan "Hentikan mock" untuk kembali ke lokasi asli.',
        style: textTheme.bodySmall,
      ),
    ]);
  }
}
