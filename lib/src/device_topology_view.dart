import 'package:flutter/material.dart';
import 'models/device_type.dart';
import 'models/port_device.dart';
import 'models/device_format.dart';
import 'models/port_status.dart';

class DeviceTopologyView extends StatefulWidget {
  const DeviceTopologyView({
    required this.size,
    required this.deviceType,
    required this.format,
    required this.portDevices,
    required this.portStatusMap,
    required this.centerLabel,
    this.isConfig = false,
    this.onDeviceSelected,
    this.initialStackedSwitchPart,
    this.onStackedSwitchPartChanged,
    super.key,
  });

  final Size size;
  final DeviceType deviceType;
  final DeviceFormat format;
  final List<PortDevice> portDevices;
  final Map<String, PortStatus> portStatusMap;
  final String centerLabel;
  final bool isConfig;
  final void Function(String deviceName, String deviceType, int? portNum)?
      onDeviceSelected;
  final int? initialStackedSwitchPart;
  final void Function(int part)? onStackedSwitchPartChanged;

  @override
  State<DeviceTopologyView> createState() => _DeviceTopologyViewState();
}

class _DeviceTopologyViewState extends State<DeviceTopologyView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Center(child: Text('DeviceTopologyView placeholder')),
    );
  }
}
