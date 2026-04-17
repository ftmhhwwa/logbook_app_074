import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'vision_controller.dart';

/// DamagePainter implements custom painting for road damage detection
///
/// This follows Single Responsibility Principle:
/// - Only handles drawing logic
/// - Receives detection results from VisionController
/// - Doesn't manage camera or state
///
/// Can be extended in Module 7 for YOLO integration
class DamagePainter extends CustomPainter {
  // ============ RIGID SCALING CONSTANTS ============
  /// Coordinate scaling factor: normalized (0.0-1.0) to logical pixels.
  static const double scalingFactorX = 1.0;
  static const double scalingFactorY = 1.0;

  // ============ PRECISE RENDERING CONSTANTS ============
  static const double staticCrosshairLength = 50.0;
  static const double staticCrosshairCircleRadius = 30.0;
  static const double dynamicCrosshairCircleRadius = 2.5;

  static const double boxStrokeWidth = 3.0;
  static const double boxShadowBlur = 3.0;
  static const double labelFontSize = 14.0;
  static const double labelPadding = 4.0;
  static const double labelBorderRadius = 4.0;
  static const double labelBackgroundOpacity = 0.4;
  static const double labelBorderStrokeWidth = 1.5;

  // ============ MOBILE VIEWPORT SAFETY ============
  /// Minimum margin to prevent edge clipping on small screens.
  static const double viewportMarginPercent = 0.05;

  final List<DetectionResult> results;
  final Map<String, dynamic>? pcdMetrics;

  DamagePainter(this.results, {this.pcdMetrics});

  @override
  void paint(Canvas canvas, Size size) {
    // Clip canvas to screen boundaries - prevent elements from going off-screen on mobile
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawPcdStatusPanel(canvas, size);

    // If no detections, draw static crosshair (Phase 4 requirement)
    if (results.isEmpty) {
      _drawStaticCrosshair(canvas, size);
      return;
    }

    // Draw each detection result
    for (var result in results) {
      _drawDetectionBox(canvas, size, result);
    }
  }

