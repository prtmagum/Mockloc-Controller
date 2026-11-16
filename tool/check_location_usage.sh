#!/usr/bin/env bash
# Guard CI: semua kode aplikasi harus membaca lokasi lewat locationSourceProvider.
#
#   tool/check_location_usage.sh apps/example_target
#
# Aturan:
#   1. `Geolocator.` hanya boleh di lib/location/real_location_source.dart.
#   2. `mock_location_kit` hanya boleh diimpor dari lib/main_dev.dart.
#   3. Tidak boleh ada flutter_map_location_marker atau myLocationEnabled: true
#      (keduanya membaca GPS asli).
set -euo pipefail

app="${1:?pakai: $0 <folder aplikasi Flutter>}"
cd "$app"
fail=0

report() {
  echo "GAGAL: $1" >&2
  sed 's/^/  /' >&2
  fail=1
}

if hits="$(grep -rn --include='*.dart' 'Geolocator\.' lib | grep -v '^lib/location/real_location_source.dart:')"; then
  report 'Geolocator dipanggil di luar RealLocationSource' <<<"$hits"
fi

if hits="$(grep -rn --include='*.dart' "package:mock_location_kit" lib | grep -v '^lib/main_dev.dart:')"; then
  report 'mock_location_kit diimpor di luar main_dev.dart' <<<"$hits"
fi

if hits="$(grep -n 'flutter_map_location_marker' pubspec.yaml)"; then
  report 'flutter_map_location_marker membaca GPS asli' <<<"$hits"
fi

if hits="$(grep -rn --include='*.dart' -E 'myLocationEnabled:\s*true' lib)"; then
  report 'myLocationEnabled: true membaca GPS asli' <<<"$hits"
fi

if (( fail )); then
  exit 1
fi
echo "OK: $app hanya membaca lokasi lewat LocationSource"
