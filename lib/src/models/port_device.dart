class PortDevice {
  const PortDevice({
    required this.portId,
    required this.deviceName,
    this.portNumber,
    this.deviceType = 'Switch',
    this.deviceIp,
    this.exploreDevName,
    this.exploreDevIp,
    this.connectionStatus = 0,
    this.deviceStatus = true,
    this.exploreUtilization,
  });

  /// Port/slot identifier. e.g. "slotA", "Port1", "23"
  final String portId;

  /// Numeric port number (required for switch, null for host/dpu)
  final int? portNumber;

  /// Baseline device display name
  final String deviceName;

  /// Device type string: 'Switch', 'Host', 'DPU', 'Unknown'
  final String deviceType;

  /// Device IP address (baseline)
  final String? deviceIp;

  /// Explored/discovered device name (host/dpu only)
  final String? exploreDevName;

  /// Explored/discovered device IP (host/dpu only)
  final String? exploreDevIp;

  /// 0=baseline, 1=matched, -1=probed/explore-only
  final int connectionStatus;

  /// true=normal (green indicator), false=abnormal (red indicator)
  final bool deviceStatus;

  /// Explore device utilization (0.0-1.0). Only meaningful when exploreDevName is set.
  /// null = no utilization data available.
  final double? exploreUtilization;
}
