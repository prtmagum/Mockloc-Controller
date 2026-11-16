import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller_model.dart';

/// Riwayat (FR-10), allowlist (FR-11), dan catatan pemasangan.
class MoreTab extends StatefulWidget {
  const MoreTab({super.key, required this.model});

  final ControllerModel model;

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  final _allow = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.model.bridge.allowlist().then((list) {
      if (mounted) _allow.text = list.join('\n');
    });
  }

  @override
  void dispose() {
    _allow.dispose();
    super.dispose();
  }

  Future<void> _copyHistory() async {
    final csv = await widget.model.bridge.historyCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    final rows = '\n'.allMatches(csv).length - 1;
    _snack('Riwayat CSV disalin ($rows baris)');
  }

  Future<void> _clearHistory() async {
    await widget.model.bridge.clearHistory();
    _snack('Riwayat dihapus');
  }

  Future<void> _saveAllowlist() async {
    final packages = _allow.text
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    await widget.model.bridge.setAllowlist(packages);
    _snack(packages.isEmpty ? 'Allowlist kosong: semua aplikasi bertanda tangan sama boleh membaca' : 'Allowlist disimpan');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Riwayat lokasi', style: textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('Setiap fix dan skenario yang dibagikan dicatat (maks. ±3000 baris terakhir).'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        FilledButton.tonalIcon(onPressed: _copyHistory, icon: const Icon(Icons.copy), label: const Text('Salin CSV')),
        TextButton.icon(onPressed: _clearHistory, icon: const Icon(Icons.delete_outline), label: const Text('Hapus')),
      ]),
      const Divider(height: 32),
      Text('Allowlist aplikasi target', style: textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('Satu package name per baris. Kosongkan untuk mengizinkan semua aplikasi '
          'yang ditandatangani keystore internal yang sama.'),
      const SizedBox(height: 8),
      TextField(
        controller: _allow,
        minLines: 2,
        maxLines: 5,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: const InputDecoration(hintText: 'id.replay.sample_target.dev', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: _saveAllowlist, child: const Text('Simpan allowlist')),
      ),
      const Divider(height: 32),
      Text('Cara pakai', style: textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text(
        '1. Pasang Controller ini lebih dulu, baru build dev aplikasi target.\n'
        '2. Keduanya harus ditandatangani keystore internal yang sama.\n'
        '3. Di aplikasi target (dev), buka panel debug lalu pilih mode "Controller".\n'
        '4. Untuk rute panjang di HP Xiaomi/Oppo/Vivo, matikan optimasi baterai Controller.\n\n'
        'Aplikasi lain (Google Maps, WhatsApp, dll.) tetap melihat lokasi asli.',
      ),
    ]);
  }
}
