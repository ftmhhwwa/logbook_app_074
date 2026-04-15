import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:logbook_app_001/features/vision/vision_controller.dart';
import 'package:logbook_app_001/features/vision/damage_painter.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});


  @override
  State<VisionView> createState() => _VisionViewState();
}


class _VisionViewState extends State<VisionView> {
  // Inisialisasi controller secara lokal untuk halaman ini
  late VisionController _visionController;


  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
  }


  @override
  void dispose() {
    // WAJIB: Memutus akses kamera saat pindah halaman
    _visionController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("Smart-Patrol Vision")),
    body: ListenableBuilder(
      listenable: _visionController,
      builder: (context, child) {
        // Tampilkan loading jika kamera sedang inisialisasi
        if (!_visionController.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Lanjut ke struktur Stack di sub-langkah berikutnya
        return _buildVisionStack();
      },
    ),
  );
}

Widget _buildVisionStack() {
  return Stack(
    fit: StackFit.expand,
    children: [
      // LAYER 1: Hardware Preview
      // Menggunakan AspectRatio agar gambar tidak gepeng (Koneksi PCD)
      Center(
        child: AspectRatio(
          aspectRatio: _visionController.controller!.value.aspectRatio,
          child: CameraPreview(_visionController.controller!),
        ),
      ),


      // LAYER 2: Digital Overlay (Canvas)
      // Layer ini transparan dan berada tepat di atas kamera
      Positioned.fill(
        child: CustomPaint(
          painter: DamagePainter(), // Langkah 4
        ),
      ),
    ],
  );
}
}
