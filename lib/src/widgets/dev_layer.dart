import 'package:flutter/material.dart';
import 'floating_devices/dev_float.dart';

export 'floating_devices/dev_float.dart' show DeviceSelectedCallback;

/// Device layer that renders all floating devices in a Stack
class DevLayer extends StatefulWidget {
  final List<DevFloat> devices;
  final Function({int? deviceToKeepHighlighted})? onClearPortHighlight;
  final int? selectedDeviceId;
  final Function(int)? onDeviceSelected;
  final DeviceSelectedCallback? onExternalDeviceSelected;
  final int? activePortNumber;

  const DevLayer({
    super.key,
    required this.devices,
    this.onClearPortHighlight,
    this.selectedDeviceId,
    this.onDeviceSelected,
    this.onExternalDeviceSelected,
    this.activePortNumber,
  });

  @override
  State<DevLayer> createState() => _DevLayerState();
}

class _DevLayerState extends State<DevLayer> {
  void _handleDeviceSelected(int deviceId) {
    if (widget.onDeviceSelected != null) {
      widget.onDeviceSelected!(deviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? active = widget.activePortNumber;
    return Stack(
      children: [
        for (final device in widget.devices)
          device.createWidget(
            left: device.position.dx,
            top: device.position.dy,
            selectedDeviceId: widget.selectedDeviceId,
            onDeviceSelected: _handleDeviceSelected,
            onClearPortHighlight: widget.onClearPortHighlight,
            onDeviceTapped: widget.onExternalDeviceSelected,
            dimOpacity: active != null && device.connectedPortNum != active
                ? 0.15
                : null,
          ),
      ],
    );
  }
}
