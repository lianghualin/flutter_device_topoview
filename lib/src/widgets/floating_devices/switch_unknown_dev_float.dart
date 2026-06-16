import 'package:flutter/material.dart';
import 'package:topology_view_icons/topology_view_icons.dart';
import 'dev_float.dart';

/// Float for a port that likely cascades an *unknown switch* / downstream
/// network (e.g. a port that learned >=2 MACs with no declared downstream
/// switch in the baseline).
///
/// Unlike [UnknownDevFloat] — which renders the "?" host glyph and reads as a
/// failed host probe — this paints the switch-shaped unknown icon
/// ([TopoDeviceType.switchUnknown]) so a cascaded switch is not mistaken for a
/// failed host probe.
class SwitchUnknownDevFloat extends DevFloat {
  SwitchUnknownDevFloat({
    required super.position,
    required super.label,
    required super.portstatus,
    super.size = 50.0,
    required super.connectedPortNum,
    super.isHighlighted = false,
    required super.deviceStatus,
    super.deviceIp,
    super.portId,
    super.inboundUtilization,
    super.outboundUtilization,
    super.isRealDevice,
  }) : super(deviceType: 'SwitchUnknown');

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

    return SwitchUnknownDevFloatWidget(
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
      dimOpacity: dimOpacity,
      enableAnimations: enableAnimations,
      inboundUtilization: inboundUtilization,
      outboundUtilization: outboundUtilization,
      isRealDevice: isRealDevice,
    );
  }
}

class SwitchUnknownDevFloatWidget extends DevFloatWidget {
  const SwitchUnknownDevFloatWidget({
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
    super.dimOpacity,
    super.enableAnimations,
    super.inboundUtilization,
    super.outboundUtilization,
    super.isRealDevice,
  });

  @override
  State<SwitchUnknownDevFloatWidget> createState() =>
      _SwitchUnknownDevFloatWidgetState();
}

class _SwitchUnknownDevFloatWidgetState
    extends DevFloatWidgetState<SwitchUnknownDevFloatWidget> {
  @override
  Widget buildCompactIcon(double animationValue) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: TopoIconPainter(
        deviceType: TopoDeviceType.switchUnknown,
        style: TopoIconStyle.lnm,
      ),
    );
  }

  @override
  Widget buildDeviceIcon(double animationValue) {
    return Container(
      width: widget.size + 30,
      height: widget.size + 30,
      child: Center(
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: TopoIconPainter(
            deviceType: TopoDeviceType.switchUnknown,
            style: TopoIconStyle.lnm,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildLabel() {
    if (widget.label.isEmpty) {
      return const Text(
        'Unknown Switch',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    }

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
  }
}
