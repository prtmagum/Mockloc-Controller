import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'location/location_providers.dart';
import 'location/real_location_source.dart';

// JANGAN impor mock_location_kit di sini.
void main() => runApp(ProviderScope(
      overrides: [
        locationSourceProvider.overrideWithValue(RealLocationSource()),
      ],
      child: const MyApp(flavor: 'prod'),
    ));
