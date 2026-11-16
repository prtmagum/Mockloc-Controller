#!/usr/bin/env bash
# Guard CI: APK prod tidak boleh berisi kode mock sama sekali.
#
#   tool/check_prod_apk.sh build/app/outputs/flutter-apk/app-prod-release.apk
#
# Memeriksa kelas Kotlin/Java (dex) dan snapshot Dart AOT (libapp.so).
# Kalau apkanalyzer tersedia, daftar package dex juga dicek dengan apkanalyzer.
set -euo pipefail

apk="${1:?pakai: $0 <path ke APK prod>}"
[[ -f "$apk" ]] || { echo "APK tidak ditemukan: $apk" >&2; exit 2; }

# Titik pada pola regex juga cocok dengan '/' di nama kelas dex (Lid/replay/mockloc/...).
forbidden='mock_location_kit|id.replay.mockloc|ControllerLocationSource|SwitchableLocationSource'

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
unzip -q -o "$apk" 'classes*.dex' 'lib/*/libapp.so' -d "$work" 2>/dev/null || true

fail=0
check() {
  local label="$1" file="$2"
  if hits="$(grep -a -o -E "$forbidden" "$file" | sort -u)" && [[ -n "$hits" ]]; then
    echo "GAGAL: $label berisi referensi mock:" >&2
    sed 's/^/  - /' <<<"$hits" >&2
    fail=1
  fi
}

shopt -s nullglob
dex=("$work"/classes*.dex)
so=("$work"/lib/*/libapp.so)
(( ${#dex[@]} )) || { echo "Tidak ada classes.dex di $apk" >&2; exit 2; }

for f in "${dex[@]}"; do check "$(basename "$f")" "$f"; done
for f in "${so[@]}"; do check "${f#"$work"/}" "$f"; done

if command -v apkanalyzer >/dev/null; then
  if apkanalyzer dex packages "$apk" | grep -E "$forbidden" >&2; then
    echo "GAGAL: apkanalyzer menemukan package mock" >&2
    fail=1
  fi
fi

if (( fail )); then
  exit 1
fi
echo "OK: $apk bersih dari kode mock (${#dex[@]} dex, ${#so[@]} libapp.so diperiksa)"
