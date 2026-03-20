import 'package:flutter/material.dart';
import 'dart:ui';

class ConnectionLine {
  final Offset sourceOffset;
  final Offset targetOffset;
  final int status;
  final bool isHighlighted;
  final String? slotId;
  final int? portNumber;
  final bool isConfig;
  final int curveDirection;
  final bool forceCurve;

  const ConnectionLine({
    required this.sourceOffset,
    required this.targetOffset,
    required this.status,
    this.isHighlighted = false,
    this.slotId,
    this.portNumber,
    this.isConfig = false,
    this.curveDirection = 1,
    this.forceCurve = false,
  });

  void paint(Canvas canvas, {double animationValue = 0.0}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    Path path = Path();
    path.moveTo(sourceOffset.dx, sourceOffset.dy);

    if (isHighlighted && portNumber != null && animationValue > 0) {
      final midX = (sourceOffset.dx + targetOffset.dx) / 2;
      final midY = (sourceOffset.dy + targetOffset.dy) / 2;
      final offset = (portNumber! % 2 == 0 ? 10.0 : -10.0) * animationValue;
      path.quadraticBezierTo(midX + offset, midY, targetOffset.dx, targetOffset.dy);
    } else if (forceCurve) {
      // Curved line (outer ring): perpendicular to the straight path
      final midX = (sourceOffset.dx + targetOffset.dx) / 2;
      final midY = (sourceOffset.dy + targetOffset.dy) / 2;
      final dx = targetOffset.dx - sourceOffset.dx;
      final dy = targetOffset.dy - sourceOffset.dy;
      // Perpendicular offset (15% of line length), direction controllable
      final perpX = -dy * 0.15 * curveDirection;
      final perpY = dx * 0.15 * curveDirection;
      path.quadraticBezierTo(
          midX + perpX, midY + perpY, targetOffset.dx, targetOffset.dy);
    } else {
      path.lineTo(targetOffset.dx, targetOffset.dy);
    }

    if (isConfig) {
      paint
        ..color = Colors.grey
        ..strokeWidth = isHighlighted ? 4 : 2;
      _drawDashedPath(canvas, path, paint);
      return;
    }

    switch (status) {
      case 0:
        paint
          ..color = Colors.black
          ..strokeWidth = isHighlighted ? 4 : 2;
        _drawDashedPath(canvas, path, paint);
        break;
      case 1:
        paint
          ..color = Colors.green
          ..strokeWidth = isHighlighted ? 6 : 3;
        canvas.drawPath(path, paint);
        break;
      case -1:
        paint
          ..color = Colors.red
          ..strokeWidth = isHighlighted ? 4 : 3;
        canvas.drawPath(path, paint);
        if (!isHighlighted) {
          final shadowPaint = Paint()
            ..color = Colors.red.withValues(alpha: 0.3)
            ..strokeWidth = 5
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, shadowPaint);
        }
        break;
    }
  }

  /// Paint with spotlight effect: flowing dashes and glow.
  void paintSpotlit(Canvas canvas, {double dashFlowValue = 0.0}) {
    final Color lineColor = status == -1 ? Colors.red : Colors.green;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = lineColor;

    Path path = Path();
    path.moveTo(sourceOffset.dx, sourceOffset.dy);

    if (forceCurve) {
      // Curved line (outer ring)
      final midX = (sourceOffset.dx + targetOffset.dx) / 2;
      final midY = (sourceOffset.dy + targetOffset.dy) / 2;
      final dx = targetOffset.dx - sourceOffset.dx;
      final dy = targetOffset.dy - sourceOffset.dy;
      final perpX = -dy * 0.15 * curveDirection;
      final perpY = dx * 0.15 * curveDirection;
      path.quadraticBezierTo(
          midX + perpX, midY + perpY, targetOffset.dx, targetOffset.dy);
    } else {
      path.lineTo(targetOffset.dx, targetOffset.dy);
    }

    // Outer glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = lineColor.withValues(alpha: 0.15);
    canvas.drawPath(path, glowPaint);

    // Flowing dashes
    const double dashLen = 10;
    const double spaceLen = 6;
    final double totalDash = dashLen + spaceLen;
    final double offset = dashFlowValue * totalDash;

    _drawFlowingDashedPath(canvas, path, paint,
        dashLength: dashLen, spaceLength: spaceLen, flowOffset: offset);
  }

  static void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 5, double spaceLength = 5}) {
    _drawFlowingDashedPath(canvas, path, paint,
        dashLength: dashLength, spaceLength: spaceLength, flowOffset: 0);
  }

  static void _drawFlowingDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 5,
      double spaceLength = 5,
      double flowOffset = 0}) {
    PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = flowOffset % (dashLength + spaceLength);
      bool draw = true;
      while (distance < pathMetric.length) {
        double nextDistance = distance + (draw ? dashLength : spaceLength);
        if (nextDistance > pathMetric.length) {
          nextDistance = pathMetric.length;
        }
        if (draw && distance >= 0) {
          Path dashPath = pathMetric.extractPath(
              distance.clamp(0, pathMetric.length), nextDistance);
          canvas.drawPath(dashPath, paint);
        }
        distance = nextDistance;
        draw = !draw;
      }
    }
  }
}
