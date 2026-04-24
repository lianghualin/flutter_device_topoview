import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_topology_view/device_topology_view.dart';
import 'package:device_topology_view/src/models/port.dart';
import 'package:device_topology_view/src/strategies/switch_rectangle_layout_strategy.dart';
import 'package:device_topology_view/src/widgets/center_device_widget.dart';

void main() {
  group('SwitchRectangleLayoutStrategy.calculateCenterLayout', () {
    test('centers chassis vertically in the viewport', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);

      final layout = strategy.calculateCenterLayout(viewportSize, format);

      // centerSize in circle strategy = 500 * scaleFactor where
      // scaleFactor = (viewportSize.width / viewportSize.height).clamp(0.5, 1.0)
      // For 1500/1000 = 1.5 → clamped to 1.0 → centerSize = 500.
      expect(layout.size, closeTo(500, 0.01));

      // Rectangle strategy centers posY vertically: (H - centerSize) / 2.
      final expectedPosY = (1000 - layout.size) / 2;
      expect(layout.position.dy, closeTo(expectedPosY, 0.01));

      // posX is unchanged from the circle strategy: (W - centerSize) / 2.
      final expectedPosX = (1500 - layout.size) / 2;
      expect(layout.position.dx, closeTo(expectedPosX, 0.01));
    });

    test('inflates contentWidth/Height to minimums when viewport is small', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      // Well below the 1500x800 minimums used by SwitchLayoutStrategy.
      final viewportSize = const Size(600, 400);

      final layout = strategy.calculateCenterLayout(viewportSize, format);

      // contentHeight is inflated to 800, so centered posY = (800 - size) / 2.
      final expectedPosY = (800 - layout.size) / 2;
      expect(layout.position.dy, closeTo(expectedPosY, 0.01));
    });
  });

  group('SwitchRectangleLayoutStrategy.calculatePortPositions', () {
    test('returns one Port per port in the format with package-derived X/Y', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);

      final ports = strategy.calculatePortPositions(center, format, {});

      expect(ports.length, 28);
      // Sorted by portNumber ascending, 1..28.
      for (int i = 0; i < ports.length; i++) {
        expect(ports[i].portNumber, i + 1);
      }
      // Each port has non-zero width and height.
      expect(ports.every((p) => p.width > 0 && p.height > 0), isTrue);
    });

    test('dims stacked-part ports outside the selected part', () {
      final strategy = SwitchRectangleLayoutStrategy(
        stackedSwitchSelectedPart: 1,
      );
      final format = Switch48PStacked();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);

      final ports = strategy.calculatePortPositions(center, format, {});

      // Part 1 ports (1..24) are fully opaque; part 2 ports (25..48) are dimmed.
      expect(
        ports.where((p) => p.portNumber != null && p.portNumber! <= 24).every(
              (p) => p.opacity == 1.0,
            ),
        isTrue,
      );
      expect(
        ports.where((p) => p.portNumber != null && p.portNumber! > 24).every(
              (p) => p.opacity == 0.3,
            ),
        isTrue,
      );
    });
  });

  group('SwitchRectangleLayoutStrategy column grid', () {
    test('splits ports into top (odd) and bottom (even) rows', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});

      final topRow = strategy.debugTopRowPorts(ports);
      final bottomRow = strategy.debugBottomRowPorts(ports);

      expect(topRow.length, 14);
      expect(bottomRow.length, 14);
      expect(topRow.every((p) => (p.portNumber ?? 0).isOdd), isTrue);
      expect(bottomRow.every((p) => (p.portNumber ?? 0).isEven), isTrue);
    });

    test('evenly distributes column X positions across the port range', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final topRow = strategy.debugTopRowPorts(ports);

      final columnXs = strategy.debugColumnXs(topRow);

      expect(columnXs.length, topRow.length);
      // Evenly spaced: successive differences are all equal.
      final step = columnXs[1] - columnXs[0];
      for (int i = 1; i < columnXs.length; i++) {
        expect(columnXs[i] - columnXs[i - 1], closeTo(step, 0.01));
      }
      // First column sits at the leftmost port X; last at the rightmost.
      final firstPortX = topRow.first.position.dx + topRow.first.width / 2;
      final lastPortX = topRow.last.position.dx + topRow.last.width / 2;
      expect(columnXs.first, closeTo(firstPortX, 0.01));
      expect(columnXs.last, closeTo(lastPortX, 0.01));
    });
  });

  group('SwitchRectangleLayoutStrategy.calculateDevicePositions', () {
    // ---- setup helpers --------------------------------------------------
    ({CenterDeviceLayout center, List<Port> ports})
        buildLayout(SwitchRectangleLayoutStrategy strategy) {
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      return (center: center, ports: ports);
    }

    PortDevice green(int port) => PortDevice(
          portId: 'p$port',
          portNumber: port,
          deviceName: 'Dev$port',
          deviceType: 'Switch',
          deviceIp: '10.0.0.$port',
          exploreDevName: 'Dev$port', // matches baseline → matched
          exploreDevIp: '10.0.0.$port',
          connectionStatus: 1,
        );
    PortDevice blackOnly(int port) => PortDevice(
          portId: 'p$port',
          portNumber: port,
          deviceName: 'Dev$port',
          deviceType: 'Switch',
          connectionStatus: 0, // no explore
        );
    PortDevice redOnly(int port) => PortDevice(
          portId: 'p$port',
          portNumber: port,
          deviceName: 'Dev$port',
          deviceType: 'Switch',
          connectionStatus: -1, // probed / explore-only
        );
    PortDevice mismatch(int port) => PortDevice(
          portId: 'p$port',
          portNumber: port,
          deviceName: 'BaselineDev$port',
          deviceType: 'Switch',
          deviceIp: '10.0.0.$port',
          exploreDevName: 'DiscoveredDev$port',
          exploreDevIp: '192.168.0.$port',
          connectionStatus: 0,
        );

    test('green-only: actual slot filled, baseline slot empty', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [green(1)],
        layout.ports,
      );

      expect(positions.baselineDevices, isEmpty);
      expect(positions.exploreDevices.length, 1);
      expect(positions.exploreDevices.first.device.portNumber, 1);
    });

    test('black-only: baseline slot filled, actual slot empty', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [blackOnly(3)],
        layout.ports,
      );

      expect(positions.baselineDevices.length, 1);
      expect(positions.exploreDevices, isEmpty);
      expect(positions.baselineDevices.first.device.portNumber, 3);
    });

    test('red-only: actual slot filled with the probed device', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [redOnly(5)],
        layout.ports,
      );

      expect(positions.baselineDevices, isEmpty);
      expect(positions.exploreDevices.length, 1);
      expect(positions.exploreDevices.first.device.portNumber, 5);
    });

    test('mismatch: both slots filled for the same port', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [mismatch(7)],
        layout.ports,
      );

      expect(positions.baselineDevices.length, 1);
      expect(positions.exploreDevices.length, 1);
      expect(positions.baselineDevices.first.device.portNumber, 7);
      expect(positions.exploreDevices.first.device.portNumber, 7);
    });

    test('odd ports land in the top section, even in the bottom', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [green(1), green(2)],
        layout.ports,
      );

      final centerTop = layout.center.position.dy;
      final centerBottom = centerTop + layout.center.size;
      final p1 = positions.exploreDevices.firstWhere(
        (d) => d.device.portNumber == 1,
      );
      final p2 = positions.exploreDevices.firstWhere(
        (d) => d.device.portNumber == 2,
      );
      expect(p1.position.dy, lessThan(centerTop),
          reason: 'odd port device goes above chassis');
      expect(p2.position.dy, greaterThan(centerBottom),
          reason: 'even port device goes below chassis');
    });

    test('actual slot is closer to chassis than outer (baseline) slot', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [mismatch(1)], // both tiers on port 1 (top section)
        layout.ports,
      );

      final actual = positions.exploreDevices.first;
      final baseline = positions.baselineDevices.first;
      final centerTop = layout.center.position.dy;
      // Both above the chassis; the actual icon is nearer the chassis top.
      expect(actual.position.dy, lessThan(centerTop));
      expect(baseline.position.dy, lessThan(actual.position.dy));
    });

    test('isConfig strips explore devices; baseline fills outer slot only', () {
      final strategy = SwitchRectangleLayoutStrategy(isConfig: true);
      final layout = buildLayout(strategy);
      final positions = strategy.calculateDevicePositions(
        const Size(1500, 1000),
        layout.center,
        [green(1), mismatch(3)],
        layout.ports,
      );

      // All devices appear on the baseline (outer) slot, none on actual.
      expect(positions.exploreDevices, isEmpty);
      expect(positions.baselineDevices.length, 2);
    });
  });
}
