import 'package:flutter/material.dart';
import '../models/connection_line.dart';

class ConnectionsPainter extends CustomPainter {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;

  ConnectionsPainter({
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    for (final connection in connections) {
      final bool isDimmed = activePortNumber != null &&
          connection.portNumber != activePortNumber;
      if (isDimmed) {
        canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.1));
        connection.paint(canvas, animationValue: animationValue);
        canvas.restore();
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
        oldDelegate.activePortNumber != activePortNumber;
  }
}

class ConnectionsLayer extends StatelessWidget {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;

  const ConnectionsLayer({
    super.key,
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ConnectionsPainter(
        connections: connections,
        animationValue: animationValue,
        activePortNumber: activePortNumber,
      ),
    );
  }
}
