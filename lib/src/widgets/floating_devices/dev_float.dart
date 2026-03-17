import 'dart:math' as math;

import 'package:flutter/material.dart';

// Callback for external device selection
typedef DeviceSelectedCallback = void Function(
    String deviceName, String deviceType, int? connectedPortNum);

/// Base class for floating devices in the network topology
abstract class DevFloat {
  final Offset position;
  final String label;
  final int portstatus;
  final double size;
  final int connectedPortNum;
  bool isHighlighted;
  final String deviceType;
  final bool deviceStatus;
  final String? deviceIp;
  final String portId;
  final double? utilization;
  final bool isRealDevice;

  DevFloat({
    required this.position,
    required this.label,
    required this.portstatus,
    this.size = 100.0,
    required this.connectedPortNum,
    this.isHighlighted = false,
    required this.deviceType,
    required this.deviceStatus,
    this.deviceIp,
    this.portId = '',
    this.utilization,
    this.isRealDevice = false,
  });

  /// Create the corresponding widget
  Widget createWidget({
    double top = 0,
    double left = 0,
    int? selectedDeviceId,
    Function(int)? onDeviceSelected,
    Function({int? deviceToKeepHighlighted})? onClearPortHighlight,
    DeviceSelectedCallback? onDeviceTapped,
    double? dimOpacity,
    bool enableAnimations = true,
  });

  /// Unique device ID based on connected port number
  int get deviceId => connectedPortNum;
}

/// Base widget class for floating devices
abstract class DevFloatWidget extends StatefulWidget {
  final String label;
  final int portstatus;
  final double size;
  final double top;
  final double left;
  final bool isHighlighted;
  final int deviceId;
  final int? selectedDeviceId;
  final Function(int)? onDeviceSelected;
  final Function({int? deviceToKeepHighlighted})? onClearPortHighlight;
  final String deviceType;
  final bool deviceStatus;
  final DeviceSelectedCallback? onDeviceTappedExternally;
  final double? dimOpacity;
  final bool enableAnimations;
  final double? utilization;
  final bool isRealDevice;

  static bool showOutline = false;

  const DevFloatWidget({
    super.key,
    required this.label,
    required this.portstatus,
    this.size = 100.0,
    this.top = 0,
    this.left = 0,
    this.isHighlighted = false,
    required this.deviceId,
    this.selectedDeviceId,
    this.onDeviceSelected,
    this.onClearPortHighlight,
    required this.deviceType,
    required this.deviceStatus,
    this.onDeviceTappedExternally,
    this.dimOpacity,
    this.enableAnimations = true,
    this.utilization,
    this.isRealDevice = false,
  });
}

