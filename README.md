# MockLoc

Alat testing lokasi untuk aplikasi Android. Bisa dipakai di HP **non-root** maupun **root**:

- **Mode Controller/Panel** (non-root, tanpa Opsi Pengembang): lokasi palsu hanya untuk aplikasi
  Flutter-mu sendiri. Aplikasi target membaca lokasi lewat `LocationSource`, dan di build dev
  sumber itu bisa diarahkan ke Controller. Aplikasi lain (Google Maps, WhatsApp, dll.) tetap
  melihat lokasi asli.
- **Mode Sistem** (non-root lewat Opsi Pengembang, atau root): lokasi palsu dikirim ke provider
  lokasi Android, jadi semua aplikasi ikut melihatnya. Lihat [Non-root vs root](#non-root-vs-root).

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

## Mode Sistem

Tab **Sistem** di Controller mengirim fix yang sama ke provider lokasi Android (GPS, network,
fused) dan ke API mock Google Play Services, sehingga Google Maps dan aplikasi lain ikut melihatnya.
Izinnya bisa diberikan dengan dua cara:

- **Non-root**: nyalakan Opsi Pengembang (Setelan → Tentang ponsel → tap "Nomor build" 7 kali),
  lalu Opsi Pengembang → "Pilih aplikasi lokasi palsu" → MockLoc Controller.
- **Root**: tap "Izinkan via root" di tab Sistem, lalu izinkan di Magisk/KernelSU. Controller
  menjalankan `su -c "appops set … android:mock_location allow"`. Opsi Pengembang tidak perlu
  dinyalakan.

Di kedua cara, Android tetap menandai lokasi ini sebagai mock (`Location.isMock`). Mode
Controller/Panel tidak terpengaruh mode Sistem.

## Non-root vs root

| | Non-root | Root |
|---|---|---|
| Mode Controller/Panel (aplikasi sendiri) | Ya, tanpa Opsi Pengembang | Ya, sama persis |
| Mode Sistem (semua aplikasi) | Ya, lewat Opsi Pengembang | Ya, tanpa Opsi Pengembang |
| Setup mode Sistem | Aktifkan Opsi Pengembang + pilih aplikasi lokasi palsu | Satu tap "Izinkan via root" |
| Ditandai mock oleh Android | Ya | Ya |

**Kelebihan non-root**

- Jalan di HP apa saja, tanpa unlock bootloader, tanpa kehilangan garansi atau update OTA.
- Mode Controller/Panel tidak butuh izin khusus apa pun; cukup pasang Controller dan app target dev.
- Lebih aman untuk HP harian: tidak ada aplikasi yang memegang akses `su`.

**Kelebihan root**

- Mode Sistem aktif tanpa menyalakan Opsi Pengembang, jadi setelan HP lain tidak ikut berubah.
- Setup lebih cepat: satu tap, tanpa menelusuri menu Opsi Pengembang yang letaknya beda-beda di
  tiap merek (Xiaomi, Samsung, Oppo, dll.).
- Cocok untuk HP khusus testing yang sudah di-root.

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
