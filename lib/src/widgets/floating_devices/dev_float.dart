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
  });

  /// Create the corresponding widget
  Widget createWidget({
    double top = 0,
    double left = 0,
    int? selectedDeviceId,
    Function(int)? onDeviceSelected,
    Function({int? deviceToKeepHighlighted})? onClearPortHighlight,
    DeviceSelectedCallback? onDeviceTapped,
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
  });
}

/// Base state class for floating device widgets
abstract class DevFloatWidgetState<T extends DevFloatWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// Check if this device is currently selected
  bool get isSelected => widget.selectedDeviceId == widget.deviceId;

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
        animation: _controller,
        builder: (context, child) {
          final double hoverOffset = _controller.value * 2;

          return Positioned(
            left: widget.left - (widget.size / 2),
            top: widget.top - (widget.size / 2) - hoverOffset,
            child: MouseRegion(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: widget.size,
                      height: widget.size + 10,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          buildDeviceIcon(_controller.value),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: widget.deviceType == 'Switch'
                          ? const Offset(0, -17)
                          : widget.deviceType == 'Host'
                              ? const Offset(0, -8)
                              : widget.deviceType == 'DPU'
                                  ? const Offset(0, 0)
                                  : const Offset(0, -5),
                      child: Opacity(
                        opacity: textOpacity,
                        child: buildLabel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
