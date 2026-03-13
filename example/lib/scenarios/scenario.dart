import 'package:device_topology_view/device_topology_view.dart';

class Scenario {
  const Scenario({
    required this.label,
    required this.deviceType,
    required this.format,
    required this.portDevices,
    required this.portStatusMap,
    required this.centerLabel,
  });

  final String label;
  final DeviceType deviceType;
  final DeviceFormat format;
  final List<PortDevice> portDevices;
  final Map<String, PortStatus> portStatusMap;
  final String centerLabel;

  int get maxDevices {
    if (deviceType == DeviceType.host) return 6;
    if (deviceType == DeviceType.dpu) return 2;
    if (format is SwitchDeviceFormat) {
      final sf = format as SwitchDeviceFormat;
      return sf.validPortsNum ?? sf.totalPortsNum;
    }
    return 6;
  }
}
