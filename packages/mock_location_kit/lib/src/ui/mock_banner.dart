import 'package:flutter/material.dart';

import '../points/point_store.dart';
import '../sources/switchable_location_source.dart';
import 'debug_panel.dart';

/// Membungkus aplikasi di flavor dev:
/// * strip merah "MOCK GPS" yang selalu terlihat saat mode mock aktif (FR-04),
/// * tab kecil di tepi kanan untuk membuka panel debug (FR-05).
///
/// Dipasang di atas `MaterialApp`, jadi panel punya `MaterialApp` sendiri.
class MockBanner extends StatefulWidget {
  const MockBanner({
    super.key,
    required this.source,
    required this.userAgentPackageName,
    required this.child,
    this.store,
    this.showHandle = true,
  });

  final SwitchableLocationSource source;

  /// Package name aplikasi target, dipakai sebagai User-Agent tile OSM.
  final String userAgentPackageName;
  final Widget child;
  final PointStore? store;
  final bool showHandle;

  @override
  State<MockBanner> createState() => _MockBannerState();
}

class _MockBannerState extends State<MockBanner> with WidgetsBindingObserver {
  late final PointStore _store = widget.store ?? (PointStore()..load());
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!_open) return false;
    setState(() => _open = false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: widget.source.mode,
        child: widget.child,
        builder: (context, mode, child) {
          final mock = mode != MockMode.real;
          return Stack(children: [
            Column(children: [
              GestureDetector(
                onTap: () => setState(() => _open = true),
                child: Container(
                  height: mock ? mq.padding.top + 22 : 0,
                  width: double.infinity,
                  color: const Color(0xFFD32F2F),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 3),
                  child: mock
                      ? Text(
                          'MOCK GPS · ${mode.label.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: MediaQuery(
                  data: mock ? mq.removePadding(removeTop: true) : mq,
                  child: child!,
                ),
              ),
            ]),
            if (widget.showHandle && !_open)
              Positioned(
                right: 0,
                top: mq.size.height * 0.4,
                child: GestureDetector(
                  onTap: () => setState(() => _open = true),
                  child: Container(
                    width: 22,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (mock ? const Color(0xFFD32F2F) : const Color(0xFF000000)).withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                    ),
                    child: const Icon(Icons.location_searching, size: 16, color: Colors.white),
                  ),
                ),
              ),
            if (_open)
              Positioned.fill(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(colorSchemeSeed: const Color(0xFFD32F2F)),
                  home: DebugPanel(
                    source: widget.source,
                    store: _store,
                    userAgentPackageName: widget.userAgentPackageName,
                    onClose: () => setState(() => _open = false),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
