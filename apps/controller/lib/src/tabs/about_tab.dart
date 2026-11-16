import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller_model.dart';

const _developer = 'Agumon Handsome';
const _whatsapp = '089684460487';
const _instagram = 'prtmagum';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key, required this.model});

  final ControllerModel model;

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  String? _version;

  @override
  void initState() {
    super.initState();
    widget.model.bridge.appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  /// 0896… → 62896… untuk link wa.me.
  static String get _waLink => 'https://wa.me/62${_whatsapp.substring(1)}';

  Future<void> _open(String url, String fallbackCopy) async {
    if (await widget.model.bridge.openUrl(url)) return;
    await Clipboard.setData(ClipboardData(text: fallbackCopy));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tidak bisa membuka link, "$fallbackCopy" disalin')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(padding: const EdgeInsets.all(24), children: [
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(Icons.location_on, size: 64, color: Colors.white),
        ),
      ),
      const SizedBox(height: 16),
      Text('MockLoc Controller', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
      Text(
        _version == null ? '' : 'Versi $_version',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
      ),
      const SizedBox(height: 8),
      const Text(
        'Alat testing lokasi untuk aplikasi Android sendiri, tanpa root dan tanpa Opsi Pengembang.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Card.outlined(
        child: Column(children: [
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Pengembang'),
            subtitle: Text(_developer),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp'),
            subtitle: const Text(_whatsapp),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(_waLink, _whatsapp),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Instagram'),
            subtitle: const Text('@$_instagram'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open('https://instagram.com/$_instagram', '@$_instagram'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(
        'Peta © OpenStreetMap contributors',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
      ),
    ]);
  }
}
