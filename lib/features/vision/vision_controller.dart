import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

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

  /// Build interactive preview image bytes from captured photo.
  /// Returns PNG bytes plus histogram and metrics for the preview page.
  Future<PhotoPreviewResult?> buildInteractivePreview(
    XFile capturedPhoto, {
    required VisionPipelineOptions options,
    required VisionImageDomain activeDomain,
  }) async {
    try {
      final bytes = await capturedPhoto.readAsBytes();
      final validation = _validateDomain(activeDomain, options);
      if (!validation.isValid) {
        errorMessage = validation.message;
        _notifySafely();
        return null;
      }

      final result = _buildOpenCvPreview(
        bytes,
        options: options,
        activeDomain: activeDomain,
      );

      lastPcdResult = result.metrics;
      _notifySafely();
      return result;
    } catch (e) {
      errorMessage = 'Failed to process filtered preview: $e';
      _notifySafely();
      return null;
    }
  }

  _DomainValidation _validateDomain(
    VisionImageDomain domain,
    VisionPipelineOptions options,
  ) {
    final usesSpatialOperations =
        options.brightness.abs() > 0.001 ||
        (options.contrast - 1.0).abs() > 0.001 ||
        options.histogramEqualization ||
        options.gaussianBlur ||
        options.sharpening ||
        options.edgeDetectionCanny ||
        options.thresholding ||
        options.medianFilter ||
        options.gammaCorrection;

    if (domain == VisionImageDomain.frequency && usesSpatialOperations) {
      return const _DomainValidation(
        isValid: false,
        message:
            'Operasi spasial tidak tersedia saat domain frequency aktif. Kembali ke domain spatial terlebih dahulu.',
      );
    }

    if (domain == VisionImageDomain.spatial && options.inverseDft) {
      return const _DomainValidation(
        isValid: false,
        message: 'Inverse DFT hanya valid saat domain frequency aktif.',
      );
    }

    return const _DomainValidation(isValid: true);
  }

  PhotoPreviewResult _buildOpenCvPreview(
    Uint8List encodedBytes, {
    required VisionPipelineOptions options,
    required VisionImageDomain activeDomain,
  }) {
    final src = cv.imdecode(encodedBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) {
      throw Exception('Unable to decode captured image with OpenCV');
    }

    cv.Mat gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    if (activeDomain == VisionImageDomain.spatial) {
      gray = _applySpatialPipeline(gray, options);
    }

    final wantsFrequency =
        activeDomain == VisionImageDomain.frequency ||
        options.frequencyMagnitude;

    if (wantsFrequency) {
      final frequencyResult = _buildFrequencyPreview(
        gray,
        options: options,
        activeDomain: activeDomain,
      );
      src.dispose();
      gray.dispose();
      return frequencyResult;
    }

    final histogram = _buildHistogram(gray);
    final metrics = _buildMetrics(gray, histogram);
    final (ok, previewPng) = cv.imencode('.png', gray);

    if (!ok) {
      throw Exception('Failed to encode OpenCV preview image');
    }

    src.dispose();
    gray.dispose();

    return PhotoPreviewResult(
      previewPng: previewPng,
      histogram: histogram,
      metrics: {...metrics, 'status': 'OpenCV spatial pipeline siap'},
      modeLabel: 'Spatial Domain',
      activeDomain: VisionImageDomain.spatial,
    );
  }

  cv.Mat _applySpatialPipeline(cv.Mat input, VisionPipelineOptions options) {
    var out = input.clone();

    if (options.brightness.abs() > 0.001 ||
        (options.contrast - 1.0).abs() > 0.001) {
      out = out.convertTo(
        cv.MatType.CV_8UC1,
        alpha: options.contrast,
        beta: options.brightness * 100.0,
      );
    }

    if (options.histogramEqualization) {
      out = cv.equalizeHist(out);
    }

    if (options.gaussianBlur) {
      final k = _oddKernel(options.gaussianKernelSize);
      out = cv.gaussianBlur(out, (k, k), 0);
    }

    if (options.sharpening) {
      final kernel = cv.Mat.fromList(3, 3, cv.MatType.CV_32FC1, [
        0.0,
        -1.0,
        0.0,
        -1.0,
        5.0,
        -1.0,
        0.0,
        -1.0,
        0.0,
      ]);
      out = cv.filter2D(out, -1, kernel);
      kernel.dispose();
    }

    if (options.edgeDetectionCanny) {
      out = cv.canny(out, options.cannyThreshold1, options.cannyThreshold2);
    }

    if (options.thresholding) {
      final (_, dst) = cv.threshold(
        out,
        options.thresholdValue,
        255,
        cv.THRESH_BINARY,
      );
      out = dst;
    }

    if (options.medianFilter) {
      out = cv.medianBlur(out, _oddKernel(options.medianKernelSize));
    }

    if (options.gammaCorrection) {
      final gamma = options.gamma <= 0 ? 1.0 : options.gamma;
      final lut = List<int>.generate(256, (i) {
        final v = (pow(i / 255.0, 1.0 / gamma) * 255.0).round();
        return v.clamp(0, 255);
      });
      final lutMat = cv.Mat.fromList(1, 256, cv.MatType.CV_8UC1, lut);
      out = cv.LUT(out, lutMat);
      lutMat.dispose();
    }

    return out;
  }

  PhotoPreviewResult _buildFrequencyPreview(
    cv.Mat gray, {
    required VisionPipelineOptions options,
    required VisionImageDomain activeDomain,
  }) {
    final optimalRows = cv.getOptimalDFTSize(gray.rows);
    final optimalCols = cv.getOptimalDFTSize(gray.cols);
    final padded = cv.copyMakeBorder(
      gray,
      0,
      optimalRows - gray.rows,
      0,
      optimalCols - gray.cols,
      cv.BORDER_CONSTANT,
      value: cv.Scalar.all(0),
    );

    final floatMat = padded.convertTo(cv.MatType.CV_32FC1);
    final zeros = cv.Mat.zeros(
      floatMat.rows,
      floatMat.cols,
      cv.MatType.CV_32FC1,
    );
    final complex = cv.merge(cv.VecMat.fromList([floatMat, zeros]));
    final dft = cv.dft(complex, flags: cv.DFT_COMPLEX_OUTPUT);
    final planes = cv.split(dft);

    final real = planes[0];
    final imag = planes[1];
    final magnitude = cv.magnitude(real, imag);
    final ones = cv.Mat.ones(
      magnitude.rows,
      magnitude.cols,
      cv.MatType.CV_32FC1,
    );
    final magPlus = cv.add(magnitude, ones);
    final magLog = cv.log(magPlus);
    final centered = options.fftShift ? _fftShift(magLog) : magLog.clone();
    final normalized = centered.convertTo(
      cv.MatType.CV_8UC1,
      alpha: 1.0,
      beta: 0.0,
    );
    cv.normalize(
      normalized,
      normalized,
      alpha: 0,
      beta: 255,
      normType: cv.NORM_MINMAX,
    );

    cv.Mat output;
    var nextDomain = VisionImageDomain.frequency;
    var label = options.fftShift
        ? 'Frequency Domain (FFT Shifted)'
        : 'Frequency Domain';

    if (activeDomain == VisionImageDomain.frequency && options.inverseDft) {
      final restored = cv.idft(dft, flags: cv.DFT_REAL_OUTPUT | cv.DFT_SCALE);
      cv.normalize(
        restored,
        restored,
        alpha: 0,
        beta: 255,
        normType: cv.NORM_MINMAX,
      );
      output = restored.convertTo(cv.MatType.CV_8UC1);
      restored.dispose();
      nextDomain = VisionImageDomain.spatial;
      label = 'Spatial Domain (Inverse DFT)';
    } else {
      output = normalized.clone();
    }

    final histogram = _buildHistogram(output);
    final metrics = _buildMetrics(output, histogram);
    final (ok, previewPng) = cv.imencode('.png', output);

    if (!ok) {
      throw Exception('Failed to encode frequency preview image');
    }

    padded.dispose();
    floatMat.dispose();
    zeros.dispose();
    complex.dispose();
    dft.dispose();
    real.dispose();
    imag.dispose();
    magnitude.dispose();
    ones.dispose();
    magPlus.dispose();
    magLog.dispose();
    centered.dispose();
    normalized.dispose();
    output.dispose();

    return PhotoPreviewResult(
      previewPng: previewPng,
      histogram: histogram,
      metrics: {
        ...metrics,
        'status': 'OpenCV Fourier analysis siap',
        'fftShift': options.fftShift,
      },
      modeLabel: label,
      activeDomain: nextDomain,
    );
  }

  cv.Mat _fftShift(cv.Mat src) {
    final cx = src.cols ~/ 2;
    final cy = src.rows ~/ 2;

    final q0 = src.rowRange(0, cy).colRange(0, cx);
    final q1 = src.rowRange(cy, src.rows).colRange(0, cx);
    final q2 = src.rowRange(0, cy).colRange(cx, src.cols);
    final q3 = src.rowRange(cy, src.rows).colRange(cx, src.cols);

    final top = cv.hconcat(q3, q1);
    final bottom = cv.hconcat(q2, q0);
    final shifted = cv.vconcat(top, bottom);

    q0.dispose();
    q1.dispose();
    q2.dispose();
    q3.dispose();
    top.dispose();
    bottom.dispose();

    return shifted;
  }

  List<int> _buildHistogram(cv.Mat mat) {
    final histogram = List<int>.filled(256, 0);
    final pixels = mat.data;

    for (final p in pixels) {
      final idx = p.clamp(0, 255).toInt();
      histogram[idx] += 1;
    }

    return histogram;
  }

  Map<String, dynamic> _buildMetrics(cv.Mat mat, List<int> histogram) {
    var luminanceSum = 0.0;
    var whitePixels = 0;
    var peakBin = 0;
    var peakValue = 0;

    for (var i = 0; i < histogram.length; i++) {
      final value = histogram[i];
      luminanceSum += i * value;

      if (i > 127) {
        whitePixels += value;
      }

      if (value > peakValue) {
        peakValue = value;
        peakBin = i;
      }
    }

    final pixelCount = histogram.fold<int>(0, (a, b) => a + b);

    return {
      'width': mat.cols,
      'height': mat.rows,
      'meanLuminance': pixelCount == 0 ? 0.0 : luminanceSum / pixelCount,
      'histogramPeakBin': peakBin,
      'histogramPeakValue': peakValue,
      'edgeDensity': pixelCount == 0 ? 0.0 : whitePixels / pixelCount,
    };
  }

  int _oddKernel(int value) {
    final normalized = value < 3 ? 3 : value;
    return normalized.isOdd ? normalized : normalized + 1;
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

/// Result object for captured-photo preview filters.
class PhotoPreviewResult {
  final Uint8List previewPng;
  final List<int> histogram;
  final Map<String, dynamic> metrics;
  final String modeLabel;
  final VisionImageDomain activeDomain;

  const PhotoPreviewResult({
    required this.previewPng,
    required this.histogram,
    required this.metrics,
    required this.modeLabel,
    required this.activeDomain,
  });
}

enum VisionImageDomain { spatial, frequency }

class VisionPipelineOptions {
  final double brightness;
  final double contrast;
  final bool histogramEqualization;
  final bool gaussianBlur;
  final int gaussianKernelSize;
  final bool sharpening;
  final bool edgeDetectionCanny;
  final double cannyThreshold1;
  final double cannyThreshold2;
  final bool thresholding;
  final double thresholdValue;
  final bool medianFilter;
  final int medianKernelSize;
  final bool gammaCorrection;
  final double gamma;
  final bool frequencyMagnitude;
  final bool fftShift;
  final bool inverseDft;

  const VisionPipelineOptions({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.histogramEqualization = false,
    this.gaussianBlur = false,
    this.gaussianKernelSize = 3,
    this.sharpening = false,
    this.edgeDetectionCanny = false,
    this.cannyThreshold1 = 80,
    this.cannyThreshold2 = 160,
    this.thresholding = false,
    this.thresholdValue = 120,
    this.medianFilter = false,
    this.medianKernelSize = 3,
    this.gammaCorrection = false,
    this.gamma = 1.0,
    this.frequencyMagnitude = false,
    this.fftShift = true,
    this.inverseDft = false,
  });
}

class _DomainValidation {
  final bool isValid;
  final String? message;

  const _DomainValidation({required this.isValid, this.message});
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
