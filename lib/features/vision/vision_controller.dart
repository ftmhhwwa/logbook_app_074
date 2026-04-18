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

    // Check if any spatial operations are enabled
    final hasSpatialOperations = _hasSpatialOperations(options);

    // If no spatial operations and not requesting frequency, return the original color image
    final wantsFrequency =
        activeDomain == VisionImageDomain.frequency ||
        options.frequencyMagnitude;

    if (!hasSpatialOperations && !wantsFrequency) {
      final histogram = _buildHistogram(src);
      final metrics = _buildMetrics(src, histogram);
      final (ok, previewPng) = cv.imencode('.png', src);

      if (!ok) {
        throw Exception('Failed to encode original image');
      }

      src.dispose();

      return PhotoPreviewResult(
        previewPng: previewPng,
        histogram: histogram,
        metrics: {...metrics, 'status': 'Foto asli (belum ada filter)'},
        modeLabel: 'Original Color',
        activeDomain: VisionImageDomain.spatial,
      );
    }

    // Convert to grayscale for processing
    cv.Mat gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    if (activeDomain == VisionImageDomain.spatial && hasSpatialOperations) {
      gray = _applySpatialPipeline(gray, options);
    }

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

  /// Check if any spatial operations are enabled
  bool _hasSpatialOperations(VisionPipelineOptions options) {
    return options.brightness.abs() > 0.001 ||
        (options.contrast - 1.0).abs() > 0.001 ||
        options.histogramEqualization ||
        options.gaussianBlur ||
        options.sharpening ||
        options.edgeDetectionCanny ||
        options.thresholding ||
        options.medianFilter ||
        options.gammaCorrection;
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

/// Dedicated preview page for captured photos with interactive PCD filters.
class VisionPreviewPage extends StatefulWidget {
  final VisionController controller;
  final XFile capturedImage;

  const VisionPreviewPage({
    super.key,
    required this.controller,
    required this.capturedImage,
  });

  @override
  State<VisionPreviewPage> createState() => _VisionPreviewPageState();
}

class _VisionPreviewPageState extends State<VisionPreviewPage> {
  double _brightness = 0.0;
  double _contrast = 1.0;
  bool _histogramEqualization = false;
  bool _gaussianBlur = false;
  int _gaussianKernelSize = 3;
  bool _sharpening = false;
  bool _edgeDetect = false;
  double _cannyThreshold1 = 80;
  double _cannyThreshold2 = 160;
  bool _thresholding = false;
  double _thresholdValue = 120;
  bool _medianFilter = false;
  int _medianKernelSize = 3;
  bool _gammaCorrection = false;
  double _gamma = 1.0;
  bool _fftShift = true;
  VisionImageDomain _activeDomain = VisionImageDomain.spatial;

  Uint8List? _previewBytes;
  Uint8List? _originalBytes;
  List<int> _histogram = List<int>.filled(256, 0);
  Map<String, dynamic> _metrics = const {};
  String _modeLabel = 'Preview';
  bool _isProcessing = true;
  String? _error;

  Timer? _debounceTimer;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadOriginalPhoto();
    _schedulePreviewRefresh(immediate: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOriginalPhoto() async {
    try {
      final bytes = await widget.capturedImage.readAsBytes();
      if (!mounted) return;
      setState(() {
        _originalBytes = bytes;
      });
    } catch (_) {
      // Keep preview page usable even if the original bytes cannot be read.
    }
  }

  void _schedulePreviewRefresh({bool immediate = false}) {
    _debounceTimer?.cancel();
    final version = ++_requestVersion;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final delay = immediate ? Duration.zero : const Duration(milliseconds: 180);

    _debounceTimer = Timer(delay, () async {
      final result = await widget.controller.buildInteractivePreview(
        widget.capturedImage,
        activeDomain: _activeDomain,
        options: VisionPipelineOptions(
          brightness: _brightness,
          contrast: _contrast,
          histogramEqualization: _histogramEqualization,
          gaussianBlur: _gaussianBlur,
          gaussianKernelSize: _gaussianKernelSize,
          sharpening: _sharpening,
          edgeDetectionCanny: _edgeDetect,
          cannyThreshold1: _cannyThreshold1,
          cannyThreshold2: _cannyThreshold2,
          thresholding: _thresholding,
          thresholdValue: _thresholdValue,
          medianFilter: _medianFilter,
          medianKernelSize: _medianKernelSize,
          gammaCorrection: _gammaCorrection,
          gamma: _gamma,
          frequencyMagnitude: _activeDomain == VisionImageDomain.frequency,
          fftShift: _fftShift,
          inverseDft: false,
        ),
      );

      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _isProcessing = false;
        if (result == null) {
          _error = widget.controller.errorMessage ?? 'Gagal memproses preview';
          return;
        }

        _previewBytes = result.previewPng;
        _histogram = result.histogram;
        _metrics = result.metrics;
        _modeLabel = result.modeLabel;
        _activeDomain = result.activeDomain;
      });
    });
  }

  Future<void> _transformToFrequencyDomain() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final result = await widget.controller.buildInteractivePreview(
      widget.capturedImage,
      activeDomain: VisionImageDomain.spatial,
      options: VisionPipelineOptions(
        brightness: _brightness,
        contrast: _contrast,
        histogramEqualization: _histogramEqualization,
        gaussianBlur: _gaussianBlur,
        gaussianKernelSize: _gaussianKernelSize,
        sharpening: _sharpening,
        edgeDetectionCanny: _edgeDetect,
        cannyThreshold1: _cannyThreshold1,
        cannyThreshold2: _cannyThreshold2,
        thresholding: _thresholding,
        thresholdValue: _thresholdValue,
        medianFilter: _medianFilter,
        medianKernelSize: _medianKernelSize,
        gammaCorrection: _gammaCorrection,
        gamma: _gamma,
        frequencyMagnitude: true,
        fftShift: _fftShift,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      if (result == null) {
        _error =
            widget.controller.errorMessage ??
            'Gagal mengubah domain ke frequency';
        return;
      }

      _previewBytes = result.previewPng;
      _histogram = result.histogram;
      _metrics = result.metrics;
      _modeLabel = result.modeLabel;
      _activeDomain = result.activeDomain;
    });
  }

  Future<void> _inverseDftToSpatial() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final result = await widget.controller.buildInteractivePreview(
      widget.capturedImage,
      activeDomain: VisionImageDomain.frequency,
      options: VisionPipelineOptions(
        fftShift: _fftShift,
        frequencyMagnitude: true,
        inverseDft: true,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      if (result == null) {
        _error =
            widget.controller.errorMessage ?? 'Gagal melakukan inverse DFT';
        return;
      }

      _previewBytes = result.previewPng;
      _histogram = result.histogram;
      _metrics = result.metrics;
      _modeLabel = result.modeLabel;
      _activeDomain = result.activeDomain;
    });
  }

  void _resetFilters() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _histogramEqualization = false;
      _gaussianBlur = false;
      _gaussianKernelSize = 3;
      _sharpening = false;
      _edgeDetect = false;
      _cannyThreshold1 = 80;
      _cannyThreshold2 = 160;
      _thresholding = false;
      _thresholdValue = 120;
      _medianFilter = false;
      _medianKernelSize = 3;
      _gammaCorrection = false;
      _gamma = 1.0;
      _fftShift = true;
      _activeDomain = VisionImageDomain.spatial;
    });
    _schedulePreviewRefresh();
  }

  List<int> _compressHistogram(List<int> source, int targetBins) {
    if (source.isEmpty || targetBins <= 0) {
      return List<int>.filled(targetBins, 0);
    }

    final result = List<int>.filled(targetBins, 0);
    final step = source.length / targetBins;

    for (var i = 0; i < targetBins; i++) {
      final start = (i * step).floor();
      final end = (((i + 1) * step).ceil()).clamp(0, source.length);
      var total = 0;
      for (var j = start; j < end; j++) {
        total += source[j];
      }
      result[i] = total;
    }

    return result;
  }

  Widget _buildPreviewArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_previewBytes != null)
                Image.memory(
                  _previewBytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              else if (_originalBytes != null)
                Image.memory(
                  _originalBytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              else
                Container(color: Colors.black),
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _modeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PCD Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistogramCard() {
    final bars = _compressHistogram(_histogram, 32);
    final maxValue = bars.isEmpty ? 1 : bars.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Histogram',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(bars.length, (index) {
                          final value = bars[index];
                          final heightFactor = maxValue == 0
                              ? 0.0
                              : value / maxValue;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              child: Container(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 92 * heightFactor,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF4F46E5),
                                        Color(0xFF38BDF8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Semakin tinggi batang, semakin banyak piksel pada intensitas tersebut.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    final meanLuminance = (_metrics['meanLuminance'] as num?)?.toDouble();
    final peakBin = _metrics['histogramPeakBin'];
    final peakValue = _metrics['histogramPeakValue'];
    final edgeDensity = (_metrics['edgeDensity'] as num?)?.toDouble();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'PCD Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricRow(
                      'Mean luminance',
                      meanLuminance?.toStringAsFixed(2) ?? '-',
                    ),
                    _buildMetricRow('Peak bin', peakBin?.toString() ?? '-'),
                    _buildMetricRow('Peak value', peakValue?.toString() ?? '-'),
                    _buildMetricRow(
                      'Edge density',
                      edgeDensity != null
                          ? edgeDensity.toStringAsFixed(4)
                          : '-',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    final isSpatialDomain = _activeDomain == VisionImageDomain.spatial;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          // Header (non-scrollable)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Filter Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InputChip(
                          selected: _activeDomain == VisionImageDomain.spatial,
                          label: const Text('Spatial Domain'),
                          onSelected: (_) {
                            setState(
                              () => _activeDomain = VisionImageDomain.spatial,
                            );
                            _schedulePreviewRefresh(immediate: true);
                          },
                        ),
                        InputChip(
                          selected:
                              _activeDomain == VisionImageDomain.frequency,
                          label: const Text('Frequency Domain'),
                          onSelected: (_) => _transformToFrequencyDomain(),
                        ),
                        if (_activeDomain == VisionImageDomain.frequency)
                          ActionChip(
                            avatar: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Inverse DFT'),
                            onPressed: _inverseDftToSpatial,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: 'Brightness',
                      value: _brightness,
                      min: -1.0,
                      max: 1.0,
                      divisions: 20,
                      valueText: _brightness.toStringAsFixed(2),
                      enabled: isSpatialDomain,
                      onChanged: (value) {
                        setState(() => _brightness = value);
                        _schedulePreviewRefresh();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSlider(
                      label: 'Contrast',
                      value: _contrast,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      valueText: _contrast.toStringAsFixed(2),
                      enabled: isSpatialDomain,
                      onChanged: (value) {
                        setState(() => _contrast = value);
                        _schedulePreviewRefresh();
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _histogramEqualization,
                      title: const Text('Histogram Equalization'),
                      subtitle: const Text(
                        'Tingkatkan kontras global grayscale',
                      ),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _histogramEqualization = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _gaussianBlur,
                      title: const Text('Gaussian Blur'),
                      subtitle: const Text(
                        'Peredam noise berbasis kernel gaussian',
                      ),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _gaussianBlur = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    if (_gaussianBlur)
                      _buildSlider(
                        label: 'Gaussian Kernel',
                        value: _gaussianKernelSize.toDouble(),
                        min: 3,
                        max: 11,
                        divisions: 4,
                        valueText: _gaussianKernelSize.toString(),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _gaussianKernelSize = value.round());
                          _schedulePreviewRefresh();
                        },
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _sharpening,
                      title: const Text('Sharpening'),
                      subtitle: const Text(
                        'Menonjolkan detail tepi menggunakan kernel',
                      ),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _sharpening = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _edgeDetect,
                      title: const Text('Edge Detection (Canny)'),
                      subtitle: const Text('Deteksi tepi objek dengan Canny'),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _edgeDetect = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    if (_edgeDetect) ...[
                      _buildSlider(
                        label: 'Canny Threshold 1',
                        value: _cannyThreshold1,
                        min: 0,
                        max: 255,
                        divisions: 51,
                        valueText: _cannyThreshold1.toStringAsFixed(0),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _cannyThreshold1 = value);
                          _schedulePreviewRefresh();
                        },
                      ),
                      _buildSlider(
                        label: 'Canny Threshold 2',
                        value: _cannyThreshold2,
                        min: 0,
                        max: 255,
                        divisions: 51,
                        valueText: _cannyThreshold2.toStringAsFixed(0),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _cannyThreshold2 = value);
                          _schedulePreviewRefresh();
                        },
                      ),
                    ],
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _thresholding,
                      title: const Text('Thresholding'),
                      subtitle: const Text(
                        'Segmentasi biner berdasarkan intensitas',
                      ),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _thresholding = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    if (_thresholding)
                      _buildSlider(
                        label: 'Threshold Value',
                        value: _thresholdValue,
                        min: 0,
                        max: 255,
                        divisions: 51,
                        valueText: _thresholdValue.toStringAsFixed(0),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _thresholdValue = value);
                          _schedulePreviewRefresh();
                        },
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _medianFilter,
                      title: const Text('Median Filter'),
                      subtitle: const Text('Mengurangi noise salt-and-pepper'),
                      onChanged: isSpatialDomain
                          ? (value) {
                              setState(() => _medianFilter = value);
                              _schedulePreviewRefresh();
                            }
                          : null,
                    ),
                    if (_medianFilter)
                      _buildSlider(
                        label: 'Median Kernel',
                        value: _medianKernelSize.toDouble(),
                        min: 3,
                        max: 11,
                        divisions: 4,
                        valueText: _medianKernelSize.toString(),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _medianKernelSize = value.round());
                          _schedulePreviewRefresh();
                        },
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _gammaCorrection,
                      title: const Text('Gamma Correction'),
                      subtitle: const Text(
                        'Koreksi nonlinear pencahayaan gambar',
                      ),
                      onChanged: (value) {
                        if (!isSpatialDomain) return;
                        setState(() => _gammaCorrection = value);
                        _schedulePreviewRefresh();
                      },
                    ),
                    if (_gammaCorrection)
                      _buildSlider(
                        label: 'Gamma',
                        value: _gamma,
                        min: 0.2,
                        max: 3.0,
                        divisions: 28,
                        valueText: _gamma.toStringAsFixed(2),
                        enabled: isSpatialDomain,
                        onChanged: (value) {
                          setState(() => _gamma = value);
                          _schedulePreviewRefresh();
                        },
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _fftShift,
                      title: const Text('FFT Shift (DC Centering)'),
                      subtitle: const Text(
                        'Pusatkan komponen DC pada visualisasi spektrum',
                      ),
                      onChanged: (value) {
                        setState(() => _fftShift = value);
                        if (_activeDomain == VisionImageDomain.frequency) {
                          _transformToFrequencyDomain();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueText,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(valueText, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Preview Foto PCD'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview area (top, non-scrollable)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPreviewArea(),
            ),

            // Error message
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Horizontal scrollable cards section (bottom, scrollable)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(width: 380, child: _buildControlsCard()),
                    const SizedBox(width: 16),
                    SizedBox(width: 340, child: _buildHistogramCard()),
                    const SizedBox(width: 16),
                    SizedBox(width: 300, child: _buildMetricsCard()),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            // Back button (bottom)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Kembali ke Kamera'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