  void _drawPcdStatusPanel(Canvas canvas, Size size) {
    final metrics = pcdMetrics;
    if (metrics == null) return;

    final mean = (metrics['meanLuminance'] as num?)?.toDouble();
    final edge = (metrics['edgeDensity'] as num?)?.toDouble();
    final peak = metrics['histogramPeakBin'];

    final info =
        'PCD mean:${mean?.toStringAsFixed(1) ?? '-'}  '
        'edge:${edge == null ? '-' : '${(edge * 100).toStringAsFixed(1)}%'}  '
        'peak:${peak ?? '-'}';

    final textPainter = TextPainter(
      text: TextSpan(
        text: info,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);

    const panelPadding = 8.0;
    const panelTop = 12.0;
    const panelLeft = 12.0;

    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        panelLeft,
        panelTop,
        textPainter.width + panelPadding * 2,
        textPainter.height + panelPadding * 2,
      ),
      const Radius.circular(8),
    );

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final borderPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(panelRect, bgPaint);
    canvas.drawRRect(panelRect, borderPaint);
    textPainter.paint(
      canvas,
      const Offset(panelLeft + panelPadding, panelTop + panelPadding),
    );
  }

  /// Draw static crosshair as visual anchor
  /// This provides user guidance for targeting road damage objects
  void _drawStaticCrosshair(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal line
    canvas.drawLine(
      Offset(centerX - staticCrosshairLength, centerY),
      Offset(centerX + staticCrosshairLength, centerY),
      paint,
    );

    // Draw vertical line
    canvas.drawLine(
      Offset(centerX, centerY - staticCrosshairLength),
      Offset(centerX, centerY + staticCrosshairLength),
      paint,
    );

    // Draw circle in center
    canvas.drawCircle(
      Offset(centerX, centerY),
      staticCrosshairCircleRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Draw label
    _drawLabel(
      canvas,
      Rect.fromCircle(
        center: Offset(
          centerX - (staticCrosshairLength + 20),
          centerY - staticCrosshairLength,
        ),
        radius: staticCrosshairCircleRadius,
      ),
      "Searching for Road Damage...",
      1.0,
    );
  }

  /// Draw detection bounding box with label
  ///
  /// Implements coordinate scaling and boundary constraints:
  /// - Normalized coordinates (0.0-1.0) from AI
  /// - Scaled to logical pixels on screen
  /// - Constrained within viewport for mobile UX
  void _drawDetectionBox(Canvas canvas, Size size, DetectionResult result) {
    // RIGID SCALING: normalized coordinates -> logical pixels.
    var box = Rect.fromLTWH(
      result.box.left * size.width * scalingFactorX,
      result.box.top * size.height * scalingFactorY,
      result.box.width * size.width * scalingFactorX,
      result.box.height * size.height * scalingFactorY,
    );

    // Keep rendering inside a safe viewport margin.
    final marginX = size.width * viewportMarginPercent;
    final marginY = size.height * viewportMarginPercent;
    final screenBounds = Rect.fromLTWH(
      marginX,
      marginY,
      size.width - (marginX * 2),
      size.height - (marginY * 2),
    );
    box = box.intersect(screenBounds);

    // Skip rendering if box is completely outside bounds
    if (box.isEmpty) {
      return;
    }

    // Get color based on damage severity
    final boxColor = _getColorForDamage(result.label);

    // Draw bounding box
    final paint = Paint()
      ..color = boxColor
      ..strokeWidth = boxStrokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(box, paint);

    // Draw shadow for better visibility
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        boxShadowBlur,
      );

    canvas.drawRect(box, shadowPaint);

    // Redraw box on top of shadow
    canvas.drawRect(box, paint);

    // Draw simple crosshair in the center of detection box
    _drawSimpleCrosshair(canvas, box, boxColor);

    // Draw label
    _drawLabel(canvas, box, result.label, result.score);
  }

  /// Draw a minimal crosshair at the center of a detection box.
  void _drawSimpleCrosshair(Canvas canvas, Rect box, Color color) {
    final center = box.center;
    final lineLength = box.shortestSide * 0.12;

    final crosshairPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - lineLength, center.dy),
      Offset(center.dx + lineLength, center.dy),
      crosshairPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - lineLength),
      Offset(center.dx, center.dy + lineLength),
      crosshairPaint,
    );

    canvas.drawCircle(
      center,
      dynamicCrosshairCircleRadius,
      Paint()..color = color,
    );
  }

  /// Draw detection label above bounding box with enhanced readability
  ///
  /// Implements smart positioning and strong shadow/stroke effects:
  /// - Draws above box by default
  /// - Moves below box if label would go off-screen
  /// - Adds multi-layer shadow for stroke-like effect
  /// - Colors match damage severity
  void _drawLabel(Canvas canvas, Rect box, String label, double score) {
    // Get severity-based color for label text
    final labelColor = _getColorForDamage(label);

    // Main label text style
    final textSpan = TextSpan(
      text: ' $label - ${(score * 100).toInt()}% ',
      style: TextStyle(
        color: Colors.white,
        fontSize: labelFontSize,
        fontWeight: FontWeight.bold,
        backgroundColor: labelColor.withOpacity(0.85),
      ),
    );

    // PRECISE RENDERING: TextPainter provides exact text dimensions
    // Layout() calculates width/height based on constraints
    // paint() renders at exact offset with no rounding errors
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Calculate label position
    double labelY = box.top - 25;

    // Smart positioning: if label would go off-screen, move below box
    if (labelY < 0) {
      labelY = box.bottom + 5;
    }

    final labelOffset = Offset(box.left, labelY);

    // Draw multi-layer shadow/stroke effect for better readability
    // This creates a stroke outline appearance
    final shadowOffsets = [
      const Offset(-1, -1),
      const Offset(1, -1),
      const Offset(-1, 1),
      const Offset(1, 1),
      const Offset(0, -1.5),
      const Offset(0, 1.5),
    ];

    // Draw shadow outlines (stroke effect)
    for (final offset in shadowOffsets) {
      final shadowSpan = TextSpan(
        text: ' $label - ${(score * 100).toInt()}% ',
        style: TextStyle(
          color: Colors.black.withOpacity(0.6),
          fontSize: labelFontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.15),
        ),
      );

      final shadowPainter = TextPainter(
        text: shadowSpan,
        textDirection: TextDirection.ltr,
      );

      shadowPainter.layout();
      shadowPainter.paint(canvas, labelOffset + offset);
    }

    // Draw dark background for contrast
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(labelBackgroundOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - labelPadding,
          labelOffset.dy - labelPadding / 2,
          textPainter.width + (labelPadding * 2),
          textPainter.height + labelPadding,
        ),
        Radius.circular(labelBorderRadius),
      ),
      backgroundPaint,
    );

    // Draw main text with severity color background
    textPainter.paint(canvas, labelOffset);

    // Optional: Draw a colored border around label for extra emphasis
    final borderPaint = Paint()
      ..color = labelColor
      ..strokeWidth = labelBorderStrokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - labelPadding,
          labelOffset.dy - labelPadding / 2,
          textPainter.width + (labelPadding * 2),
          textPainter.height + labelPadding,
        ),
        Radius.circular(labelBorderRadius),
      ),
      borderPaint,
    );
  }

  /// Get color based on damage severity
  ///
  /// RDD-2022 Dataset Classification:
  /// - D40 (Pothole): Severe - Red
  /// - D20 (Alligator Crack): High - Orange
  /// - D10 (Transverse Crack): Medium - Yellow
  /// - D00 (Longitudinal Crack): Minor - Green
  Color _getColorForDamage(String label) {
    if (label.contains('D40')) return Colors.red; // Pothole - Severe
    if (label.contains('D20')) return Colors.orange; // Alligator - High
    if (label.contains('D10')) return Colors.yellow; // Transverse - Medium
    return Colors.green; // Longitudinal - Minor
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! DamagePainter) return true;
    return oldDelegate.results != results ||
        oldDelegate.pcdMetrics != pcdMetrics;
  }
}
