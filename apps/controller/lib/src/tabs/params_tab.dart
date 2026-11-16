import 'package:flutter/material.dart';

import '../controller_model.dart';

/// Parameter fix (FR-07). Berlaku untuk kiriman berikutnya; tombol di bawah
/// menerapkannya ke titik yang sedang aktif.
class ParamsTab extends StatelessWidget {
  const ParamsTab({super.key, required this.model});

  final ControllerModel model;

  @override
  Widget build(BuildContext context) {
    final p = model.params;
    void set(FixParams value) => model.setParams(value);

    return ListView(padding: const EdgeInsets.all(16), children: [
      _SliderRow(
        label: 'Akurasi',
        unit: 'm',
        value: p.accuracy,
        min: 1,
        max: 200,
        onChanged: (v) => set(p.copyWith(accuracy: v)),
      ),
      _SliderRow(
        label: 'Jitter acak',
        unit: 'm',
        value: p.jitter,
        min: 0,
        max: 200,
        onChanged: (v) => set(p.copyWith(jitter: v)),
      ),
      _SliderRow(
        label: 'Kecepatan (titik diam)',
        unit: 'km/jam',
        value: p.speedKmh,
        min: 0,
        max: 150,
        onChanged: (v) => set(p.copyWith(speedKmh: v)),
      ),
      _OptionalSlider(
        label: 'Arah (bearing)',
        unit: '°',
        value: p.bearing,
        min: 0,
        max: 359,
        fallback: 0,
        onChanged: (v) => set(p.copyWith(bearing: () => v)),
      ),
      _OptionalSlider(
        label: 'Ketinggian',
        unit: 'm',
        value: p.altitude,
        min: -100,
        max: 3000,
        fallback: 25,
        onChanged: (v) => set(p.copyWith(altitude: () => v)),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: model.lastSent == null ? null : model.resendWithParams,
        icon: const Icon(Icons.refresh),
        label: const Text('Terapkan ke titik aktif'),
      ),
      const SizedBox(height: 8),
      Text(
        'Preset memakai akurasinya sendiri; parameter lain berlaku untuk semua kiriman. '
        'Jitter > 0 membuat titik bergoyang tiap detik lewat foreground service.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label, unit;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(0)} $unit', style: Theme.of(context).textTheme.labelLarge),
          Slider(value: value.clamp(min, max), min: min, max: max, onChanged: (v) => onChanged(v.roundToDouble())),
        ],
      );
}

class _OptionalSlider extends StatelessWidget {
  const _OptionalSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.fallback,
    required this.onChanged,
  });

  final String label, unit;
  final double? value;
  final double min, max, fallback;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(v == null ? '$label: tidak dikirim' : '$label: ${v.toStringAsFixed(0)} $unit'),
        value: v != null,
        onChanged: (on) => onChanged(on ? fallback : null),
      ),
      if (v != null)
        Slider(value: v.clamp(min, max), min: min, max: max, onChanged: (x) => onChanged(x.roundToDouble())),
    ]);
  }
}
