import 'package:flutter/material.dart';
import '../svg_widget.dart';
import 'dev_float.dart';

class UnknownDevFloat extends DevFloat {
  UnknownDevFloat({
    required super.position,
    required super.label,
    required super.portstatus,
    super.size = 50.0,
    required super.connectedPortNum,
    super.isHighlighted = false,
    required super.deviceStatus,
    super.deviceIp,
    super.portId,
  }) : super(deviceType: 'Unknown');

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

    return UnknownDevFloatWidget(
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
    );
  }
}

class UnknownDevFloatWidget extends DevFloatWidget {
  const UnknownDevFloatWidget({
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
  });

  @override
  State<UnknownDevFloatWidget> createState() => _UnknownDevFloatWidgetState();
}

class _UnknownDevFloatWidgetState
    extends DevFloatWidgetState<UnknownDevFloatWidget> {
  @override
  Widget buildDeviceIcon(double animationValue) {
    return Container(
      width: widget.size + 30,
      height: widget.size + 30,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: SvgClip(
              path: 'assets/images/unknown_float.svg',
              elevation: 2 + animationValue * 5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildLabel() {
    if (widget.label.isEmpty) {
      return const Text(
        'Unknown Device',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    }

    if (widget.label.contains('+')) {
      List<String> parts = widget.label.split('+');

      if (parts.length < 2 ||
          parts[0].trim().isEmpty ||
          parts[1].trim().isEmpty) {
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

      String firstLine = parts[0].trim();
      String secondLine = parts[1].trim();

      if (secondLine.contains(',')) {
        List<String> ips =
            secondLine.split(',').map((ip) => ip.trim()).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstLine,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 2),
            ...ips
                .map((ip) => Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        ip,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ))
                .toList(),
          ],
        );
      } else {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstLine,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 2),
            Text(
              secondLine,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ],
        );
      }
    } else {
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
}
