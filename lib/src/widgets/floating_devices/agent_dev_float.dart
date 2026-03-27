import 'package:flutter/material.dart';
import 'package:topology_view_icons/topology_view_icons.dart';
import 'dev_float.dart';

class AgentDevFloat extends DevFloat {
  final int totalPfs;
  final int usedPfs;

  AgentDevFloat({
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
    super.inboundUtilization,
    super.outboundUtilization,
    super.isRealDevice,
  }) : super(deviceType: 'Agent');

  @override
  Widget createWidget({
    double top = 0,
    double left = 0,
    int? selectedDeviceId,
    Function(int)? onDeviceSelected,
    Function({int? deviceToKeepHighlighted})? onClearPortHighlight,
    DeviceSelectedCallback? onDeviceTapped,
    double? dimOpacity,
    bool enableAnimations = true,
  }) {
    String uniqueKeyString = '${portId}_${label}_${deviceType}_$portstatus';

    return AgentDevFloatWidget(
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
      enableAnimations: enableAnimations,
      inboundUtilization: inboundUtilization,
      outboundUtilization: outboundUtilization,
      isRealDevice: isRealDevice,
    );
  }
}

class AgentDevFloatWidget extends DevFloatWidget {
  final int totalPfs;
  final int usedPfs;

  const AgentDevFloatWidget({
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
    super.enableAnimations,
    super.inboundUtilization,
    super.outboundUtilization,
    super.isRealDevice,
  });

  @override
  State<AgentDevFloatWidget> createState() => _AgentDevFloatWidgetState();
}

class _AgentDevFloatWidgetState extends DevFloatWidgetState<AgentDevFloatWidget> {
  @override
  Widget buildCompactIcon(double animationValue) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: TopoIconPainter(
          deviceType: TopoDeviceType.agent,
          style: TopoIconStyle.lnm,
        ),
      ),
    );
  }

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
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: TopoIconPainter(
              deviceType: TopoDeviceType.agent,
              style: TopoIconStyle.lnm,
            ),
          ),
        ),
      ),
    );
  }
}
