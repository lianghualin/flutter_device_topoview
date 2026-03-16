import 'package:device_topology_view/device_topology_view.dart';

import 'scenario.dart';

final List<Scenario> allScenarios = [
  _hostScenario(1),
  _hostScenario(2),
  _hostScenario(3),
  _hostScenario(4),
  _hostScenario(5),
  _hostScenario(6),
  _dpuScenario1P(),
  _dpuScenario(),
  _switchScenarioFull(label: 'Switch 6P', format: const SwitchUD1U6P(), totalPorts: 6),
  _switchScenarioFull(label: 'Switch 10P', format: const SwitchUD1U10P(), totalPorts: 10),
  _switchScenarioFull(label: 'Switch 16P', format: const SwitchUD1U16P(), totalPorts: 16),
  _switchScenarioFull(label: 'Switch 24P', format: const SwitchUD1U24P(), totalPorts: 24),
  _switchScenarioFull(label: 'Switch 28P', format: const SwitchUD1U28P(), totalPorts: 28),
  _switchScenarioFull(label: 'Switch 30P (Stacked)', format: const SwitchUD1U30PStacked(), totalPorts: 48),
  _switchScenarioFull(label: 'Switch 48P (Stacked)', format: const SwitchUD1U48PStacked(), totalPorts: 48),
];

Scenario _hostScenario(int deviceCount) {
  final portStatusMap = <String, PortStatus>{};
  final devices = <PortDevice>[];

  for (int i = 0; i < deviceCount; i++) {
    final portId = 'slotA_port${i + 1}';
    portStatusMap[portId] = i % 3 == 0
        ? PortStatus.up
        : (i % 3 == 1 ? PortStatus.down : PortStatus.unknown);

    // Every port gets both baseline and explore devices
    devices.add(PortDevice(
      portId: portId,
      deviceName: 'Switch-${i + 1}',
      deviceType: 'Switch',
      deviceIp: '10.0.0.${i + 1}',
      exploreDevName: 'Probe-Switch-${i + 1}',
      exploreDevIp: '10.0.99.${i + 1}',
      connectionStatus: 0,
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

Scenario _dpuScenario1P() {
  return Scenario(
    label: 'DPU (1 port)',
    deviceType: DeviceType.dpu,
    format: const DPUTemplate(),
    portDevices: const [
      PortDevice(
        portId: 'slotA',
        deviceName: 'Switch-A',
        deviceType: 'Switch',
        deviceIp: '10.0.10.1',
        exploreDevName: 'Probe-Switch-A',
        exploreDevIp: '10.0.99.1',
        connectionStatus: 0,
        deviceStatus: true,
      ),
    ],
    portStatusMap: const {
      'slotA': PortStatus.up,
    },
    centerLabel: 'DPU-Node',
  );
}

Scenario _dpuScenario() {
  return Scenario(
    label: 'DPU (2 port)',
    deviceType: DeviceType.dpu,
    format: const DPUTemplate(),
    portDevices: const [
      PortDevice(
        portId: 'slotA',
        deviceName: 'Switch-A',
        deviceType: 'Switch',
        deviceIp: '10.0.10.1',
        exploreDevName: 'Probe-Switch-A',
        exploreDevIp: '10.0.99.1',
        connectionStatus: 0,
        deviceStatus: true,
      ),
      PortDevice(
        portId: 'slotB',
        deviceName: 'Switch-B',
        deviceType: 'Switch',
        deviceIp: '10.0.10.2',
        exploreDevName: 'Probe-Switch-B',
        exploreDevIp: '10.0.99.2',
        connectionStatus: 0,
        deviceStatus: false,
      ),
    ],
    portStatusMap: const {
      'slotA': PortStatus.up,
      'slotB': PortStatus.up,
    },
    centerLabel: 'DPU-Node',
  );
}

const List<String> _deviceTypes = ['Switch', 'Host', 'DPU', 'MMI', 'Unknown'];

Scenario _switchScenarioFull({
  required String label,
  required SwitchDeviceFormat format,
  required int totalPorts,
}) {
  final portStatusMap = <String, PortStatus>{};
  final devices = <PortDevice>[];

  for (int i = 1; i <= totalPorts; i++) {
    portStatusMap[i.toString()] = i % 3 == 0
        ? PortStatus.up
        : (i % 3 == 1 ? PortStatus.down : PortStatus.unknown);

    final String type = _deviceTypes[(i - 1) % _deviceTypes.length];
    final int typeIndex = (i - 1) ~/ _deviceTypes.length + 1;
    final String name = '$type-$typeIndex';
    final int status = i % 3 == 0 ? 1 : (i % 3 == 1 ? 0 : -1);

    devices.add(PortDevice(
      portId: '$i',
      deviceName: name,
      portNumber: i,
      deviceType: type,
      deviceIp: '10.0.0.$i',
      exploreDevName: 'Probe-$name',
      exploreDevIp: '10.0.99.$i',
      connectionStatus: status,
      deviceStatus: i % 5 != 0,
    ));
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
