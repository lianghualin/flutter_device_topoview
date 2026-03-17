import 'package:flutter/material.dart';
import '../models/connection_line.dart';

class ConnectionsPainter extends CustomPainter {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;
  final double dashFlowValue;

  ConnectionsPainter({
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
    this.dashFlowValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    for (final connection in connections) {
      final bool isActive = activePortNumber != null &&
          connection.portNumber == activePortNumber;
      final bool isDimmed = activePortNumber != null && !isActive;

      if (isDimmed) {
        // Smooth dim: paint at low opacity
        canvas.saveLayer(
            null, Paint()..color = Colors.white.withValues(alpha: 0.1));
        connection.paint(canvas, animationValue: animationValue);
        canvas.restore();
      } else if (isActive) {
        // Spotlight: paint with flowing dash animation
        connection.paintSpotlit(canvas, dashFlowValue: dashFlowValue);
      } else {
        connection.paint(canvas, animationValue: animationValue);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.activePortNumber != activePortNumber ||
        oldDelegate.dashFlowValue != dashFlowValue;
  }
}

class ConnectionsLayer extends StatelessWidget {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;
  final double dashFlowValue;

  const ConnectionsLayer({
    super.key,
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
    this.dashFlowValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ConnectionsPainter(
        connections: connections,
        animationValue: animationValue,
        activePortNumber: activePortNumber,
        dashFlowValue: dashFlowValue,
      ),
    );
  }
}
