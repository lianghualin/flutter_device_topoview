import 'package:device_topology_view/device_topology_view.dart';

import 'scenario.dart';

final List<Scenario> allScenarios = [
  _hostScenario(1),
  _hostScenario(2),
  _hostScenario(3),
  _hostScenario(4),
  _hostScenario(5),
  _hostScenario(6),
  _dpuScenario(),
  _switchScenario(
    label: 'Switch 6P',
    format: const SwitchUD1U6P(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.1.1', connectionStatus: 1),
      const PortDevice(portId: '3', deviceName: 'Host-1', portNumber: 3, deviceType: 'Host', deviceIp: '10.0.1.2', connectionStatus: 0),
      const PortDevice(portId: '5', deviceName: 'Unknown-1', portNumber: 5, deviceType: 'Unknown', deviceIp: '10.0.1.3', connectionStatus: -1),
    ],
    totalPorts: 6,
  ),
  _switchScenario(
    label: 'Switch 10P',
    format: const SwitchUD1U10P(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.2.1', connectionStatus: 1),
      const PortDevice(portId: '4', deviceName: 'Host-1', portNumber: 4, deviceType: 'Host', deviceIp: '10.0.2.2', connectionStatus: 0),
      const PortDevice(portId: '7', deviceName: 'DPU-1', portNumber: 7, deviceType: 'DPU', deviceIp: '10.0.2.3', connectionStatus: 1),
      const PortDevice(portId: '10', deviceName: 'MMI-1', portNumber: 10, deviceType: 'MMI', deviceIp: '10.0.2.4', connectionStatus: 0),
    ],
    totalPorts: 10,
  ),
  _switchScenario(
    label: 'Switch 16P',
    format: const SwitchUD1U16P(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.3.1', connectionStatus: 1),
      const PortDevice(portId: '4', deviceName: 'Host-1', portNumber: 4, deviceType: 'Host', deviceIp: '10.0.3.2', connectionStatus: 0),
      const PortDevice(portId: '8', deviceName: 'DPU-1', portNumber: 8, deviceType: 'DPU', deviceIp: '10.0.3.3', connectionStatus: 1),
      const PortDevice(portId: '11', deviceName: 'Switch-B', portNumber: 11, deviceType: 'Switch', deviceIp: '10.0.3.4', connectionStatus: -1),
      const PortDevice(portId: '15', deviceName: 'Unknown-1', portNumber: 15, deviceType: 'Unknown', deviceIp: '10.0.3.5', connectionStatus: 0),
    ],
    totalPorts: 16,
  ),
  _switchScenario(
    label: 'Switch 24P',
    format: const SwitchUD1U24P(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.4.1', connectionStatus: 1),
      const PortDevice(portId: '3', deviceName: 'Host-1', portNumber: 3, deviceType: 'Host', deviceIp: '10.0.4.2', connectionStatus: 0),
      const PortDevice(portId: '6', deviceName: 'DPU-1', portNumber: 6, deviceType: 'DPU', deviceIp: '10.0.4.3', connectionStatus: 1),
      const PortDevice(portId: '9', deviceName: 'Unknown-1', portNumber: 9, deviceType: 'Unknown', deviceIp: '10.0.4.4', connectionStatus: -1),
      const PortDevice(portId: '12', deviceName: 'Switch-B', portNumber: 12, deviceType: 'Switch', deviceIp: '10.0.4.5', connectionStatus: 1),
      const PortDevice(portId: '15', deviceName: 'MMI-1', portNumber: 15, deviceType: 'MMI', deviceIp: '10.0.4.6', connectionStatus: 0),
      const PortDevice(portId: '18', deviceName: 'Host-2', portNumber: 18, deviceType: 'Host', deviceIp: '10.0.4.7', connectionStatus: 0),
      const PortDevice(portId: '21', deviceName: 'DPU-2', portNumber: 21, deviceType: 'DPU', deviceIp: '10.0.4.8', connectionStatus: 1),
    ],
    totalPorts: 24,
  ),
  _switchScenario(
    label: 'Switch 28P',
    format: const SwitchUD1U28P(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.5.1', connectionStatus: 1),
      const PortDevice(portId: '5', deviceName: 'Host-1', portNumber: 5, deviceType: 'Host', deviceIp: '10.0.5.2', connectionStatus: 0),
      const PortDevice(portId: '10', deviceName: 'DPU-1', portNumber: 10, deviceType: 'DPU', deviceIp: '10.0.5.3', connectionStatus: 1),
      const PortDevice(portId: '15', deviceName: 'Switch-B', portNumber: 15, deviceType: 'Switch', deviceIp: '10.0.5.4', connectionStatus: -1),
      const PortDevice(portId: '20', deviceName: 'Unknown-1', portNumber: 20, deviceType: 'Unknown', deviceIp: '10.0.5.5', connectionStatus: 0),
      const PortDevice(portId: '25', deviceName: 'Host-2', portNumber: 25, deviceType: 'Host', deviceIp: '10.0.5.6', connectionStatus: 1),
    ],
    totalPorts: 28,
  ),
  _switchScenario(
    label: 'Switch 30P (Stacked)',
    format: const SwitchUD1U30PStacked(),
    devices: [
      const PortDevice(portId: '2', deviceName: 'Switch-A', portNumber: 2, deviceType: 'Switch', deviceIp: '10.0.6.1', connectionStatus: 1),
      const PortDevice(portId: '8', deviceName: 'Host-1', portNumber: 8, deviceType: 'Host', deviceIp: '10.0.6.2', connectionStatus: 0),
      const PortDevice(portId: '14', deviceName: 'DPU-1', portNumber: 14, deviceType: 'DPU', deviceIp: '10.0.6.3', connectionStatus: 1),
      const PortDevice(portId: '20', deviceName: 'Switch-B', portNumber: 20, deviceType: 'Switch', deviceIp: '10.0.6.4', connectionStatus: -1),
      const PortDevice(portId: '25', deviceName: 'Host-2', portNumber: 25, deviceType: 'Host', deviceIp: '10.0.6.5', connectionStatus: 0),
      const PortDevice(portId: '28', deviceName: 'Unknown-1', portNumber: 28, deviceType: 'Unknown', deviceIp: '10.0.6.6', connectionStatus: 1),
    ],
    totalPorts: 48, // Must be 48 (format.totalPortsNum) so port status map covers all layout ports
  ),
  _switchScenario(
    label: 'Switch 48P (Stacked)',
    format: const SwitchUD1U48PStacked(),
    devices: [
      const PortDevice(portId: '1', deviceName: 'Switch-A', portNumber: 1, deviceType: 'Switch', deviceIp: '10.0.7.1', connectionStatus: 1),
      const PortDevice(portId: '5', deviceName: 'Host-1', portNumber: 5, deviceType: 'Host', deviceIp: '10.0.7.2', connectionStatus: 0),
      const PortDevice(portId: '10', deviceName: 'DPU-1', portNumber: 10, deviceType: 'DPU', deviceIp: '10.0.7.3', connectionStatus: 1),
      const PortDevice(portId: '15', deviceName: 'MMI-1', portNumber: 15, deviceType: 'MMI', deviceIp: '10.0.7.4', connectionStatus: 0),
      const PortDevice(portId: '20', deviceName: 'Unknown-1', portNumber: 20, deviceType: 'Unknown', deviceIp: '10.0.7.5', connectionStatus: -1),
      const PortDevice(portId: '25', deviceName: 'Switch-B', portNumber: 25, deviceType: 'Switch', deviceIp: '10.0.7.6', connectionStatus: 1),
      const PortDevice(portId: '30', deviceName: 'Host-2', portNumber: 30, deviceType: 'Host', deviceIp: '10.0.7.7', connectionStatus: 0),
      const PortDevice(portId: '35', deviceName: 'DPU-2', portNumber: 35, deviceType: 'DPU', deviceIp: '10.0.7.8', connectionStatus: 1),
      const PortDevice(portId: '40', deviceName: 'Switch-C', portNumber: 40, deviceType: 'Switch', deviceIp: '10.0.7.9', connectionStatus: -1),
      const PortDevice(portId: '45', deviceName: 'Host-3', portNumber: 45, deviceType: 'Host', deviceIp: '10.0.7.10', connectionStatus: 0),
    ],
    totalPorts: 48,
  ),
];

