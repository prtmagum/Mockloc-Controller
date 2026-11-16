import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Satu-satunya file yang boleh mengimpor mock_location_kit.
import 'package:mock_location_kit/mock_location_kit.dart';

import 'app.dart';
import 'location/location_providers.dart';
import 'location/real_location_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mode (Asli/Controller/Panel) terakhir dipulihkan sebelum app jalan, jadi
  // GPS asli tidak sempat dibaca kalau sebelumnya mode mock.
  final source = await SwitchableLocationSource.restore(
    real: RealLocationSource(),
    mock: ControllerLocationSource(),
  );
  runApp(ProviderScope(
    overrides: [
      locationSourceProvider.overrideWithValue(source),
    ],
    child: MockBanner(
      source: source,
      userAgentPackageName: appPackageName,
      child: const MyApp(flavor: 'dev'),
    ),
  ));
}
