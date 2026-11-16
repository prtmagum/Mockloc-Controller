import 'package:flutter/material.dart';
import 'package:mock_location_kit/mock_location_kit.dart';

import '../controller_model.dart';

class PresetsTab extends StatelessWidget {
  const PresetsTab({super.key, required this.model, required this.onAdd});

  final ControllerModel model;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Tambah titik'),
            ),
            const Spacer(),
            PresetMenuButton(store: model.store),
          ]),
        ),
        Expanded(
          child: PresetList(
            store: model.store,
            userAgentPackageName: userAgentPackageName,
            activeId: model.activePresetId,
            onActivate: model.activatePreset,
          ),
        ),
      ]);
}
