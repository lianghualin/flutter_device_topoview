import 'package:device_topology_view/device_topology_view.dart';

import 'scenario.dart';
import '../utils/randomizer.dart';

final List<Scenario> allScenarios = [
  _hostScenario(1),
  _hostScenario(2),
  _hostScenario(3),
  _hostScenario(4),
  _hostScenario(5),
  _hostScenario(6),
  _dpuScenario(1),
  _dpuScenario(2),
  _switchScenario(label: 'Switch 6P', format: const SwitchUD1U6P(), totalPorts: 6),
  _switchScenario(label: 'Switch 10P', format: const SwitchUD1U10P(), totalPorts: 10),
  _switchScenario(label: 'Switch 16P', format: const SwitchUD1U16P(), totalPorts: 16),
  _switchScenario(label: 'Switch 24P', format: const SwitchUD1U24P(), totalPorts: 24),
  _switchScenario(label: 'Switch 28P', format: const SwitchUD1U28P(), totalPorts: 28),
  _switchScenario(label: 'Switch 30P (Stacked)', format: const SwitchUD1U30PStacked(), totalPorts: 48),
  _switchScenario(label: 'Switch 48P (Stacked)', format: const SwitchUD1U48PStacked(), totalPorts: 48),
];

Scenario _hostScenario(int deviceCount) {
  final portStatusMap = <String, PortStatus>{};
  final devices = generateDevices(
    deviceType: DeviceType.host,
    count: deviceCount,
  );

  for (final dev in devices) {
    portStatusMap[dev.portId] = PortStatus.values[
        devices.indexOf(dev) % PortStatus.values.length];
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

Scenario _dpuScenario(int portCount) {
  final devices = generateDevices(
    deviceType: DeviceType.dpu,
    count: portCount,
  );

  final portStatusMap = <String, PortStatus>{};
  for (final dev in devices) {
    portStatusMap[dev.portId] = PortStatus.up;
  }

  return Scenario(
    label: 'DPU ($portCount port${portCount > 1 ? 's' : ''})',
    deviceType: DeviceType.dpu,
    format: const DPUTemplate(),
    portDevices: devices,
    portStatusMap: portStatusMap,
    centerLabel: 'DPU-Node',
  );
}

Scenario _switchScenario({
  required String label,
  required SwitchDeviceFormat format,
  required int totalPorts,
}) {
  final devices = generateDevices(
    deviceType: DeviceType.switch_,
    count: totalPorts,
  );

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