Scenario _hostScenario(int deviceCount) {
  final portStatusMap = <String, PortStatus>{};
  final devices = <PortDevice>[];

  for (int i = 0; i < deviceCount; i++) {
    final portId = 'slotA_port${i + 1}';
    portStatusMap[portId] = i % 3 == 0
        ? PortStatus.up
        : (i % 3 == 1 ? PortStatus.down : PortStatus.unknown);

    final bool hasExplore = i >= 1 && i < 3;
    devices.add(PortDevice(
      portId: portId,
      deviceName: 'Switch-${i + 1}',
      deviceType: 'Switch',
      deviceIp: '10.0.0.${i + 1}',
      exploreDevName: hasExplore ? 'Probe-Switch-${i + 1}' : null,
      exploreDevIp: hasExplore ? '10.0.99.${i + 1}' : null,
      connectionStatus: hasExplore ? 0 : 1,
      deviceStatus: i != 2,
    ));
  }

  return Scenario(
    label: 'Host ($deviceCount device${deviceCount > 1 ? 's' : ''})',
    deviceType: DeviceType.host,
    format: const HostTemplate(),
    portDevices: devices,
    portStatusMap: portStatusMap,
    centerLabel: 'Host-Server',
  );
}

Scenario _dpuScenario() {
  return Scenario(
    label: 'DPU',
    deviceType: DeviceType.dpu,
    format: const DPUTemplate(),
    portDevices: const [
      PortDevice(
        portId: 'slotA',
        deviceName: 'Switch-A',
        deviceType: 'Switch',
        deviceIp: '10.0.10.1',
        connectionStatus: 1,
        deviceStatus: true,
      ),
      PortDevice(
        portId: 'slotB',
        deviceName: 'Switch-B',
        deviceType: 'Switch',
        deviceIp: '10.0.10.2',
        connectionStatus: 1,
        deviceStatus: true,
      ),
    ],
    portStatusMap: const {
      'slotA_port1': PortStatus.up,
      'slotA_port2': PortStatus.down,
      'slotA_port3': PortStatus.up,
      'slotA_port4': PortStatus.unknown,
      'slotB_port1': PortStatus.up,
      'slotB_port2': PortStatus.up,
      'slotB_port3': PortStatus.down,
      'slotB_port4': PortStatus.unknown,
    },
    centerLabel: 'DPU-Node',
  );
}

Scenario _switchScenario({
  required String label,
  required SwitchDeviceFormat format,
  required List<PortDevice> devices,
  required int totalPorts,
}) {
  final portStatusMap = <String, PortStatus>{};
  for (int i = 1; i <= totalPorts; i++) {
    portStatusMap[i.toString()] = i % 3 == 0
        ? PortStatus.up
        : (i % 3 == 1 ? PortStatus.down : PortStatus.unknown);
  }

  return Scenario(
    label: label,
    deviceType: DeviceType.switch_,
    format: format,
    portDevices: devices,
    portStatusMap: portStatusMap,
    centerLabel: 'Switch-Core',
  );
}
