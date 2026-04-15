import 'package:flutter/material.dart';
import 'package:flutter_device_ring/flutter_device_ring.dart';

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
  final double? inboundUtilization;
  final double? outboundUtilization;
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
    this.inboundUtilization,
    this.outboundUtilization,
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
  final double? inboundUtilization;
  final double? outboundUtilization;
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
    this.inboundUtilization,
    this.outboundUtilization,
    this.isRealDevice = false,
  });
}

/// Base state class for floating device widgets
abstract class DevFloatWidgetState<T extends DevFloatWidget> extends State<T>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  /// Check if this device is currently selected
  bool get isSelected => widget.selectedDeviceId == widget.deviceId;

  /// Whether this device is in the spotlight (not dimmed)
  bool get _isSpotlit => widget.dimOpacity == null || widget.dimOpacity == 1.0;

  /// Whether this device should show the DeviceRing.
  /// True for all real (explore) devices — uses 0.0 when utilization is null.
  bool get _showRing => widget.isRealDevice;

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

    if (widget.isHighlighted || isSelected) {
      _controller.value = 1.0;
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Build the device icon. Subclasses must implement this.
  Widget buildDeviceIcon(double animationValue);

  /// Build a compact icon for use inside DeviceRing (no background circle or padding).
  /// Subclasses should override this to return just the SVG/icon.
  Widget buildCompactIcon(double animationValue) {
    return buildDeviceIcon(animationValue);
  }

  @override
  Widget build(BuildContext context) {
    double textOpacity = widget.isHighlighted ||
            isSelected ||
            widget.deviceType == 'Unknown' ||
            widget.deviceType == 'Switch' ||
            widget.deviceType == 'Host' ||
            widget.deviceType == 'Agent'
        ? 1.0
        : _controller.value;

    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double hoverOffset = _controller.value * 2;

          // Circle is size+30 to contain both icon and label
          final double visualSize = widget.size + 30;

          // Scale pop: spotlit devices scale up, dimmed scale down
          double scale = 1.0;
          if (widget.dimOpacity != null && widget.enableAnimations) {
            if (_isSpotlit) {
              scale = 1.05;
            } else {
              scale = 0.95;
            }
          }

          // Determine if we should show info instead of icon
          final bool showUtilInfo = _showRing &&
              widget.inboundUtilization != null &&
              _isSpotlit &&
              widget.dimOpacity != null;

          // Build the center content: device icon
          Widget centerContent = buildDeviceIcon(_controller.value);

          // Build device content with or without ring
          Widget deviceContent;
          if (_showRing) {
            final double ringSize = widget.size + 30;

            // Status halo: green=normal, red=abnormal — always visible.
            final Color statusColor = widget.deviceStatus
                ? const Color(0xFF00B42A).withValues(alpha: 0.3)
                : const Color(0xFFF53F3F).withValues(alpha: 0.3);

            // DeviceRing with built-in label, wrapped in status halo
            deviceContent = Stack(
              alignment: Alignment.center,
              children: [
                // Status halo circle behind the ring
                Positioned(
                  top: 0,
                  child: Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // DeviceRing with label handled by the package
                DeviceRing(
                  inbound: widget.inboundUtilization ?? 0.0,
                  outbound: widget.outboundUtilization ?? 0.0,
                  size: ringSize,
                  showGlow: _isSpotlit &&
                      widget.dimOpacity != null &&
                      widget.enableAnimations,
                  showInfo: showUtilInfo,
                  theme: const DeviceRingTheme(
                    showDirectionLabels: false,
                  ),
                  labelWidget: Opacity(
                    opacity: textOpacity,
                    child: buildLabel(),
                  ),
                  labelMaxWidth: visualSize,
                  labelBackgroundDecoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: buildCompactIcon(_controller.value),
                ),
              ],
            );
          } else {
            deviceContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                centerContent,
                const SizedBox(height: 4),
                Opacity(
                  opacity: textOpacity,
                  child: buildLabel(),
                ),
              ],
            );
          }

          Widget content = MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) {
                if (widget.enableAnimations &&
                    !(widget.isHighlighted || isSelected)) {
                  _controller.forward();
                }
              },
              onExit: (_) {
                if (widget.enableAnimations &&
                    !(widget.isHighlighted || isSelected)) {
                  _controller.reverse();
                }
              },
              child: GestureDetector(
                onTap: () {
                  // Internal selection: toggle port spotlight
                  if (widget.onDeviceSelected != null) {
                    widget.onDeviceSelected!(widget.deviceId);
                  }
                },
                onDoubleTap: () {
                  // External callback: navigate to device page
                  if (widget.onDeviceTappedExternally != null) {
                    widget.onDeviceTappedExternally!(
                        widget.label, widget.deviceType, widget.deviceId);
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
}
