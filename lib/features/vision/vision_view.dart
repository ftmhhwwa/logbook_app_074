import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'vision_controller.dart';
import 'damage_painter.dart';

/// VisionPage implements the layered stack architecture
/// for Smart Patrol System.
///
/// Architecture:
/// - Layer 1 (Bottom): CameraPreview - Live video feed from hardware
/// - Layer 2 (Top): CustomPaint - Digital overlay for detection boxes
///
/// This follows Separation of Concerns principle:
/// - VisionController: Manages camera lifecycle and detection logic
/// - VisionPage: Manages UI layout and user interactions
/// - DamagePainter: Manages drawing logic (Phase 4)
class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Initialize controller locally for this page
  late VisionController _visionController;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();

    // Start mock detection (Phase 5)
    _visionController.startMockDetection();
  }

  @override
  void dispose() {
    // MANDATORY: Disconnect camera when navigating away
    // This prevents memory leaks and battery drain
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _visionController,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text("Smart-Patrol Vision"),
          actions: [
            // Flashlight toggle (Phase 6 UX Enhancement) - now reactive
            IconButton(
              icon: Icon(
                _visionController.isFlashlightOn
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed: _visionController.toggleFlashlight,
              tooltip: 'Toggle Flashlight',
            ),
            // Overlay visibility toggle (Phase 6 UX Enhancement) - now reactive
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
          // Show loading if camera is initializing
          if (!_visionController.isInitialized) {
            return _buildLoadingState();
          }

          // Continue to Stack structure
          return _buildVisionStack();
        },
      ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final image = await _visionController.takePhoto();
            if (image != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Photo saved: ${image.path}'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      // You can add code here to open the image
                      // For now, just showing the path
                    },
                  ),
                ),
              );
            }
          },
          tooltip: 'Capture Photo',
          child: const Icon(Icons.camera),
        ),
      ),
    );
  }

  /// Build loading state with informative message and permission handling
  /// Phase 6 UX Enhancement - improved with better error messaging
  Widget _buildLoadingState() {
    final errorMsg = _visionController.errorMessage;
    final isPermissionDenied = errorMsg?.toLowerCase().contains('permission') ?? false;
    final isCameraAccessDenied = errorMsg?.toLowerCase().contains('no camera') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart-Patrol Vision"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error state: Camera or permission denied
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
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isPermissionDenied
                            ? "Camera Permission Denied"
                            : "No Camera Access",
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
                            ? "This app needs camera permission to detect road damage. Please grant permission in Settings."
                            : "No camera device found on this device. Please ensure your device has a working camera.",
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
                            "Error: $errorMsg",
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
                        label: const Text("Open Settings"),
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
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Loading state: Initializing camera
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated background circle
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
                    // Circular progress indicator
                    const CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  "Menghubungkan ke Sensor Visual...",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Mohon tunggu sampai kamera siap",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Steps indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(1, "Request"),
                    const SizedBox(width: 12),
                    _buildStepIndicator(2, "Init"),
                    const SizedBox(width: 12),
                    _buildStepIndicator(3, "Ready"),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build a step indicator widget for loading sequence
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
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// Build the layered stack architecture
  ///
  /// This is the core of Vision architecture:
  /// - Stack with fit: StackFit.expand fills entire screen
  /// - Layer 1: CameraPreview with AspectRatio to prevent distortion
  /// - Layer 2: CustomPaint for digital overlay
  Widget _buildVisionStack() {
    final cameraController = _visionController.controller!;
    final previewSize = cameraController.value.previewSize;

    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // LAYER 1: Hardware Preview
        // Use cover scaling with native preview size to avoid portrait distortion.
        Positioned.fill(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // previewSize is landscape-oriented on most Android devices.
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(cameraController),
              ),
            ),
          ),
        ),

        // LAYER 2: Digital Overlay (Canvas)
        // This layer is transparent and sits exactly above camera
        // DamagePainter will draw detection boxes here (Phase 4)
        if (_visionController.isOverlayVisible)
          Positioned.fill(
            child: CustomPaint(
              painter: DamagePainter(
                _visionController.currentDetections,
              ), // Phase 4: Will be updated with detections
            ),
          ),
      ],
    );
  }
}