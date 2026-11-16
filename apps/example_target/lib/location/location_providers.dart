import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location_core/location_core.dart';

/// Satu-satunya sumber lokasi aplikasi. Di-override di main_prod.dart /
/// main_dev.dart. Jangan memanggil Geolocator langsung di luar
/// RealLocationSource (dicek oleh tool/check_geolocator_usage.sh).
final locationSourceProvider = Provider<LocationSource>(
  (ref) => throw UnimplementedError('Override locationSourceProvider di main_*.dart'),
);

final locationStreamProvider = StreamProvider<LocationFix>(
  (ref) => ref.watch(locationSourceProvider).watch(),
);
