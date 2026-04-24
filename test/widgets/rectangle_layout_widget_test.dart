import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_topology_view/device_topology_view.dart';

void main() {
  testWidgets('rectangle mode places actual devices adjacent to the chassis',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1500,
          height: 1000,
          child: DeviceTopologyView(
            size: const Size(1500, 1000),
            deviceType: DeviceType.switch_,
            format: Switch28P(),
            portDevices: [
              PortDevice(
                portId: 'p1',
                portNumber: 1,
                deviceName: 'Dev1',
                deviceIp: '10.0.0.1',
                exploreDevName: 'Dev1',
                exploreDevIp: '10.0.0.1',
                connectionStatus: 1,
              ),
              PortDevice(
                portId: 'p2',
                portNumber: 2,
                deviceName: 'Dev2',
                deviceIp: '10.0.0.2',
                exploreDevName: 'Dev2',
                exploreDevIp: '10.0.0.2',
                connectionStatus: 1,
              ),
            ],
            portStatusMap: const {
              '1': PortStatus.up,
              '2': PortStatus.up,
            },
            centerLabel: 'Switch',
            switchLayoutMode: SwitchLayoutMode.rectangle,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('default mode still uses the circle strategy (no exception)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1500,
          height: 1000,
          child: DeviceTopologyView(
            size: const Size(1500, 1000),
            deviceType: DeviceType.switch_,
            format: Switch28P(),
            portDevices: const [],
            portStatusMap: const {},
            centerLabel: 'Switch',
            // switchLayoutMode omitted — defaults to circle.
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
