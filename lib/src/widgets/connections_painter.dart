import 'package:flutter/material.dart';
import '../models/connection_line.dart';

class ConnectionsPainter extends CustomPainter {
  final List<ConnectionLine> connections;
  final double animationValue;

  ConnectionsPainter({
    required this.connections,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    for (final connection in connections) {
      connection.paint(canvas, animationValue: animationValue);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.animationValue != animationValue;
  }
}

class ConnectionsLayer extends StatelessWidget {
  final List<ConnectionLine> connections;
  final double animationValue;

  const ConnectionsLayer({
    super.key,
    required this.connections,
    this.animationValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ConnectionsPainter(
        connections: connections,
        animationValue: animationValue,
      ),
    );
  }
}
