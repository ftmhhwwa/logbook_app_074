import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'vision_controller.dart';

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
  bool _grayscale = false;
  bool _edgeDetect = false;

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
        brightness: _brightness,
        contrast: _contrast,
        grayscale: _grayscale,
        edgeDetect: _edgeDetect,
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
      });
    });
  }

  void _resetFilters() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _grayscale = false;
      _edgeDetect = false;
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
            color: Colors.black.withOpacity(0.12),
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
                  color: Colors.black.withOpacity(0.45),
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
                    color: Colors.black.withOpacity(0.6),
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
                    color: Colors.blueGrey.withOpacity(0.75),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (index) {
                  final value = bars[index];
                  final heightFactor = maxValue == 0 ? 0.0 : value / maxValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
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
                              colors: [Color(0xFF4F46E5), Color(0xFF38BDF8)],
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 12),
            _buildMetricRow(
              'Mean luminance',
              meanLuminance?.toStringAsFixed(2) ?? '-',
            ),
            _buildMetricRow('Peak bin', peakBin?.toString() ?? '-'),
            _buildMetricRow('Peak value', peakValue?.toString() ?? '-'),
            _buildMetricRow(
              'Edge density',
              edgeDensity != null ? edgeDensity.toStringAsFixed(4) : '-',
            ),
          ],
        ),
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 12),
            _buildSlider(
              label: 'Brightness',
              value: _brightness,
              min: -1.0,
              max: 1.0,
              divisions: 20,
              valueText: _brightness.toStringAsFixed(2),
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
              onChanged: (value) {
                setState(() => _contrast = value);
                _schedulePreviewRefresh();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _grayscale,
              title: const Text('Grayscale'),
              subtitle: const Text('Ubah tampilan menjadi abu-abu'),
              onChanged: (value) {
                setState(() => _grayscale = value);
                _schedulePreviewRefresh();
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _edgeDetect,
              title: const Text('Edge Detect'),
              subtitle: const Text('Tampilkan tepi objek / kerusakan'),
              onChanged: (value) {
                setState(() => _edgeDetect = value);
                _schedulePreviewRefresh();
              },
            ),
          ],
        ),
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
          onChanged: onChanged,
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPreviewArea(),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
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
              const SizedBox(height: 16),
            ],
            _buildControlsCard(),
            const SizedBox(height: 16),
            _buildHistogramCard(),
            const SizedBox(height: 16),
            _buildMetricsCard(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Kembali ke Kamera'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
