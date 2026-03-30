import 'package:flutter/material.dart';
import '../models/connection_line.dart';

class ConnectionsPainter extends CustomPainter {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;
  final double dashFlowValue;
  final bool dimOnly;
  final int? hoveredPortNumber;
  final double hoverAnimationValue;
  final Set<int> selectedPorts;

  ConnectionsPainter({
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
    this.dashFlowValue = 0.0,
    this.dimOnly = false,
    this.hoveredPortNumber,
    this.hoverAnimationValue = 0.0,
    this.selectedPorts = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    for (final connection in connections) {
      final bool isActive =
          activePortNumber != null && connection.isHighlighted;
      final bool isDimmed = activePortNumber != null && !isActive;

      // Apply hover/selection offset to source to match port float animation
      ConnectionLine paintConn = connection;
      if (connection.portNumber != null) {
        double offsetY = 0;
        final double fullOffset =
            connection.portNumber!.isOdd ? -3.0 : 3.0;

        if (selectedPorts.contains(connection.portNumber)) {
          // Selected ports are always floated — full offset
          offsetY = fullOffset;
        } else if (connection.portNumber == hoveredPortNumber &&
            hoverAnimationValue > 0) {
          // Hovered (not selected) — animated offset
          offsetY = fullOffset * hoverAnimationValue;
        }

        if (offsetY != 0) {
          paintConn = ConnectionLine(
            sourceOffset: Offset(
                connection.sourceOffset.dx,
                connection.sourceOffset.dy + offsetY),
            targetOffset: connection.targetOffset,
            status: connection.status,
            isHighlighted: connection.isHighlighted,
            slotId: connection.slotId,
            portNumber: connection.portNumber,
            isConfig: connection.isConfig,
            curveDirection: connection.curveDirection,
            forceCurve: connection.forceCurve,
          );
        }
      }

      if (isDimmed) {
        canvas.saveLayer(
            null, Paint()..color = Colors.white.withValues(alpha: 0.1));
        paintConn.paint(canvas, animationValue: animationValue);
        canvas.restore();
      } else if (isActive && !dimOnly) {
        paintConn.paintSpotlit(canvas, dashFlowValue: dashFlowValue);
      } else {
        paintConn.paint(canvas, animationValue: animationValue);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.activePortNumber != activePortNumber ||
        oldDelegate.dashFlowValue != dashFlowValue ||
        oldDelegate.dimOnly != dimOnly ||
        oldDelegate.hoveredPortNumber != hoveredPortNumber ||
        oldDelegate.hoverAnimationValue != hoverAnimationValue ||
        oldDelegate.selectedPorts != selectedPorts;
  }
}

class ConnectionsLayer extends StatelessWidget {
  final List<ConnectionLine> connections;
  final double animationValue;
  final int? activePortNumber;
  final double dashFlowValue;
  final bool dimOnly;
  final int? hoveredPortNumber;
  final double hoverAnimationValue;
  final Set<int> selectedPorts;

  const ConnectionsLayer({
    super.key,
    required this.connections,
    this.animationValue = 0.0,
    this.activePortNumber,
    this.dashFlowValue = 0.0,
    this.dimOnly = false,
    this.hoveredPortNumber,
    this.hoverAnimationValue = 0.0,
    this.selectedPorts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ConnectionsPainter(
        connections: connections,
        animationValue: animationValue,
        activePortNumber: activePortNumber,
        dashFlowValue: dashFlowValue,
        dimOnly: dimOnly,
        hoveredPortNumber: hoveredPortNumber,
        hoverAnimationValue: hoverAnimationValue,
        selectedPorts: selectedPorts,
      ),
    );
  }
}
