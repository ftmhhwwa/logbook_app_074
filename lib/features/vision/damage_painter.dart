import 'package:flutter/material.dart';


class DamagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Konfigurasi "Kuas" Digital
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke; // Garis pinggir saja, bukan blok warna
      
    // 2. Menghitung Dimensi Kotak (Simulasi Pothole RDD-2022)
    // Membuat kotak di tengah layar seluas 50% dari lebar layar
    double boxSize = size.width * 0.5;
    double left = (size.width - boxSize) / 2;
    double top = (size.height - boxSize) / 2;

    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // 3. Menggambar Kotak ke Kanvas
    canvas.drawRect(rect, paint);

    // 4. Konstruksi Label Tipe Kerusakan
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.redAccent,
    );

    final textSpan = TextSpan(
      text: " [D40] POTHOLE - 92% ", // Kode D40 merujuk pada RDD-2022
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    // 5. Proses Layouting & Rendering Teks
    textPainter.layout();
    // Gambar teks tepat di atas garis kotak (offset -25 pixel)
    textPainter.paint(canvas, Offset(left, top - 25));
  }

@override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Untuk tahap awal (statis), kita kembalikan false untuk menghemat CPU.
    return false; 
  }
}

