import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

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

  // ============ PCD PIPELINE STATE ============
  bool isProcessing = false;
  bool isPcdStreamRunning = false;
  int _processedFrameCount = 0;
  Map<String, dynamic>? lastPcdResult;

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
            ImageFormatGroup.yuv420, // Better for per-frame PCD processing
      );

      await controller!.initialize();

      // Keep camera orientation consistent in portrait mode.
      await controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Start per-frame PCD stream in background isolate.
      await startPcdStream();

      isInitialized = true;
      errorMessage = null;
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    }

    _notifySafely();
  }

  /// Start real-time PCD stream.
  ///
  /// Notes:
  /// - CameraImage is not directly sendable to isolate in a safe/reliable way.
  /// - We extract a lightweight payload (luma plane bytes + metadata) and pass it to compute().
  Future<void> startPcdStream() async {
    final activeController = controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return;
    }
    if (isPcdStreamRunning) {
      return;
    }

    await activeController.startImageStream((CameraImage cameraImage) async {
      if (_disposed || isProcessing) {
        return; // Drop frame if controller is disposed or worker still busy.
      }

      isProcessing = true;

      try {
        final firstPlane = cameraImage.planes.first;
        final payload = <String, dynamic>{
          'bytes': Uint8List.fromList(firstPlane.bytes),
          'width': cameraImage.width,
          'height': cameraImage.height,
          'bytesPerRow': firstPlane.bytesPerRow,
          'bytesPerPixel': firstPlane.bytesPerPixel ?? 1,
        };

        final result = await compute(_pcdWorker, payload);
        lastPcdResult = result;
        _processedFrameCount += 1;

        // Notify periodically to avoid excessive UI rebuilds.
        if (_processedFrameCount % 10 == 0) {
          _notifySafely();
        }
      } catch (e) {
        errorMessage = 'PCD stream error: $e';
        _notifySafely();
      } finally {
        isProcessing = false;
      }
    });

    isPcdStreamRunning = true;
    _notifySafely();
  }

  Future<void> stopPcdStream() async {
    final activeController = controller;
    if (activeController == null) {
      isPcdStreamRunning = false;
      return;
    }

    if (!activeController.value.isStreamingImages) {
      isPcdStreamRunning = false;
      return;
    }

    try {
      await activeController.stopImageStream();
    } catch (_) {
      // Ignore stream stop errors during lifecycle transitions.
    } finally {
      isPcdStreamRunning = false;
      isProcessing = false;
      _notifySafely();
    }
  }

  /// Capture photo from camera stream
  /// This ensures full frame capture with proper resolution
  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) {
      return null;
    }

    try {
      final wasStreaming = isPcdStreamRunning;
      if (wasStreaming) {
        await stopPcdStream();
      }

      // Pause camera stream briefly to ensure clean capture
      await controller!.pausePreview();

      // Small delay to ensure camera is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the picture
      final image = await controller!.takePicture();

      // Resume camera stream
      await controller!.resumePreview();

      if (wasStreaming) {
        await startPcdStream();
      }

      return image;
    } catch (e) {
      errorMessage = "Failed to capture photo: $e";
      _notifySafely();
      return null;
    }
  }

  /// Build filtered preview image bytes from captured photo.
  /// Returns PNG bytes of processed (binary) image for UI preview.
  Future<Uint8List?> buildFilteredPreview(XFile capturedPhoto) async {
    try {
      final bytes = await capturedPhoto.readAsBytes();
      final payload = <String, dynamic>{'bytes': Uint8List.fromList(bytes)};
      final result = await compute(_pcdPhotoWorker, payload);

      if (result['metrics'] is Map<String, dynamic>) {
        lastPcdResult = result['metrics'] as Map<String, dynamic>;
      }

      final previewBytes = result['previewPng'];
      if (previewBytes is Uint8List) {
        _notifySafely();
        return previewBytes;
      }

      errorMessage = result['error']?.toString() ?? 'Failed to build preview';
      _notifySafely();
      return null;
    } catch (e) {
      errorMessage = 'Failed to process filtered preview: $e';
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
      unawaited(stopPcdStream());
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

    unawaited(stopPcdStream());

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

/// Isolate worker for PCD pipeline.
///
/// Input payload keys:
/// - bytes: Uint8List (luma / first plane)
/// - width: int
/// - height: int
/// - bytesPerRow: int
/// - bytesPerPixel: int
Map<String, dynamic> _pcdWorker(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as Uint8List;
  final width = payload['width'] as int;
  final height = payload['height'] as int;
  final bytesPerRow = payload['bytesPerRow'] as int;
  final bytesPerPixel = payload['bytesPerPixel'] as int;

  // 1) Convert camera plane to grayscale image
  final src = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rowIndex = y * bytesPerRow;
      final pixelIndex = rowIndex + (x * bytesPerPixel);
      if (pixelIndex >= bytes.length) continue;

      final v = bytes[pixelIndex];
      src.setPixelRgba(x, y, v, v, v, 255);
    }
  }

  // Important for real-time CPU processing: resize to small resolution first.
  final resized = img.copyResize(src, width: 320, height: 320);

  // 2) Histogram & contrast enhancement
  final highContrastImg = img.adjustColor(resized, contrast: 1.5);
  final grayscaleImg = img.grayscale(highContrastImg);

  final histogram = List<int>.filled(256, 0);
  var luminanceSum = 0;
  var pixelCount = 0;
  for (final p in grayscaleImg) {
    final lum = p.r.toInt().clamp(0, 255);
    histogram[lum] += 1;
    luminanceSum += lum;
    pixelCount += 1;
  }

  // 3) Convolution pipeline (blur + edge)
  final blurredImg = img.gaussianBlur(grayscaleImg, radius: 3);
  const edgeKernel = <num>[-1, -1, -1, -1, 8, -1, -1, -1, -1];
  final edgeImg = img.convolution(
    blurredImg,
    filter: edgeKernel,
    div: 1,
    offset: 0,
  );

  // 4) Binary thresholding
  final binaryImg = img.luminanceThreshold(edgeImg, threshold: 100);

  var whitePixels = 0;
  for (final p in binaryImg) {
    if (p.r > 127) whitePixels += 1;
  }

  // Quick histogram peaks for logging/debugging.
  var peakBin = 0;
  var peakValue = 0;
  for (var i = 0; i < histogram.length; i++) {
    if (histogram[i] > peakValue) {
      peakValue = histogram[i];
      peakBin = i;
    }
  }

  final meanLuminance = pixelCount == 0 ? 0.0 : luminanceSum / pixelCount;
  final edgeDensity = pixelCount == 0 ? 0.0 : whitePixels / pixelCount;

  return {
    'status': 'Pemrosesan PCD Selesai',
    'width': resized.width,
    'height': resized.height,
    'meanLuminance': meanLuminance,
    'histogramPeakBin': peakBin,
    'histogramPeakValue': peakValue,
    'edgeDensity': edgeDensity,
  };
}

