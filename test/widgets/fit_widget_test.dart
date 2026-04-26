import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_topology_view/device_topology_view.dart';

void main() {
  testWidgets('without fit, no FittedBox is inserted (overflow path)',
      (tester) async {
    // Match the surface to the strategy minimum so positioned children don't
    // visibly overflow (which would trip render-tree asserts in tests).
    await tester.binding.setSurfaceSize(const Size(1500, 800));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: DeviceTopologyView(
            size: const Size(600, 400),
            deviceType: DeviceType.switch_,
            format: Switch28P(),
            portDevices: const [],
            portStatusMap: const {},
            centerLabel: 'sw',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(DeviceTopologyView),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('with fit: scaleDown, content fits inside the viewport',
      (tester) async {
    const viewport = Size(600, 400);
    await tester.binding.setSurfaceSize(viewport);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: DeviceTopologyView(
            size: viewport,
            deviceType: DeviceType.switch_,
            format: Switch28P(),
            portDevices: const [],
            portStatusMap: const {},
            centerLabel: 'sw',
            fit: BoxFit.scaleDown,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final fittedBox = find.descendant(
      of: find.byType(DeviceTopologyView),
      matching: find.byType(FittedBox),
    );
    expect(fittedBox, findsOneWidget);
    final fittedBoxSize = tester.getSize(fittedBox);
    expect(fittedBoxSize.width, lessThanOrEqualTo(viewport.width));
    expect(fittedBoxSize.height, lessThanOrEqualTo(viewport.height));
  });

  testWidgets('with fit null (default), no FittedBox is inserted',
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
            centerLabel: 'sw',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(DeviceTopologyView),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
  });
}
