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

  const ConnectionLine({
    required this.sourceOffset,
    required this.targetOffset,
    required this.status,
    this.isHighlighted = false,
    this.slotId,
    this.portNumber,
    this.isConfig = false,
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
    } else {
      path.lineTo(targetOffset.dx, targetOffset.dy);
    }

    if (isConfig) {
      paint
        ..color = Colors.grey
        ..strokeWidth = isHighlighted ? 4 : 2;
      if (status == 0) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
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

  static void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 5, double spaceLength = 5}) {
    PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      while (distance < pathMetric.length) {
        double nextDistance = distance + (draw ? dashLength : spaceLength);
        if (nextDistance > pathMetric.length) {
          nextDistance = pathMetric.length;
        }
        if (draw) {
          Path dashPath = pathMetric.extractPath(distance, nextDistance);
          canvas.drawPath(dashPath, paint);
        }
        distance = nextDistance;
        draw = !draw;
      }
    }
  }
}
