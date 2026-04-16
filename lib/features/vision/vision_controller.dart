import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// VisionController manages the camera lifecycle and detection logic
/// for the Smart Patrol System.
///
/// This controller follows SOLID principles:
/// - Single Responsibility: Manages only camera and detection state
/// - Open/Closed: Can be extended without modifying core logic
/// - Dependency Inversion: Depends on abstractions (ChangeNotifier)
class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  // Camera controller instance
  CameraController? controller;

  // ============ RESOURCE MANAGEMENT ============
  /// Tracks if controller has been disposed to prevent use-after-free
  bool _disposed = false;

  // ============ STATE TRACKING ============
  bool isInitialized = false;
  String? errorMessage;

  // Detection results (for Phase 5)
  List<DetectionResult> currentDetections = [];
  Timer? _mockDetectionTimer;

  // UX Enhancement: Flashlight and Overlay toggles (Phase 6)
  bool isFlashlightOn = false;
  bool isOverlayVisible = true;

  String? lastFlashMessage; // Track flash toggle feedback for UX

  /// Getter for resource state (for lifecycle debugging)
  bool get isDisposed => _disposed;

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  VisionController() {
    // Register observer to monitor app lifecycle status
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  /// Initialize the rear camera for high-quality detection.
  Future<void> initCamera() async {
    try {
      // Dispose previous controller instance before creating a new one.
      await controller?.dispose();
      controller = null;
      isInitialized = false;

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
        _notifySafely();
        return;
      }

      // Select Rear Camera (Index 0)
      controller = CameraController(
        cameras[0],
        ResolutionPreset
            .ultraHigh, // Use high resolution for better photo quality
        enableAudio: false, // We only need visual for road damage detection
        imageFormatGroup:
            ImageFormatGroup.jpeg, // Use JPEG format for better compatibility
      );

      await controller!.initialize();

      // Keep camera orientation consistent in portrait mode.
      await controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      isInitialized = true;
      errorMessage = null;
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    }

    _notifySafely();
  }

  /// Capture photo from camera stream
  /// This ensures full frame capture with proper resolution
  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) {
      return null;
    }

    try {
      // Pause camera stream briefly to ensure clean capture
      await controller!.pausePreview();

      // Small delay to ensure camera is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the picture
      final image = await controller!.takePicture();

      // Resume camera stream
      await controller!.resumePreview();

      return image;
    } catch (e) {
      errorMessage = "Failed to capture photo: $e";
      _notifySafely();
      return null;
    }
  }

  /// Handle app lifecycle state changes
  ///
  /// This is CRITICAL for preventing memory leaks and battery drain
  /// - AppLifecycleState.inactive: Release camera when app goes to background
  /// - AppLifecycleState.resumed: Re-initialize camera when app returns to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Release camera resource when app is not visible.
      controller?.dispose();
      controller = null;
      isInitialized = false;
      _notifySafely();
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera when user returns to app.
      if (!_disposed) {
        initCamera();
      }
    }
  }

  /// Toggle flashlight (torch) on/off
  /// UX Enhancement from Phase 6
  Future<void> toggleFlashlight() async {
    if (controller == null || !controller!.value.isInitialized) {
      errorMessage = "Camera not initialized for flashlight toggle";
      _notifySafely();
      return;
    }

    final nextState = !isFlashlightOn;

    try {
      // Use torch mode for continuous light (better compatibility than 'always')
      // Fallback to 'always' if torch not available on device
      final flashMode = nextState ? FlashMode.torch : FlashMode.off;

      await controller!.setFlashMode(flashMode);
      isFlashlightOn = nextState;
      lastFlashMessage = nextState ? "Torch ON" : "Torch OFF";
      errorMessage = null;
    } catch (e) {
      // Try fallback: use 'always' mode
      if (nextState) {
        try {
          await controller!.setFlashMode(FlashMode.always);
          isFlashlightOn = true;
          lastFlashMessage = "Torch ON (mode: always)";
          errorMessage = null;
        } catch (fallbackError) {
          isFlashlightOn = false;
          errorMessage = "Flashlight not supported on this device";
          lastFlashMessage = "Torch tidak didukung";
        }
      } else {
        // Turning off should always work
        try {
          await controller!.setFlashMode(FlashMode.off);
          isFlashlightOn = false;
          lastFlashMessage = "Torch OFF";
          errorMessage = null;
        } catch (turnOffError) {
          errorMessage = "Failed to turn off flashlight: $turnOffError";
        }
      }
    }

    _notifySafely();
  }

  /// Toggle overlay visibility
  /// UX Enhancement from Phase 6
  void toggleOverlay() {
    isOverlayVisible = !isOverlayVisible;
    _notifySafely();
  }

  /// Start mock detection simulation
  /// Phase 5: Simulates AI detection by moving bounding box every 3 seconds
  void startMockDetection() {
    _mockDetectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _generateMockDetection(),
    );
  }

  /// Generate a mock detection result at random position
  /// This simulates YOLO output before actual AI integration in Module 7
  void _generateMockDetection() {
    final random = Random();

    // Generate random normalized coordinates (0.0 - 1.0)
    // Keep within 10%-90% range to avoid edge clipping
    final x = random.nextDouble() * 0.8 + 0.1;
    final y = random.nextDouble() * 0.8 + 0.1;
    final width = 0.2 + random.nextDouble() * 0.2; // 20%-40% of screen width
    final height = 0.1 + random.nextDouble() * 0.1; // 10%-20% of screen height

    // Create detection result
    currentDetections = [
      DetectionResult(
        box: Rect.fromLTWH(x, y, width, height),
        label: _getRandomDamageType(),
        score: 0.85 + random.nextDouble() * 0.14, // 85%-99% confidence
      ),
    ];

    _notifySafely();
  }

  /// Get a random damage type from RDD-2022 dataset
  String _getRandomDamageType() {
    final types = ['D00', 'D10', 'D20', 'D40'];
    final labels = {
      'D00': 'Longitudinal Crack',
      'D10': 'Transverse Crack',
      'D20': 'Alligator Crack',
      'D40': 'Pothole',
    };
    final type = types[Random().nextInt(types.length)];
    return ' [$type] ${labels[type]!}';
  }

  /// Clean up resources
  ///
  /// This is MANDATORY to prevent memory leaks
  /// - Remove observer to stop listening to lifecycle events
  /// - Dispose camera controller to release hardware
  /// - Cancel mock detection timer
  @override
  void dispose() {
    // Remove observer to prevent memory leak
    WidgetsBinding.instance.removeObserver(this);

    // Cancel mock detection timer
    _mockDetectionTimer?.cancel();

    // Release camera hardware
    controller?.dispose();
    controller = null;
    _disposed = true;

    super.dispose();
  }
}

/// Data Transfer Object (DTO) for detection results
///
/// This follows the Single Responsibility Principle:
/// - VisionController generates these objects
/// - DamagePainter only draws them
///
/// If you replace YOLO with another model, only change data population
/// in VisionController without touching UI or Painter code.
class DetectionResult {
  final Rect box; // Box coordinates (normalized 0.0-1.0)
  final String label; // Damage type (D40, D20, etc)
  final double score; // AI confidence percentage (0.0-1.0)

  DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}
