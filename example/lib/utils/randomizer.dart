import 'dart:math';

import 'package:device_topology_view/device_topology_view.dart';

final _random = Random();

const _deviceTypes = ['Switch', 'Host', 'MMI', 'Agent', 'Unknown'];

Map<String, PortStatus> randomizePortStatuses(Map<String, PortStatus> original) {
  final values = PortStatus.values;
  return original.map(
    (key, _) => MapEntry(key, values[_random.nextInt(values.length)]),
  );
}

/// Generate realistic port devices for any device type.
///
/// Produces all 4 connection situations:
///   - Green (status 1): baseline matches explore (verified)
///   - Black dashed (status 0, no explore): baseline only, unverified
///   - Red curved (status -1): explore only, unexpected device
///   - Black + Red (status 0, with explore): baseline and explore differ (mismatch)
List<PortDevice> generateDevices({
  required DeviceType deviceType,
  required int count,
  bool fullMismatch = false,
}) {
  switch (deviceType) {
    case DeviceType.host:
      return _generateHostDevices(count, fullMismatch);
    case DeviceType.agent:
      return _generateAgentDevices(count, fullMismatch);
    case DeviceType.switch_:
      return _generateSwitchDevices(count, fullMismatch);
  }
}

List<PortDevice> _generateSwitchDevices(int count, bool fullMismatch) {
  return List.generate(count, (i) {
    final portNum = i + 1;
    final devType = _deviceTypes[portNum % _deviceTypes.length];
    final typeIndex = portNum ~/ _deviceTypes.length + 1;
    final name = '$devType-$typeIndex';

    return _buildPortDevice(
      portId: portNum.toString(),
      portNumber: portNum,
      baselineName: name,
      deviceType: devType,
      baselineIp: '10.0.0.$portNum',
      index: i,
      forceMismatch: fullMismatch,
    );
  });
}

List<PortDevice> _generateHostDevices(int count, bool fullMismatch) {
  return List.generate(count, (i) {
    final portId = 'slotA_port${i + 1}';
    return _buildPortDevice(
      portId: portId,
      portNumber: null,
      baselineName: 'Switch-${i + 1}',
      deviceType: 'Switch',
      baselineIp: '10.0.1.${i + 1}',
      index: i,
      forceMismatch: fullMismatch,
    );
  });
}

List<PortDevice> _generateAgentDevices(int count, bool fullMismatch) {
  final slots = ['slotA', 'slotB'];
  return List.generate(count.clamp(0, 2), (i) {
    return _buildPortDevice(
      portId: slots[i],
      portNumber: null,
      baselineName: 'Switch-${String.fromCharCode(65 + i)}',
      deviceType: 'Switch',
      baselineIp: '10.0.2.${i + 1}',
      index: i,
      forceMismatch: fullMismatch,
    );
  });
}

/// Build a single PortDevice with realistic connection scenario.
///
/// Cycles through all 4 situations based on index:
///   i % 4 == 0 → Green (matched): baseline == explore
///   i % 4 == 1 → Black dashed: baseline only, no explore
///   i % 4 == 2 → Red: explore only, no baseline match
///   i % 4 == 3 → Black + Red: baseline and explore differ (mismatch)
PortDevice _buildPortDevice({
  required String portId,
  required int? portNumber,
  required String baselineName,
  required String deviceType,
  required String baselineIp,
  required int index,
  bool forceMismatch = false,
}) {
  if (forceMismatch) {
    // All ports get baseline + different explore (black + red)
    final exploreName = 'Probe-${_deviceTypes[_random.nextInt(_deviceTypes.length)]}-${index + 1}';
    final exploreIp = '10.0.99.${index + 1}';
    return PortDevice(
      portId: portId,
      portNumber: portNumber,
      deviceName: baselineName,
      deviceType: deviceType,
      deviceIp: baselineIp,
      exploreDevName: exploreName,
      exploreDevIp: exploreIp,
      connectionStatus: 0,
      deviceStatus: true,
      exploreInboundUtilization: _random.nextDouble(),
      exploreOutboundUtilization: _random.nextDouble(),
    );
  }

  final int situation = index % 4;

  switch (situation) {
    case 0:
      // Green: baseline matches explore (verified, real device)
      return PortDevice(
        portId: portId,
        portNumber: portNumber,
        deviceName: baselineName,
        deviceType: deviceType,
        deviceIp: baselineIp,
        exploreDevName: baselineName,
        exploreDevIp: baselineIp,
        connectionStatus: 1,
        deviceStatus: true,
        exploreInboundUtilization: _random.nextDouble(),
      exploreOutboundUtilization: _random.nextDouble(),
      );
    case 1:
      // Black dashed: baseline only, no explore data
      return PortDevice(
        portId: portId,
        portNumber: portNumber,
        deviceName: baselineName,
        deviceType: deviceType,
        deviceIp: baselineIp,
        connectionStatus: 0,
        deviceStatus: true,
      );
    case 2:
      // Red: probed connection, baseline only with status -1
      return PortDevice(
        portId: portId,
        portNumber: portNumber,
        deviceName: baselineName,
        deviceType: deviceType,
        deviceIp: baselineIp,
        connectionStatus: -1,
        deviceStatus: false,
      );
    case 3:
    default:
      // Black + Red: baseline configured AND explore found different device
      final exploreName = 'Probe-${_deviceTypes[_random.nextInt(_deviceTypes.length)]}-${index + 1}';
      final exploreIp = '10.0.99.${index + 1}';
      return PortDevice(
        portId: portId,
        portNumber: portNumber,
        deviceName: baselineName,
        deviceType: deviceType,
        deviceIp: baselineIp,
        exploreDevName: exploreName,
        exploreDevIp: exploreIp,
        connectionStatus: 0,
        deviceStatus: _random.nextDouble() > 0.3,
        exploreInboundUtilization: _random.nextDouble(),
      exploreOutboundUtilization: _random.nextDouble(),
      );
  }
}
