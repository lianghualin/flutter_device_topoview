import 'dart:math';

import 'package:device_topology_view/device_topology_view.dart';

final _random = Random();

const _deviceTypes = ['Switch', 'Host', 'MMI', 'DPU', 'Unknown'];

Map<String, PortStatus> randomizePortStatuses(Map<String, PortStatus> original) {
  final values = PortStatus.values;
  return original.map(
    (key, _) => MapEntry(key, values[_random.nextInt(values.length)]),
  );
}

List<PortDevice> generateSwitchDevices(int count) {
  return List.generate(count, (i) {
    final portNum = i + 1;
    final devType = _deviceTypes[_random.nextInt(_deviceTypes.length)];
    return PortDevice(
      portId: portNum.toString(),
      deviceName: '$devType-$portNum',
      portNumber: portNum,
      deviceType: devType,
      deviceIp: '10.0.${_random.nextInt(255)}.${_random.nextInt(255)}',
      connectionStatus: _random.nextBool() ? 0 : 1,
      deviceStatus: _random.nextDouble() > 0.2,
    );
  });
}

List<PortDevice> generateHostDevices(int count) {
  return List.generate(count, (i) {
    final portId = 'slotA_port${i + 1}';
    return PortDevice(
      portId: portId,
      deviceName: 'Switch-${i + 1}',
      deviceType: 'Switch',
      deviceIp: '10.0.1.${i + 1}',
      connectionStatus: i == 0 ? 1 : 0,
      deviceStatus: true,
    );
  });
}

List<PortDevice> generateDpuDevices(int count) {
  final slots = ['slotA', 'slotB'];
  return List.generate(count.clamp(0, 2), (i) {
    return PortDevice(
      portId: slots[i],
      deviceName: 'Switch-${String.fromCharCode(65 + i)}',
      deviceType: 'Switch',
      deviceIp: '10.0.2.${i + 1}',
      connectionStatus: 1,
      deviceStatus: true,
    );
  });
}
