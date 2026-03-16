import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dev_float.dart';

class DpuDevFloat extends DevFloat {
  final int totalPfs;
  final int usedPfs;

  DpuDevFloat({
    required super.position,
    required super.label,
    required super.portstatus,
    super.size = 100.0,
    required super.connectedPortNum,
    super.isHighlighted = false,
    required this.totalPfs,
    required this.usedPfs,
    required super.deviceStatus,
    super.deviceIp,
    super.portId,
  }) : super(deviceType: 'DPU');

  @override
  Widget createWidget({
    double top = 0,
    double left = 0,
    int? selectedDeviceId,
    Function(int)? onDeviceSelected,
    Function({int? deviceToKeepHighlighted})? onClearPortHighlight,
    DeviceSelectedCallback? onDeviceTapped,
    double? dimOpacity,
  }) {
    String uniqueKeyString = '${portId}_${label}_${deviceType}_$portstatus';

    return DpuDevFloatWidget(
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
      totalPfs: totalPfs,
      usedPfs: usedPfs,
      dimOpacity: dimOpacity,
    );
  }
}

class DpuDevFloatWidget extends DevFloatWidget {
  final int totalPfs;
  final int usedPfs;

  const DpuDevFloatWidget({
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
    required this.totalPfs,
    required this.usedPfs,
    super.dimOpacity,
  });

  @override
  State<DpuDevFloatWidget> createState() => _DpuDevFloatWidgetState();
}

class _DpuDevFloatWidgetState extends DevFloatWidgetState<DpuDevFloatWidget> {
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
          child: PhysicalModel(
            color: Colors.transparent,
            elevation: 2 + animationValue * 5,
            child: SvgPicture.asset(
              'assets/images/dpu_float.svg',
              package: 'device_topology_view',
              width: widget.size,
              height: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}
