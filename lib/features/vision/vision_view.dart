import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'damage_painter.dart';
import 'vision_controller.dart';

/// VisionPage implements the layered stack architecture
/// for Smart Patrol System.
class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  late VisionController _visionController;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
    _visionController.startMockDetection();
  }

  @override
  void dispose() {
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _visionController,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Smart-Patrol Vision'),
          backgroundColor: const Color(0xFF4E342E),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                _visionController.isFlashlightOn
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed: () async {
                await _visionController.toggleFlashlight();
                if (context.mounted &&
                    _visionController.lastFlashMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_visionController.lastFlashMessage!),
                      duration: const Duration(milliseconds: 800),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              tooltip: _visionController.isFlashlightOn
                  ? 'Torch ON'
                  : 'Torch OFF',
              color: _visionController.isFlashlightOn ? Colors.amber : null,
            ),
            IconButton(
              icon: Icon(
                _visionController.isOverlayVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: _visionController.toggleOverlay,
              tooltip: 'Toggle Overlay',
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _visionController,
          builder: (context, child) {
            if (!_visionController.isInitialized) {
              return _buildLoadingState();
            }

            return Column(
              children: [
                Expanded(child: _buildVisionStack()),
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _handleImageAction(
                              context,
                              action: _visionController.pickImageFromGallery,
                              failureMessage: 'Gagal memilih gambar',
                            );
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 22),
                          label: const Text(
                            'Upload Gambar',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: const Color(0xFF4E342E),
                            side: const BorderSide(color: Color(0xFF4E342E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _handleImageAction(
                              context,
                              action: _visionController.takePhoto,
                              failureMessage: 'Gagal mengambil foto',
                            );
                          },
                          icon: const Icon(Icons.camera_rounded, size: 24),
                          label: const Text(
                            'Ambil Foto',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF4E342E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build loading state with informative message and permission handling.
  Widget _buildLoadingState() {
    final errorMsg = _visionController.errorMessage;
    final isPermissionDenied =
        errorMsg?.toLowerCase().contains('permission') ?? false;
    final isCameraAccessDenied =
        errorMsg?.toLowerCase().contains('no camera') ?? false;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPermissionDenied || isCameraAccessDenied) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.red.shade700),
                      const SizedBox(height: 16),
                      Text(
                        isPermissionDenied
                            ? 'Camera Permission Denied'
                            : 'No Camera Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPermissionDenied
                            ? 'This app needs camera permission to detect road damage. Please grant permission in Settings.'
                            : 'No camera device found on this device. Please ensure your device has a working camera.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Error: $errorMsg',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => openAppSettings(),
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _visionController.initCamera(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade50,
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 2,
                        ),
                      ),
                    ),
                    const CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Menghubungkan ke Sensor Visual...',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mohon tunggu sampai kamera siap',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(1, 'Request'),
                    const SizedBox(width: 12),
                    _buildStepIndicator(2, 'Init'),
                    const SizedBox(width: 12),
                    _buildStepIndicator(3, 'Ready'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade100,
            border: Border.all(color: Colors.blue.shade400, width: 2),
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _handleImageAction(
    BuildContext context, {
    required Future<XFile?> Function() action,
    required String failureMessage,
  }) async {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final image = await action();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_visionController.errorMessage ?? failureMessage),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisionPreviewPage(
          controller: _visionController,
          capturedImage: image,
        ),
      ),
    );
  }

  Widget _buildVisionStack() {
    final cameraController = _visionController.controller!;
    final previewSize = cameraController.value.previewSize;

    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(cameraController),
              ),
            ),
          ),
        ),
        if (_visionController.isOverlayVisible)
          Positioned.fill(
            child: CustomPaint(
              painter: DamagePainter(
                _visionController.currentDetections,
                pcdMetrics: _visionController.lastPcdResult,
              ),
            ),
          ),
      ],
    );
  }
}
