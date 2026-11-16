# MockLoc

Alat testing lokasi untuk aplikasi Flutter Android sendiri: **tanpa Opsi Pengembang dan tanpa root**.
Lokasi palsu tidak disuntikkan ke sistem; aplikasi target membaca lokasi lewat `LocationSource`,
dan di build dev sumber itu bisa diarahkan ke aplikasi Controller. Aplikasi lain (Google Maps,
WhatsApp, dll.) tetap melihat lokasi asli.

Minimal **Android 9 (API 28)**.

```text
packages/location_core/      LocationFix, LocationSource, error netral, util jarak (ikut ke prod)
packages/mock_location_kit/  ControllerLocationSource, SwitchableLocationSource, PanelLocationSource,
                             MockBanner, DebugPanel, parser koordinat, preset (hanya main_dev.dart)
apps/controller/             Aplikasi Controller: peta OSM, preset, rute GPX/KML, parameter, skenario
                             android/.../MockLocationProvider.kt  ContentProvider (izin signature)
                             android/.../RouteService.kt          foreground service putar rute
apps/example_target/         Contoh aplikasi target dengan flavor dev/prod
tool/                        Guard CI
```

## Build dan pasang

Urutan penting: **pasang Controller lebih dulu**, baru aplikasi target (dev). Kalau terbalik,
izin `signature` bisa tidak diberikan sampai aplikasi target dipasang ulang.

```bash
# 1. Controller
cd apps/controller
flutter pub get
flutter build apk && adb install -r build/app/outputs/flutter-apk/app-release.apk
# atau: flutter run

# 2. Aplikasi target, flavor dev (untuk QA)
cd ../example_target
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart

# 3. Rilis (tanpa kode mock)
flutter build apk --flavor prod -t lib/main_prod.dart
../../tool/check_prod_apk.sh build/app/outputs/flutter-apk/app-prod-release.apk
```

Kedua app harus ditandatangani keystore yang sama. Lihat [signing/README.md](signing/README.md).

## Cara pakai

- **Panel debug in-app** (tanpa Controller): di app target dev, tap tab kecil di tepi kanan layar
  → mode **Panel** → `Tambah titik` → tempel koordinat → `Simpan & aktifkan`.
- **Controller**: di app target dev buka panel → mode **Controller**. Lalu di Controller pilih preset,
  tap peta, putar rute, atau picu skenario. Fix sampai ke app target lewat ContentObserver (< 1 detik).
- Saat mode mock aktif, strip merah **MOCK GPS** selalu tampil di atas app, dan GPS asli tidak
  dibaca sama sekali (langganan `RealLocationSource` dibatalkan).

Format koordinat yang dikenali: `-6.9761, 108.4830`, `-6.9761 108.4830`, link Google Maps
(`@lat,lng` atau pin `!3d…!4d…`), `geo:lat,lng`, dan DMS `6°58'33.96"S 108°28'58.8"E`.
Lat/lng yang tertukar ditukar otomatis. Link pendek `maps.app.goo.gl` belum didukung.

## Mode Sistem (opsional, Opsi Pengembang atau root)

Tab **Sistem** di Controller mengirim fix yang sama ke provider lokasi Android (GPS, network,
fused) dan ke API mock Google Play Services, sehingga Google Maps dan aplikasi lain ikut melihatnya.
Syaratnya, MockLoc dipilih di Opsi Pengembang → "Pilih aplikasi lokasi palsu", **atau** di HP
root tap "Izinkan via root" (`appops set … android:mock_location allow`, tanpa Opsi Pengembang).
Android tetap menandai lokasi ini sebagai mock. Mode Controller/Panel tidak terpengaruh dan tetap
tanpa Opsi Pengembang.

## Memasang di aplikasimu sendiri

1. Tambahkan `location_core` dan `mock_location_kit` (path dependency) ke pubspec.
2. Salin `lib/location/` dari `example_target`, lalu ganti semua pemakaian `Geolocator` dengan
   `ref.watch(locationStreamProvider)` / `ref.read(locationSourceProvider).current()`.
3. Buat flavor `dev`/`prod` seperti di `example_target/android/app/build.gradle.kts`.
4. Pindahkan `MainActivity.kt` dari `src/main` ke `src/prod` (polos) dan `src/dev`
   (salin dari contoh, sesuaikan nama package). Salin `src/dev/AndroidManifest.xml`.
5. Pastikan package aplikasimu **tidak** mengandung `id.replay.mockloc`, karena guard CI mencari string itu.
6. Jalankan `tool/check_location_usage.sh <folder app>` dan `tool/check_prod_apk.sh <apk prod>` di CI.

## Error yang diterima aplikasi

Sumber asli dan mock sama-sama melempar error dari `location_core`, jadi alur UI-nya sama:
`GpsDisabledException`, `GpsPermissionDeniedException`, `GpsTimeoutException`,
`GpsUnavailableException` (Controller belum terpasang, tanda tangan beda, tidak ada di allowlist,
atau belum ada fix).

## Catatan

- Peta memakai `flutter_map` + OpenStreetMap; tidak pernah membaca GPS asli. Jangan pasang
  `flutter_map_location_marker` atau `google_maps_flutter` dengan `myLocationEnabled: true`.
- HP Xiaomi/Oppo/Vivo: matikan optimasi baterai Controller supaya rute panjang tidak dihentikan.
- Backend produksi sebaiknya menolak payload dengan `isMock: true` (lihat `LocationFix.toJson`).
