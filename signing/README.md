# Keystore internal

Controller dan build **dev** aplikasi target harus ditandatangani keystore yang sama,
karena provider Controller dilindungi izin `signature`.

Tanpa konfigurasi apa pun, kedua app memakai debug keystore bawaan
(`~/.android/debug.keystore`). Itu sudah cukup kalau semua APK dibangun di satu mesin.

Untuk tim atau CI, buat keystore internal (BUKAN keystore rilis Play Store):

```bash
keytool -genkeypair -v -keystore signing/internal.jks -alias mockloc \
  -keyalg RSA -keysize 2048 -validity 10000
```

Lalu buat `signing/internal.properties`:

```properties
storeFile=internal.jks
storePassword=...
keyAlias=mockloc
keyPassword=...
```

Kedua file ini ada di `.gitignore`. Di CI, simpan sebagai secret.
