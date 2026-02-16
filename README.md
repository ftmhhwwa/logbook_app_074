# LogBook App - Tugas Modul 1 📱

**Oleh:** Fatimah Hawwa Alkhansa  
**NIM:** 241511074  
**Kelas:** 2C - D3 Teknik Informatika

## 📋 Deskripsi Proyek
Aplikasi ini merupakan implementasi logbook sederhana berbasis Flutter yang dirancang untuk mencatat aktivitas perubahan nilai (Counter). Proyek ini berfokus pada penerapan arsitektur perangkat lunak yang bersih menggunakan prinsip **Single Responsibility Principle (SRP)**.

## ✨ Fitur Utama
- **Dynamic Step Adjustment**: Pengguna dapat menentukan besaran nilai penambahan atau pengurangan secara dinamis melalui input field.
- **History Logger (The Twist)**: Mencatat 5 aktivitas terakhir (Increment, Decrement, Reset) secara otomatis dengan menyertakan keterangan waktu (jam) dan saldo akhir.
- **Smart History Limit**: Riwayat aktivitas dibatasi hanya untuk **5 entri terbaru** menggunakan manipulasi List (`removeLast`).
- **UX Protection**: 
  - Dialog konfirmasi sebelum melakukan reset data.
  - SnackBar sebagai notifikasi instan saat aksi berhasil atau gagal (seperti validasi nilai minus).
- **UI Polishing**: Antarmuka modern dengan tombol aksi yang memiliki identitas warna (Merah untuk Minus, Hijau untuk Add, Oranye untuk Reset).

## 🧠 Self-Reflection: Bagaimana SRP Membantu Pengembangan?

Dalam mengerjakan tugas ini, prinsip **Single Responsibility Principle (SRP)** memberikan dampak yang signifikan terhadap efisiensi proses *coding* saya:

1. **Pemisahan Tanggung Jawab yang Jelas**:
   - `CounterController` bertanggung jawab sepenuhnya atas logika (Logic). Di sinilah perhitungan angka dan aturan pembatasan riwayat 5 data dikelola.
   - `CounterView` bertanggung jawab hanya pada tampilan (UI). File ini tidak tahu bagaimana angka dihitung, ia hanya bertugas menampilkan apa yang diberikan oleh Controller.

2. **Kemudahan Saat Menambah Fitur**:
   Ketika saya harus menambahkan fitur **History Logger**, saya tidak perlu mengutak-atik file UI yang rumit. Saya cukup fokus di file Controller untuk membuat fungsi privat `_addLog`. Karena logikanya terpusat, fitur riwayat ini otomatis bekerja di semua aksi (tambah, kurang, reset) tanpa ada kode yang tumpang tindih.

3. **Proses Debugging yang Cepat**:
   Saat fitur limit 5 data sempat tidak berjalan di fungsi *increment*, saya tidak perlu mencari kesalahan di ribuan baris widget. Saya langsung menuju `counter_controller.dart` dan menemukan bahwa fungsi tersebut belum diarahkan ke pintu log yang benar. SRP membuat struktur kode menjadi sangat terprediksi.

4. **Skalabilitas**:
   Jika kedepannya saya ingin mengubah format jam atau menambah fitur simpan data ke database, saya cukup memodifikasi Controller. Tampilan aplikasi saya akan tetap aman dan tidak akan *error* karena perubahan logika tersebut.

---
*Proyek ini dikembangkan sebagai bagian dari Tugas Mata Kuliah Proyek 4 - 2026.*