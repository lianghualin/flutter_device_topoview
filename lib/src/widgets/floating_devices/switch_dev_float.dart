import 'package:flutter/material.dart';
import '../svg_widget.dart';
import 'dev_float.dart';

class SwitchDevFloat extends DevFloat {
  SwitchDevFloat({
    required super.position,
    required super.label,
    required super.portstatus,
    super.size = 100.0,
    required super.connectedPortNum,
    super.isHighlighted = false,
    required super.deviceStatus,
    super.deviceIp,
    super.portId,
  }) : super(deviceType: 'Switch');

  @override
  Widget createWidget({
    double top = 0,
    double left = 0,
    int? selectedDeviceId,
    Function(int)? onDeviceSelected,
    Function({int? deviceToKeepHighlighted})? onClearPortHighlight,
    DeviceSelectedCallback? onDeviceTapped,
  }) {
    String uniqueKeyString = '${portId}_${label}_${deviceType}_$portstatus';

    return SwitchDevFloatWidget(
      key: ValueKey(uniqueKeyString),
      label: label,
      portstatus: portstatus,
      size: size,
      top: top,
      left: left,
      isHighlighted: isHighlighted,
      deviceId: deviceId,
      deviceType: deviceType,
      deviceStatus: deviceStatus,
      selectedDeviceId: selectedDeviceId,
      onDeviceSelected: onDeviceSelected,
      onClearPortHighlight: onClearPortHighlight,
      onDeviceTappedExternally: onDeviceTapped,
    );
  }
}

class SwitchDevFloatWidget extends DevFloatWidget {
  const SwitchDevFloatWidget({
    super.key,
    required super.label,
    required super.portstatus,
    required super.size,
    required super.top,
    required super.left,
    required super.isHighlighted,
    required super.deviceId,
    required super.deviceType,
    required super.deviceStatus,
    super.selectedDeviceId,
    super.onDeviceSelected,
    super.onClearPortHighlight,
    super.onDeviceTappedExternally,
  });

  @override
  State<SwitchDevFloatWidget> createState() => _SwitchDevFloatWidgetState();
}

class _SwitchDevFloatWidgetState
    extends DevFloatWidgetState<SwitchDevFloatWidget> {
  @override
  Widget buildDeviceIcon(double animationValue) {
    final backgroundColor = widget.deviceStatus == true
        ? const Color(0xFF00B42A).withValues(alpha: 0.3)
        : const Color(0xFFF53F3F).withValues(alpha: 0.3);

    return Container(
      width: widget.size + 30,
      height: widget.size + 30,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: SvgClip(
              path: 'assets/images/switch_float.svg',
              elevation: 2 + animationValue * 5,
            ),
          ),
        ),
      ),
    );
  }
}
