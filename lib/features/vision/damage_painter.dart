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
  final List<DetectionResult> results;

  DamagePainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    // Clip canvas to screen boundaries - prevent elements from going off-screen on mobile
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

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
      Offset(centerX - 50, centerY),
      Offset(centerX + 50, centerY),
      paint,
    );

    // Draw vertical line
    canvas.drawLine(
      Offset(centerX, centerY - 50),
      Offset(centerX, centerY + 50),
      paint,
    );

    // Draw circle in center
    canvas.drawCircle(
      Offset(centerX, centerY),
      30,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Draw label
    _drawLabel(
      canvas,
      Rect.fromCircle(center: Offset(centerX - 70, centerY - 50), radius: 30),
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
    // Scale normalized coordinates to screen pixels
    var box = Rect.fromLTWH(
      result.box.left * size.width,
      result.box.top * size.height,
      result.box.width * size.width,
      result.box.height * size.height,
    );

    // Constrain box within screen boundaries (mobile-safe clipping)
    final screenBounds = Rect.fromLTWH(0, 0, size.width, size.height);
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
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(box, paint);

    // Draw shadow for better visibility
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);

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
      2.5,
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
        fontSize: 14,
        fontWeight: FontWeight.bold,
        backgroundColor: labelColor.withOpacity(0.85),
      ),
    );

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
          fontSize: 14,
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
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      ),
      backgroundPaint,
    );

    // Draw main text with severity color background
    textPainter.paint(canvas, labelOffset);

    // Optional: Draw a colored border around label for extra emphasis
    final borderPaint = Paint()
      ..color = labelColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
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
    // Repaint when detections change
    // In Phase 5, this will be true for dynamic updates
    return true;
  }
}