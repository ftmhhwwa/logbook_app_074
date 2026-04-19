# logbook_app_074

## Deskripsi Aplikasi

`logbook_app_074` adalah aplikasi Flutter yang dikembangkan untuk mendukung alur kerja Smart-Patrol Vision dan pengelolaan logbook. Aplikasi ini memadukan fitur kamera, upload gambar, serta image processing untuk membantu proses analisis visual pada gambar yang diambil dari perangkat atau galeri.

## Ruang Lingkup Fitur

Aplikasi ini memiliki beberapa fitur utama, yaitu:

- Pengambilan foto langsung dari kamera perangkat.
- Upload gambar dari galeri untuk diproses pada halaman vision preview.
- Image processing menggunakan OpenCV dan manipulasi piksel manual.
- Filter visual seperti brightness, contrast, grayscale, gaussian blur, sharpening, edge detection, thresholding, median filter, gamma correction, inverse, dan frequency domain.
- Halaman logbook serta autentikasi pengguna.

## Kebutuhan Sistem

Untuk menjalankan aplikasi ini, diperlukan beberapa komponen berikut:

- Flutter SDK 3.38+ atau versi yang kompatibel.
- Dart SDK yang sudah termasuk dalam instalasi Flutter.
- Android Studio atau Visual Studio Code dengan ekstensi Flutter.
- Perangkat Android atau emulator yang mendukung kamera.
- Opsional: perangkat iOS atau simulator untuk pengujian iOS.

## Instalasi Proyek

Langkah instalasi proyek adalah sebagai berikut:

1. Buka atau clone repositori proyek ke komputer Anda.
2. Pastikan Flutter sudah terpasang dan dapat diakses melalui `PATH`.
3. Masuk ke direktori root proyek, kemudian jalankan perintah berikut untuk mengunduh seluruh dependency:

```bash
flutter pub get
```

4. Jika proyek dijalankan pada Android, pastikan Android SDK telah dikonfigurasi dengan benar.
5. Jika aplikasi memerlukan konfigurasi lokal, pastikan file `.env` tersedia pada root proyek.

## Menjalankan Aplikasi

Untuk menjalankan aplikasi pada perangkat atau emulator yang terhubung, gunakan perintah berikut:

```bash
flutter run
```

Jika terdapat lebih dari satu perangkat, perangkat dapat dipilih terlebih dahulu dengan:

```bash
flutter devices
flutter run -d <device_id>
```

## Izin Akses

Fitur vision memerlukan izin kamera dan akses galeri.

- Pada Android, izinkan kamera serta akses media/storage ketika diminta.
- Pada iOS, pastikan izin kamera dan photo library telah dikonfigurasi pada pengaturan aplikasi.

## Asset dan Konfigurasi

Proyek ini menggunakan asset yang tersimpan pada folder `assets/images/` dan file `.env` untuk kebutuhan konfigurasi.
Jika menambahkan asset baru, daftarkan terlebih dahulu pada `pubspec.yaml`, kemudian jalankan kembali `flutter pub get`.

## Build Aplikasi

### Build Android

```bash
flutter build apk
```

### Build iOS

```bash
flutter build ios
```

## Catatan Implementasi

- Vision preview mendukung pengambilan foto dari kamera dan upload gambar dari galeri.
- Image processing dibangun menggunakan pipeline OpenCV serta manipulasi piksel manual untuk analisis realtime.
- Jika terdapat perubahan pada dependency native, jalankan `flutter clean` kemudian `flutter pub get`.

## Troubleshooting

Jika aplikasi mengalami kendala, beberapa langkah berikut dapat dilakukan:

- Periksa izin kamera dan galeri pada perangkat.
- Pastikan perangkat atau emulator mendukung kamera.
- Jika build gagal setelah perubahan dependency, jalankan:

```bash
flutter clean
flutter pub get
flutter run
```

## Perintah yang Sering Digunakan

```bash
flutter doctor
flutter devices
flutter pub get
flutter run
flutter build apk
```