/// Isolate worker for captured-photo preview processing.
/// Input payload keys:
/// - bytes: Uint8List (encoded image: jpg/png)
Map<String, dynamic> _pcdPhotoWorker(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {'error': 'Unable to decode captured image'};
  }

  // Resize first to keep CPU processing fast and stable.
  final resized = img.copyResize(decoded, width: 320, height: 320);

  // PCD pipeline: contrast -> grayscale -> blur -> convolution -> binary threshold.
  final highContrastImg = img.adjustColor(resized, contrast: 1.5);
  final grayscaleImg = img.grayscale(highContrastImg);
  final blurredImg = img.gaussianBlur(grayscaleImg, radius: 3);
  const edgeKernel = <num>[-1, -1, -1, -1, 8, -1, -1, -1, -1];
  final edgeImg = img.convolution(
    blurredImg,
    filter: edgeKernel,
    div: 1,
    offset: 0,
  );
  final binaryImg = img.luminanceThreshold(edgeImg, threshold: 100);

  // Basic metrics for overlay/debug status.
  final histogram = List<int>.filled(256, 0);
  var luminanceSum = 0;
  var whitePixels = 0;
  var pixelCount = 0;

  for (final p in binaryImg) {
    final lum = p.r.toInt().clamp(0, 255);
    histogram[lum] += 1;
    luminanceSum += lum;
    if (lum > 127) whitePixels += 1;
    pixelCount += 1;
  }

  var peakBin = 0;
  var peakValue = 0;
  for (var i = 0; i < histogram.length; i++) {
    if (histogram[i] > peakValue) {
      peakValue = histogram[i];
      peakBin = i;
    }
  }

  final meanLuminance = pixelCount == 0 ? 0.0 : luminanceSum / pixelCount;
  final edgeDensity = pixelCount == 0 ? 0.0 : whitePixels / pixelCount;
  final pngBytes = Uint8List.fromList(img.encodePng(binaryImg));

  return {
    'previewPng': pngBytes,
    'metrics': {
      'status': 'Preview filter siap',
      'width': binaryImg.width,
      'height': binaryImg.height,
      'meanLuminance': meanLuminance,
      'histogramPeakBin': peakBin,
      'histogramPeakValue': peakValue,
      'edgeDensity': edgeDensity,
    },
  };
}