/// Base state class for floating device widgets
abstract class DevFloatWidgetState<T extends DevFloatWidget> extends State<T>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;

  /// Check if this device is currently selected
  bool get isSelected => widget.selectedDeviceId == widget.deviceId;

  /// Whether this device is in the spotlight (not dimmed)
  bool get _isSpotlit => widget.dimOpacity == null || widget.dimOpacity == 1.0;

  /// Build the device label. Subclasses can override for custom display.
  Widget buildLabel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Text(
          widget.label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          overflow: TextOverflow.visible,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isHighlighted || isSelected) {
      _controller.value = 1.0;
    }
    if (_isSpotlit && widget.dimOpacity != null) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool wasSelected = oldWidget.selectedDeviceId == oldWidget.deviceId;

    if (widget.isHighlighted != oldWidget.isHighlighted ||
        isSelected != wasSelected) {
      if (widget.isHighlighted || isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }

    // Start/stop pulse glow based on spotlight state
    final bool wasSpotlit =
        oldWidget.dimOpacity == null || oldWidget.dimOpacity == 1.0;
    final bool hadDimContext = oldWidget.dimOpacity != null;
    if (widget.enableAnimations && _isSpotlit && widget.dimOpacity != null && (!wasSpotlit || !hadDimContext)) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.enableAnimations || !_isSpotlit || widget.dimOpacity == null) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Build the device icon. Subclasses must implement this.
  Widget buildDeviceIcon(double animationValue);

  @override
  Widget build(BuildContext context) {
    double textOpacity = widget.isHighlighted ||
            isSelected ||
            widget.deviceType == 'Unknown' ||
            widget.deviceType == 'Switch' ||
            widget.deviceType == 'Host' ||
            widget.deviceType == 'DPU'
        ? 1.0
        : _controller.value;

    return AnimatedBuilder(
        animation: Listenable.merge([_controller, _pulseController]),
        builder: (context, child) {
          final double hoverOffset = _controller.value * 2;

          // Circle is size+30 to contain both icon and label
          final double visualSize = widget.size + 30;

          // Scale pop: spotlit devices scale up, dimmed scale down
          double scale = 1.0;
          if (widget.dimOpacity != null && widget.enableAnimations) {
            if (_isSpotlit) {
              scale = 1.0 + 0.10 * _pulseController.value * 0.3 + 0.05;
            } else {
              scale = 0.95;
            }
          }

          // Determine if we should show info instead of icon
          final bool showUtilInfo = widget.isRealDevice &&
              widget.utilization != null &&
              _isSpotlit &&
              widget.dimOpacity != null;

          // Build the center content: icon or utilization info
          Widget centerContent;
          if (showUtilInfo) {
            // Icon swaps to utilization info
            final double util = widget.utilization!;
            final Color utilColor = _utilizationColor(util);
            final String tierLabel = _utilizationTier(util);
            centerContent = SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(util * 100).round()}%',
                      style: TextStyle(
                        color: utilColor,
                        fontSize: widget.size * 0.3,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      tierLabel,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: widget.size * 0.15,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            centerContent = buildDeviceIcon(_controller.value);
          }

          // Build ring gauge for explore devices with utilization
          Widget deviceContent;
          if (widget.isRealDevice && widget.utilization != null) {
            final double util = widget.utilization!;
            final Color utilColor = _utilizationColor(util);
            deviceContent = SizedBox(
              width: visualSize,
              height: visualSize,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Ring gauge
                  Positioned(
                    top: (visualSize - widget.size - 6) / 2,
                    left: (visualSize - widget.size - 6) / 2,
                    child: CustomPaint(
                      size: Size(widget.size + 6, widget.size + 6),
                      painter: _RingGaugePainter(
                        utilization: util,
                        color: utilColor,
                        strokeWidth: 4.0,
                      ),
                    ),
                  ),
                  centerContent,
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: buildLabel(),
                    ),
                  ),
                ],
              ),
            );
          } else {
            deviceContent = SizedBox(
              width: visualSize,
              height: visualSize,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  centerContent,
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: buildLabel(),
                    ),
                  ),
                ],
              ),
            );
          }

          // Pulse glow effect when spotlit
          if (_isSpotlit && widget.dimOpacity != null && widget.enableAnimations) {
            final Color glowColor = widget.isRealDevice && widget.utilization != null
                ? _utilizationColor(widget.utilization!)
                : (widget.portstatus == -1 ? Colors.red : Colors.green);
            final double glowOpacity =
                0.2 + 0.4 * _pulseController.value;
            final double glowSpread =
                4.0 + 8.0 * _pulseController.value;

            deviceContent = Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: glowOpacity),
                    blurRadius: glowSpread,
                    spreadRadius: glowSpread * 0.3,
                  ),
                ],
              ),
              child: deviceContent,
            );
          }

          Widget content = MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) {
                if (!(widget.isHighlighted || isSelected)) {
                  _controller.forward();
                }
              },
              onExit: (_) {
                if (!(widget.isHighlighted || isSelected)) {
                  _controller.reverse();
                }
              },
              child: GestureDetector(
                onTap: () {
                  if (widget.onDeviceTappedExternally != null) {
                    widget.onDeviceTappedExternally!(
                        widget.label, widget.deviceType, widget.deviceId);
                  } else {
                    int currentDeviceId = widget.deviceId;
                    if (widget.onClearPortHighlight != null) {
                      widget.onClearPortHighlight!(
                          deviceToKeepHighlighted: currentDeviceId);
                    }
                    if (widget.onDeviceSelected != null) {
                      widget.onDeviceSelected!(currentDeviceId);
                    }
                  }
                },
                child: Transform.scale(
                  scale: scale,
                  child: deviceContent,
                ),
              ),
            );

          // Smooth fade transition
          if (widget.enableAnimations) {
            content = TweenAnimationBuilder<double>(
              tween: Tween(end: widget.dimOpacity ?? 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: content,
            );
          } else if (widget.dimOpacity != null) {
            content = Opacity(opacity: widget.dimOpacity!, child: content);
          }

          return Positioned(
            left: widget.left - visualSize / 2,
            top: widget.top - visualSize / 2 - hoverOffset,
            child: content,
          );
        });
  }

  /// Get color for utilization tier.
  static Color _utilizationColor(double util) {
    if (util >= 0.95) return Colors.red;
    if (util >= 0.8) return Colors.red;
    if (util >= 0.5) return Colors.orange;
    return Colors.green;
  }

  /// Get label for utilization tier.
  static String _utilizationTier(double util) {
    if (util >= 0.95) return 'CRIT';
    if (util >= 0.8) return 'HIGH';
    if (util >= 0.5) return 'MED';
    return 'LOW';
  }
}

/// Custom painter for the utilization ring gauge arc.
class _RingGaugePainter extends CustomPainter {
  final double utilization;
  final Color color;
  final double strokeWidth;

  _RingGaugePainter({
    required this.utilization,
    required this.color,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, bgPaint);

    // Utilization arc (clockwise from top)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweepAngle = 2 * math.pi * utilization;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from top
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingGaugePainter oldDelegate) {
    return oldDelegate.utilization != utilization ||
        oldDelegate.color != color;
  }
}
