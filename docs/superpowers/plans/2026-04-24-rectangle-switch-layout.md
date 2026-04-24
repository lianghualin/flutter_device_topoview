# Rectangle Switch Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `SwitchLayoutMode.rectangle` layout that arranges floating devices in columns above and below the switch chassis instead of in two concentric rings, while leaving today's circle layout untouched.

**Architecture:** New `SwitchRectangleLayoutStrategy` class implementing `DeviceLayoutStrategy`, sibling to `SwitchLayoutStrategy`. A new `switchLayoutMode` parameter on `DeviceTopologyView` picks which strategy to instantiate in `_createStrategy()`. All other public API and existing strategies are unchanged.

**Tech Stack:** Flutter 3.10+ / Dart 3.0+, existing internal classes (`DeviceLayoutStrategy`, `ConnectionLine`, `ConnectionsPainter`, `DevFloat`, `SwitchDeviceView.getPortPositions()` from `flutter_switch_device`), `flutter_test`.

**Source spec:** `docs/superpowers/specs/2026-04-24-rectangle-switch-layout-design.md`

---

## File Structure

**New files**

| Path | Responsibility |
|---|---|
| `lib/src/models/switch_layout_mode.dart` | Public `SwitchLayoutMode` enum (`circle`, `rectangle`). |
| `lib/src/strategies/switch_rectangle_layout_strategy.dart` | New strategy; implements `DeviceLayoutStrategy` for rectangle mode. Overrides `calculateCenterLayout` to center the chassis; lays devices in top/bottom column sections. |
| `test/strategies/switch_rectangle_layout_strategy_test.dart` | Unit tests for the strategy (center layout, column placement, 4 situations, config, stacked filtering, connections). |
| `test/widgets/rectangle_layout_widget_test.dart` | Widget test verifying `DeviceTopologyView` dispatches to the right strategy based on `switchLayoutMode`. |

**Modified files**

| Path | Change |
|---|---|
| `lib/device_topology_view.dart` | Add `export 'src/models/switch_layout_mode.dart';`. |
| `lib/src/device_topology_view.dart` | Add `switchLayoutMode` field (default `.circle`); instantiate the new strategy when mode is `.rectangle` and deviceType is `switch_`; wrap the `SwitchDeviceView` in the rectangle-mode half-chassis clip when the format is stacked. |
| `example/lib/app.dart` | Hold a `_switchLayoutMode` state field; pass it to `DeviceTopologyView`; forward toggle callback to control panel. |
| `example/lib/controls/control_panel.dart` | Add a segmented toggle for the layout mode (Circle / Rectangle), visible only when `deviceType == DeviceType.switch_`. |
| `pubspec.yaml` | Bump version `1.3.4` → `1.4.0`. |
| `CHANGELOG.md` | Add `## 1.4.0` entry describing the new mode. |

**Not touched**
- `lib/src/strategies/switch_layout_strategy.dart` (circle layout — zero changes).
- `lib/src/strategies/host_layout_strategy.dart`, `agent_layout_strategy.dart`, `slot_based_layout_strategy.dart`.
- `lib/src/models/connection_line.dart`, `lib/src/widgets/connections_painter.dart`, `dev_layer.dart`, `port_widget.dart`, `center_device_widget.dart`.
- All `lib/src/widgets/floating_devices/*.dart`.

---

## Task 1: Add `SwitchLayoutMode` enum and export

**Files:**
- Create: `lib/src/models/switch_layout_mode.dart`
- Modify: `lib/device_topology_view.dart`

- [ ] **Step 1: Create the enum file.**

Write `lib/src/models/switch_layout_mode.dart`:

```dart
/// Chooses how floating devices are laid out around a switch center.
///
/// Applies only when `deviceType == DeviceType.switch_`. Host and agent
/// device types ignore this.
enum SwitchLayoutMode {
  /// Two concentric rings: inner = real/explored devices, outer = baseline/config.
  /// This is the original and default layout.
  circle,

  /// Columns above and below the chassis. Each column has two slots:
  /// the slot adjacent to the chassis holds the real/explored device,
  /// the outer slot (at the screen edge) holds the baseline/config device.
  rectangle,
}
```

- [ ] **Step 2: Export the enum from the library's public entry point.**

Edit `lib/device_topology_view.dart`. Locate the existing `export 'src/models/port_status.dart';` line and insert a new export immediately below it:

```dart
export 'src/models/port_status.dart';
export 'src/models/switch_layout_mode.dart';
```

- [ ] **Step 3: Verify the enum compiles.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze lib/src/models/switch_layout_mode.dart lib/device_topology_view.dart`

Expected: `No issues found!`

- [ ] **Step 4: Commit.**

```bash
git add lib/src/models/switch_layout_mode.dart lib/device_topology_view.dart
git commit -m "feat: add SwitchLayoutMode enum for rectangle layout opt-in"
```

---

## Task 2: Scaffold `SwitchRectangleLayoutStrategy` with centered chassis layout (TDD)

**Files:**
- Create: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Create: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write the failing test for `calculateCenterLayout`.**

Write `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart';
import 'package:device_topology_view/src/strategies/switch_rectangle_layout_strategy.dart';

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
}
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `Error: Target of URI doesn't exist: 'package:device_topology_view/src/strategies/switch_rectangle_layout_strategy.dart'`.

- [ ] **Step 3: Scaffold the strategy class with the centered `calculateCenterLayout` and stubs for the rest.**

Write `lib/src/strategies/switch_rectangle_layout_strategy.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart' hide PortStatus;

import '../models/connection_line.dart';
import '../models/port.dart';
import '../models/port_device.dart';
import '../models/port_status.dart';
import '../widgets/center_device_widget.dart';
import '../widgets/floating_devices/dev_float.dart';
import 'device_layout_strategy.dart';

/// Layout strategy for switch topology views in rectangle mode.
///
/// Places floating devices in column sections above and below the chassis
/// instead of in two concentric rings. The chassis itself is rendered
/// vertically centered in the viewport. See the design spec at
/// `docs/superpowers/specs/2026-04-24-rectangle-switch-layout-design.md`.
class SwitchRectangleLayoutStrategy extends DeviceLayoutStrategy {
  final bool isConfig;
  final int stackedSwitchSelectedPart;
  final double labelBottomPadding;

  static const double _minWidth = 1500.0;
  static const double _minHeight = 800.0;

  SwitchRectangleLayoutStrategy({
    this.isConfig = false,
    this.stackedSwitchSelectedPart = 0,
    this.labelBottomPadding = 40.0,
  });

  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, Object format) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // Cache viewport size for use by calculatePortPositions.
    _cachedViewportSize = Size(contentWidth, contentHeight);

    // Same scaleFactor / centerSize derivation as the circle strategy.
    double scaleFactor = contentWidth / contentHeight;
    scaleFactor = scaleFactor.clamp(0.5, 1.0);
    final double centerSize = 500.0 * scaleFactor;

    // Centered vertically (rectangle-specific override). Horizontal
    // centering matches the circle strategy.
    final double posX = (contentWidth - centerSize) / 2;
    final double posY = (contentHeight - centerSize) / 2;

    return CenterDeviceLayout(
      position: Offset(posX, posY),
      size: centerSize,
    );
  }

  // Cached in calculateCenterLayout; read in calculatePortPositions.
  Size _cachedViewportSize = Size.zero;

  // ---------------------------------------------------------------------------
  // Placeholders — to be implemented in later tasks.
  // ---------------------------------------------------------------------------

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    Object format,
    Map<String, PortStatus> statusMap,
  ) {
    throw UnimplementedError('Task 3: calculatePortPositions');
  }

  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports, {
    Size? actualViewport,
  }) {
    throw UnimplementedError('Task 5: calculateDevicePositions');
  }

  @override
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  ) {
    throw UnimplementedError('Task 6: buildFloatingDevices');
  }

  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    throw UnimplementedError('Task 7: generateConnections');
  }

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    throw UnimplementedError('Task 7: generateExploreConnections');
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: both tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: scaffold SwitchRectangleLayoutStrategy with centered chassis layout"
```

---

## Task 3: Implement `calculatePortPositions`

The rectangle strategy reads port center positions from the same source the circle strategy uses (`SwitchDeviceView.getPortPositions`), but applies rectangle-specific stacked-part dimming. Logic is intentionally duplicated from `SwitchLayoutStrategy` so the existing file stays untouched.

**Files:**
- Modify: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write the failing test.**

Append to `test/strategies/switch_rectangle_layout_strategy_test.dart` inside the top-level `main()` function:

```dart
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
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `UnimplementedError: Task 3: calculatePortPositions`.

- [ ] **Step 3: Implement `calculatePortPositions`.**

In `lib/src/strategies/switch_rectangle_layout_strategy.dart`, replace the `calculatePortPositions` placeholder with the implementation below, and add the two private helpers at the bottom of the class.

```dart
  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    Object format,
    Map<String, PortStatus> statusMap,
  ) {
    if (format is! SwitchFormat) {
      return [];
    }

    final SwitchFormat switchFormat = format;
    final int? validPortsNum = switchFormat.validPortsNum;

    final Map<int, Offset> portCenters = SwitchDeviceView.getPortPositions(
      switchFormat,
      _cachedViewportSize,
    );

    final double cs = _packageCenterSize(switchFormat, _cachedViewportSize);
    final double portWidth = _packagePortWidth(switchFormat, cs);
    final double portHeight = portWidth * 0.75;

    final List<Port> ports = [];

    for (final entry in portCenters.entries) {
      final int i = entry.key;
      final Offset portCenter = entry.value;
      final bool isInvalid = validPortsNum != null && i > validPortsNum;

      final PortStatus? portStatus = statusMap[i.toString()];
      final bool? isUp =
          portStatus != null ? _portStatusToBool(portStatus) : null;

      double opacity = 1.0;
      if (switchFormat.isStacked) {
        if (stackedSwitchSelectedPart == 1) {
          opacity = (i >= 1 && i <= 24) ? 1.0 : 0.3;
        } else if (stackedSwitchSelectedPart == 2) {
          opacity = (i >= 25 && i <= 48) ? 1.0 : 0.3;
        } else {
          opacity = 0.3;
        }
      }

      ports.add(Port(
        position: Offset(
          portCenter.dx - portWidth / 2,
          portCenter.dy - portHeight / 2,
        ),
        portNumber: i,
        width: portWidth,
        height: portHeight,
        isUp: isUp,
        isInvalid: isInvalid,
        opacity: opacity,
      ));
    }

    ports.sort((a, b) => (a.portNumber ?? 0).compareTo(b.portNumber ?? 0));
    return ports;
  }

  static double _packageCenterSize(SwitchFormat format, Size viewportSize) {
    final scaleX = viewportSize.width / format.minWidth;
    final scaleY = viewportSize.height / format.minHeight;
    return 500.0 * math.min(scaleX, scaleY);
  }

  static double _packagePortWidth(SwitchFormat format, double cs) {
    final allX = <double>[
      for (final o in format.oddPortOffsetR) o.dx,
      for (final o in format.evenPortOffsetR) o.dx,
    ]..sort();
    if (allX.length < 2) return cs * 0.04;
    double minSpacing = double.infinity;
    for (int i = 1; i < allX.length; i++) {
      final spacing = allX[i] - allX[i - 1];
      if (spacing > 0 && spacing < minSpacing) {
        minSpacing = spacing;
      }
    }
    final rawWidth = cs * minSpacing * 0.8;
    return rawWidth.clamp(10.0, 25.0);
  }

  static bool? _portStatusToBool(PortStatus status) {
    switch (status) {
      case PortStatus.up:
        return true;
      case PortStatus.down:
        return false;
      case PortStatus.unknown:
        return null;
    }
  }
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: implement port positioning for SwitchRectangleLayoutStrategy"
```

---

## Task 4: Split ports into top/bottom rows and compute column X positions

This task introduces the column-grid math (purely internal helpers) so `calculateDevicePositions` in Task 5 has clean building blocks.

**Files:**
- Modify: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write failing tests for the column-layout helpers.**

Append inside the top-level `main()` of `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to confirm they fail.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `The method 'debugTopRowPorts' isn't defined`.

- [ ] **Step 3: Add the helpers to the strategy.**

Append inside the `SwitchRectangleLayoutStrategy` class, just before the closing `}`:

```dart
  // ---------------------------------------------------------------------------
  // Column-grid helpers (internal, exposed for testing via `debug*` shims)
  // ---------------------------------------------------------------------------

  List<Port> _topRowPorts(List<Port> ports) => ports
      .where((p) => p.portNumber != null && p.portNumber!.isOdd)
      .toList()
    ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

  List<Port> _bottomRowPorts(List<Port> ports) => ports
      .where((p) => p.portNumber != null && p.portNumber!.isEven)
      .toList()
    ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

  /// Returns column center-X positions, evenly distributed from the leftmost
  /// to the rightmost port in [rowPorts]. `rowPorts` must be sorted by X.
  List<double> _columnXs(List<Port> rowPorts) {
    if (rowPorts.isEmpty) return const [];
    if (rowPorts.length == 1) {
      return [rowPorts.first.position.dx + rowPorts.first.width / 2];
    }
    final double first = rowPorts.first.position.dx + rowPorts.first.width / 2;
    final double last = rowPorts.last.position.dx + rowPorts.last.width / 2;
    final double step = (last - first) / (rowPorts.length - 1);
    return List<double>.generate(
      rowPorts.length,
      (i) => first + step * i,
    );
  }

  // --- @visibleForTesting shims (public-ish) --------------------------------
  @visibleForTesting
  List<Port> debugTopRowPorts(List<Port> ports) => _topRowPorts(ports);

  @visibleForTesting
  List<Port> debugBottomRowPorts(List<Port> ports) => _bottomRowPorts(ports);

  @visibleForTesting
  List<double> debugColumnXs(List<Port> rowPorts) => _columnXs(rowPorts);
```

Add the import for `@visibleForTesting` at the top of the file (if not already present):

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: add column-grid helpers to SwitchRectangleLayoutStrategy"
```

---

## Task 5: Implement `calculateDevicePositions` with slot placement and the 4 situations

**Files:**
- Modify: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write failing tests for all 4 connection situations.**

Append inside the top-level `main()` of `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to confirm they fail.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `UnimplementedError: Task 5: calculateDevicePositions`.

- [ ] **Step 3: Implement `calculateDevicePositions`.**

Replace the `calculateDevicePositions` placeholder in `lib/src/strategies/switch_rectangle_layout_strategy.dart` with:

```dart
  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports, {
    Size? actualViewport,
  }) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // --- Filter devices (config + stacked) -----------------------------
    List<PortDevice> filtered = List.of(devices);
    if (isConfig) {
      filtered = filtered.where((d) => d.connectionStatus >= 0).toList();
    }
    if (_isStacked(devices)) {
      if (stackedSwitchSelectedPart == 1) {
        filtered = filtered
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 1 &&
                d.portNumber! <= 24)
            .toList();
      } else if (stackedSwitchSelectedPart == 2) {
        filtered = filtered
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 25 &&
                d.portNumber! <= 48)
            .toList();
      } else {
        filtered = [];
      }
    }
    if (filtered.isEmpty) {
      return const DevicePositions(
        baselineDevices: [],
        exploreDevices: [],
      );
    }

    // --- Precompute column X lookups per row ---------------------------
    final topRow = _topRowPorts(ports);
    final bottomRow = _bottomRowPorts(ports);
    final topColumnXs = _columnXs(topRow);
    final bottomColumnXs = _columnXs(bottomRow);
    final Map<int, double> columnXByPort = {};
    for (int i = 0; i < topRow.length; i++) {
      final num = topRow[i].portNumber;
      if (num != null) columnXByPort[num] = topColumnXs[i];
    }
    for (int i = 0; i < bottomRow.length; i++) {
      final num = bottomRow[i].portNumber;
      if (num != null) columnXByPort[num] = bottomColumnXs[i];
    }

    // --- Section vertical extents --------------------------------------
    final double topSectionTop = 0.0;
    final double topSectionBottom = center.position.dy;
    final double bottomSectionTop = center.position.dy + center.size;
    final double bottomSectionBottom = contentHeight;

    // --- Device size tiers ---------------------------------------------
    final double visibleWidth = actualViewport?.width ?? contentWidth;
    final double visibleHeight = actualViewport?.height ?? contentHeight;
    final int deviceCount = filtered.length;
    final double canvasMinDim = math.min(contentWidth, contentHeight);

    double sizeFactor;
    double minSize;
    double maxSize;
    if (deviceCount <= 3) {
      sizeFactor = 0.10;
      minSize = 55;
      maxSize = 100;
    } else if (deviceCount <= 6) {
      sizeFactor = 0.08;
      minSize = 45;
      maxSize = 85;
    } else {
      sizeFactor = 0.065;
      minSize = 40;
      maxSize = 75;
    }
    double baseDeviceSize =
        (canvasMinDim * sizeFactor).clamp(minSize, maxSize);
    final double viewportMinDim = math.min(visibleWidth, visibleHeight);
    if (viewportMinDim < canvasMinDim) {
      final double boost =
          math.sqrt(canvasMinDim / viewportMinDim).clamp(1.0, 1.4);
      baseDeviceSize = (baseDeviceSize * boost).clamp(minSize, maxSize * 1.3);
    }
    final double baselineDeviceSize = baseDeviceSize * 0.7;

    // --- Per-device placement ------------------------------------------
    final List<PositionedDevice> baselineOut = [];
    final List<PositionedDevice> exploreOut = [];

    // A port has explore data if its exploreDevName or exploreDevIp is set
    // AND explore differs from baseline. When both tiers exist, the
    // baseline sits in the outer slot and the actual (explore) in the
    // adjacent slot. When only one tier exists, baseline goes outer if it
    // is status 0; otherwise the baseline PortDevice goes to the actual
    // (adjacent) slot as the "real" device (green or red).
    for (final dev in filtered) {
      final int portNum = dev.portNumber ?? 0;
      final bool isTop = portNum.isOdd;
      final double columnX = columnXByPort[portNum] ?? center.position.dx;

      final bool hasExplore =
          ((dev.exploreDevName != null && dev.exploreDevName!.isNotEmpty) ||
              (dev.exploreDevIp != null && dev.exploreDevIp!.isNotEmpty)) &&
              !(dev.deviceName == dev.exploreDevName &&
                  dev.deviceIp == dev.exploreDevIp);
      final bool baselineIsReal =
          dev.connectionStatus == 1 || dev.connectionStatus == -1;

      double actualDeviceSize = baseDeviceSize;
      if (dev.deviceType != 'Switch') actualDeviceSize *= 0.8;
      double baselineIconSize = baselineDeviceSize;
      if (dev.deviceType != 'Switch') baselineIconSize *= 0.8;

      // Slot Y positions — outer slot sits nearer the screen edge; actual
      // slot sits nearer the chassis. 55/45 vertical split of the section.
      double outerY;
      double actualY;
      if (isTop) {
        final double sectionH = topSectionBottom - topSectionTop;
        outerY = topSectionTop + sectionH * 0.27;
        actualY = topSectionTop + sectionH * 0.72;
      } else {
        final double sectionH = bottomSectionBottom - bottomSectionTop;
        outerY = bottomSectionTop + sectionH * 0.73;
        actualY = bottomSectionTop + sectionH * 0.28;
      }
      // Clamp so icons stay inside the viewport.
      outerY = outerY.clamp(
        baselineIconSize / 2 + 10,
        contentHeight - baselineIconSize / 2 - 10 - labelBottomPadding,
      );
      actualY = actualY.clamp(
        actualDeviceSize / 2 + 10,
        contentHeight - actualDeviceSize / 2 - 10 - labelBottomPadding,
      );

      if (hasExplore) {
        // Mismatch: baseline in outer slot, explore (constructed from
        // explore* fields) in actual slot. Both use the same port column.
        baselineOut.add(PositionedDevice(
          position: Offset(columnX, outerY),
          size: baselineIconSize,
          device: dev,
        ));
        // Re-wrap as a PortDevice representing the explore side, so the
        // builder can use explore name/IP as the label. The original
        // `dev` is preserved in baselineOut so its baseline name/IP
        // render in the outer slot.
        final PortDevice exploreDev = PortDevice(
          portId: dev.portId,
          portNumber: dev.portNumber,
          deviceName: dev.deviceName,
          deviceType: dev.deviceType,
          deviceIp: dev.deviceIp,
          exploreDevName: dev.exploreDevName,
          exploreDevIp: dev.exploreDevIp,
          connectionStatus: dev.connectionStatus,
          deviceStatus: dev.deviceStatus,
          exploreInboundUtilization: dev.exploreInboundUtilization,
          exploreOutboundUtilization: dev.exploreOutboundUtilization,
        );
        exploreOut.add(PositionedDevice(
          position: Offset(columnX, actualY),
          size: actualDeviceSize,
          device: exploreDev,
        ));
      } else if (baselineIsReal) {
        // Green-only (status 1) or red-only (status -1): single real
        // device, adjacent slot. Outer slot stays empty.
        exploreOut.add(PositionedDevice(
          position: Offset(columnX, actualY),
          size: actualDeviceSize,
          device: dev,
        ));
      } else {
        // Black-only (status 0, no explore): baseline-only, outer slot.
        baselineOut.add(PositionedDevice(
          position: Offset(columnX, outerY),
          size: baselineIconSize,
          device: dev,
        ));
      }
    }

    return DevicePositions(
      baselineDevices: baselineOut,
      exploreDevices: exploreOut,
    );
  }

  /// Stacked if any device port number exceeds 28 (non-stacked formats top
  /// out at 28). Matches the heuristic used by the circle strategy.
  bool _isStacked(List<PortDevice> devices) {
    return devices.any(
        (d) => d.portNumber != null && d.portNumber! > 28);
  }
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: implement rectangle device placement across the 4 connection situations"
```

---

## Task 6: Implement `buildFloatingDevices`

The mapping from `PositionedDevice` to a `DevFloat` is almost identical to the circle strategy's. To keep today's file untouched (per the spec), we duplicate the `_buildDevFloat` dispatch inside the rectangle strategy.

**Files:**
- Modify: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write the failing test.**

Append to `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
  group('SwitchRectangleLayoutStrategy.buildFloatingDevices', () {
    test('produces one DevFloat per positioned device; outer first, actual second', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
            portId: 'p3',
            portNumber: 3,
            deviceName: 'BaseA',
            deviceIp: '10.0.0.3',
            exploreDevName: 'DiscoveredA',
            exploreDevIp: '192.168.0.3',
            connectionStatus: 0,
          ),
        ],
        ports,
      );

      final floats = strategy.buildFloatingDevices(positions, const []);
      // 1 baseline + 1 explore = 2 DevFloats.
      expect(floats.length, 2);
      // Baseline first, explore second (same ordering as circle strategy).
      expect(floats[0].connectedPortNum, 3);
      expect(floats[1].connectedPortNum, 3);
    });
  });
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `UnimplementedError: Task 6: buildFloatingDevices`.

- [ ] **Step 3: Add the imports for the four floating-device widgets at the top of `switch_rectangle_layout_strategy.dart`** (below the existing imports):

```dart
import '../widgets/floating_devices/agent_dev_float.dart';
import '../widgets/floating_devices/host_dev_float.dart';
import '../widgets/floating_devices/switch_dev_float.dart';
import '../widgets/floating_devices/unknown_dev_float.dart';
```

- [ ] **Step 4: Implement `buildFloatingDevices` and the `_buildDevFloat` dispatch.**

Replace the `buildFloatingDevices` placeholder with:

```dart
  @override
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  ) {
    final List<DevFloat> result = [];

    // Outer-slot (baseline) devices first — preserves the same ordering
    // the widget layer uses to slice the list into baseline/explore.
    for (final pd in positions.baselineDevices) {
      result.add(_buildDevFloat(pd, pd.device.deviceName, isReal: false));
    }

    // Actual-slot (real/explored) devices second.
    for (final pd in positions.exploreDevices) {
      final dev = pd.device;
      String label;
      if (dev.connectionStatus == 1 || dev.connectionStatus == -1) {
        label = dev.deviceName;
      } else {
        label = (dev.exploreDevName != null && dev.exploreDevName!.isNotEmpty)
            ? dev.exploreDevName!
            : (dev.exploreDevIp ?? dev.deviceName);
      }
      result.add(_buildDevFloat(
        pd,
        label,
        isReal: true,
        inboundUtilization: dev.exploreInboundUtilization,
        outboundUtilization: dev.exploreOutboundUtilization,
      ));
    }
    return result;
  }

  DevFloat _buildDevFloat(
    PositionedDevice pd,
    String label, {
    bool isReal = false,
    double? inboundUtilization,
    double? outboundUtilization,
  }) {
    final dev = pd.device;
    final int portNum = dev.portNumber ?? 0;

    switch (dev.deviceType) {
      case 'Switch':
        return SwitchDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
        );
      case 'MMI':
      case 'Host':
        return HostDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
        );
      case 'Agent':
        return AgentDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          totalPfs: 0,
          usedPfs: 0,
          deviceStatus: isConfig ? true : dev.deviceStatus,
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
        );
      default:
        String processed = label;
        if (label.contains('+') && label.split('+').length >= 2) {
          final parts = label.split('+');
          if (parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
            processed = 'Unknown Device';
          }
        }
        return UnknownDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: processed,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
        );
    }
  }
```

- [ ] **Step 5: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: build DevFloats for rectangle-mode baseline and actual slots"
```

---

## Task 7: Implement `generateConnections` and `generateExploreConnections`

**Line routing (from the spec, Section: Connections):**

- **Actual (explore-ring) lines** — always straight (`forceCurve: false`); status collapses to `1` or `-1` based on the device's `connectionStatus`.
- **Baseline (outer) lines** — straight **unless** the same port also has an actual device in `exploreDevices` (the mismatch case), in which case `forceCurve: true` so it arcs around the actual icon.
- **Config mode** — all baseline lines straight grey dashed (`isConfig: true`, `forceCurve: false`).
- **Curve direction**: use the port's column index within its row — left-half ports arc right, right-half ports arc left, so curves fan *outward* toward the viewport edge instead of into adjacent columns.

**Files:**
- Modify: `lib/src/strategies/switch_rectangle_layout_strategy.dart`
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write failing tests for connection generation.**

Append to `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
  group('SwitchRectangleLayoutStrategy.generateConnections', () {
    test('green-only port produces one straight green explore line', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
            portId: 'p1',
            portNumber: 1,
            deviceName: 'Dev1',
            deviceIp: '10.0.0.1',
            exploreDevName: 'Dev1',
            exploreDevIp: '10.0.0.1',
            connectionStatus: 1,
          ),
        ],
        ports,
      );
      final floats = strategy.buildFloatingDevices(positions, const []);
      final baseline = floats.take(positions.baselineDevices.length).toList();
      final explore = floats.skip(positions.baselineDevices.length).toList();

      final baseLines = strategy.generateConnections(ports, baseline, const []);
      final exploreLines =
          strategy.generateExploreConnections(ports, explore, const []);

      expect(baseLines, isEmpty);
      expect(exploreLines.length, 1);
      expect(exploreLines.first.status, 1);
      expect(exploreLines.first.forceCurve, isFalse);
      expect(exploreLines.first.isConfig, isFalse);
    });

    test('mismatch port: baseline line is curved black (status 0); explore is straight red', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
            portId: 'p5',
            portNumber: 5,
            deviceName: 'BaseDev5',
            deviceIp: '10.0.0.5',
            exploreDevName: 'DiscoveredDev5',
            exploreDevIp: '192.168.0.5',
            connectionStatus: 0,
          ),
        ],
        ports,
      );
      final floats = strategy.buildFloatingDevices(positions, const []);
      final baseline = floats.take(positions.baselineDevices.length).toList();
      final explore = floats.skip(positions.baselineDevices.length).toList();

      final baseLines = strategy.generateConnections(ports, baseline, const []);
      final exploreLines =
          strategy.generateExploreConnections(ports, explore, const []);

      expect(baseLines.length, 1);
      expect(baseLines.first.status, 0);
      expect(baseLines.first.forceCurve, isTrue,
          reason: 'baseline must arc around the actual icon in mismatch');
      expect(exploreLines.length, 1);
      expect(exploreLines.first.status, -1,
          reason: 'explore-mismatch is always status -1');
      expect(exploreLines.first.forceCurve, isFalse);
    });

    test('isConfig mode: baseline lines are straight, flagged isConfig', () {
      final strategy = SwitchRectangleLayoutStrategy(isConfig: true);
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
            portId: 'p3',
            portNumber: 3,
            deviceName: 'Dev3',
            connectionStatus: 0,
          ),
        ],
        ports,
      );
      final floats = strategy.buildFloatingDevices(positions, const []);
      final baseline = floats.take(positions.baselineDevices.length).toList();

      final baseLines = strategy.generateConnections(ports, baseline, const []);

      expect(baseLines.length, 1);
      expect(baseLines.first.isConfig, isTrue);
      expect(baseLines.first.forceCurve, isFalse);
    });
  });
```

- [ ] **Step 2: Run the tests to confirm they fail.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: FAIL — `UnimplementedError: Task 7: generateConnections`.

- [ ] **Step 3: Implement both generators.**

Replace the `generateConnections` and `generateExploreConnections` placeholders with:

```dart
  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    final List<ConnectionLine> result = [];
    // Set of port numbers that also have an actual (explore) device.
    // Baseline lines for these ports must curve around the actual icon.
    final Set<int> portsWithActual = _portNumbersWithActual(portDevices);

    for (final device in devices) {
      Port? matched;
      try {
        matched = ports.firstWhere(
            (p) => p.portNumber == device.connectedPortNum);
      } catch (_) {
        continue;
      }

      final Offset portPoint = Offset(
        matched.position.dx + matched.width / 2,
        matched.position.dy + matched.height / 2,
      );
      final Offset deviceCenter = Offset(device.position.dx, device.position.dy);

      // Inset endpoint slightly into the device for visual overlap,
      // matching the circle strategy's 8% inset.
      final double inset = device.size * 0.08;
      final double dx = deviceCenter.dx - portPoint.dx;
      final double dy = deviceCenter.dy - portPoint.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final Offset devicePoint = dist > 0
          ? Offset(
              deviceCenter.dx - inset * (dx / dist),
              deviceCenter.dy - inset * (dy / dist),
            )
          : deviceCenter;

      final bool mismatch = !isConfig &&
          device.connectedPortNum != 0 &&
          portsWithActual.contains(device.connectedPortNum);

      result.add(ConnectionLine(
        sourceOffset: portPoint,
        targetOffset: devicePoint,
        status: device.portstatus,
        portNumber: matched.portNumber,
        isConfig: isConfig,
        forceCurve: mismatch,
        curveDirection: _curveDirectionForPort(matched.portNumber, ports),
      ));
    }
    return result;
  }

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    final List<ConnectionLine> result = [];
    for (final device in devices) {
      Port? matched;
      try {
        matched = ports.firstWhere(
            (p) => p.portNumber == device.connectedPortNum);
      } catch (_) {
        continue;
      }

      final Offset portPoint = Offset(
        matched.position.dx + matched.width / 2,
        matched.position.dy + matched.height / 2,
      );
      final Offset deviceCenter = Offset(device.position.dx, device.position.dy);

      final int lineStatus = device.portstatus == 1 ? 1 : -1;
      result.add(ConnectionLine(
        sourceOffset: portPoint,
        targetOffset: deviceCenter,
        status: lineStatus,
        portNumber: matched.portNumber,
        isConfig: isConfig,
      ));
    }
    return result;
  }

  /// Set of port numbers for which the original input devices list has an
  /// actual (explore) device — either matched (status 1), probed
  /// (status -1), or mismatch (status 0 with explore data).
  Set<int> _portNumbersWithActual(List<PortDevice> portDevices) {
    final Set<int> result = {};
    for (final d in portDevices) {
      if (d.portNumber == null) continue;
      final bool hasExplore =
          ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
              (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
              !(d.deviceName == d.exploreDevName &&
                  d.deviceIp == d.exploreDevIp);
      final bool baselineIsReal =
          d.connectionStatus == 1 || d.connectionStatus == -1;
      if (hasExplore || baselineIsReal) {
        result.add(d.portNumber!);
      }
    }
    return result;
  }

  /// +1 or -1 — picks the side the baseline curve arcs toward. The goal
  /// is for curves to bulge *outward* (toward the viewport edge) rather
  /// than into adjacent columns. Because `ConnectionLine.paint`
  /// computes `perpX = -dy * 0.15 * curveDirection`, and `dy` flips sign
  /// between the top section (target above port → dy < 0) and the bottom
  /// section (target below port → dy > 0), the correct direction value
  /// also flips between the two sections.
  ///
  /// | Section | Left-half port | Right-half port |
  /// |---------|----------------|-----------------|
  /// | Top (odd ports)    | -1 | +1 |
  /// | Bottom (even ports)| +1 | -1 |
  int _curveDirectionForPort(int? portNumber, List<Port> allPorts) {
    if (portNumber == null) return 1;
    final bool isOdd = portNumber.isOdd;
    final List<Port> row =
        isOdd ? _topRowPorts(allPorts) : _bottomRowPorts(allPorts);
    final int index = row.indexWhere((p) => p.portNumber == portNumber);
    if (index < 0 || row.isEmpty) return 1;
    final bool leftHalf = index < row.length / 2;
    if (isOdd) {
      return leftHalf ? -1 : 1;
    } else {
      return leftHalf ? 1 : -1;
    }
  }
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/src/strategies/switch_rectangle_layout_strategy.dart test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "feat: generate rectangle-mode connection lines with context-sensitive curve"
```

---

## Task 8: Stacked-switch filtering (device-side)

Port-side filtering already happened in Task 3 (via the existing `calculatePortPositions`). Task 5 includes stacked-part filtering for devices inside `calculateDevicePositions`. This task adds tests to verify the device-side filtering behaves as the spec requires — no new production code, just coverage.

**Files:**
- Modify: `test/strategies/switch_rectangle_layout_strategy_test.dart`

- [ ] **Step 1: Write failing tests (the strategy already supports this — the tests will pass immediately if implementation is correct).**

Append to `test/strategies/switch_rectangle_layout_strategy_test.dart`:

```dart
  group('SwitchRectangleLayoutStrategy stacked-switch filtering', () {
    test('stackedSwitchSelectedPart=1 keeps only ports 1..24 devices', () {
      final strategy = SwitchRectangleLayoutStrategy(
        stackedSwitchSelectedPart: 1,
      );
      final format = Switch48PStacked();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
              portId: 'p1', portNumber: 1, deviceName: 'A', connectionStatus: 0),
          PortDevice(
              portId: 'p24',
              portNumber: 24,
              deviceName: 'B',
              connectionStatus: 0),
          PortDevice(
              portId: 'p25',
              portNumber: 25,
              deviceName: 'C',
              connectionStatus: 0),
          PortDevice(
              portId: 'p48',
              portNumber: 48,
              deviceName: 'D',
              connectionStatus: 0),
        ],
        ports,
      );

      final keptPorts = positions.baselineDevices
          .map((d) => d.device.portNumber)
          .whereType<int>()
          .toSet();
      expect(keptPorts, {1, 24});
    });

    test('stackedSwitchSelectedPart=2 keeps only ports 25..48 devices', () {
      final strategy = SwitchRectangleLayoutStrategy(
        stackedSwitchSelectedPart: 2,
      );
      final format = Switch48PStacked();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
              portId: 'p1', portNumber: 1, deviceName: 'A', connectionStatus: 0),
          PortDevice(
              portId: 'p25',
              portNumber: 25,
              deviceName: 'C',
              connectionStatus: 0),
          PortDevice(
              portId: 'p48',
              portNumber: 48,
              deviceName: 'D',
              connectionStatus: 0),
        ],
        ports,
      );

      final keptPorts = positions.baselineDevices
          .map((d) => d.device.portNumber)
          .whereType<int>()
          .toSet();
      expect(keptPorts, {25, 48});
    });

    test('stackedSwitchSelectedPart=0 removes all stacked devices', () {
      final strategy = SwitchRectangleLayoutStrategy(
        stackedSwitchSelectedPart: 0,
      );
      final format = Switch48PStacked();
      final viewportSize = const Size(1500, 1000);
      final center = strategy.calculateCenterLayout(viewportSize, format);
      final ports = strategy.calculatePortPositions(center, format, {});
      final positions = strategy.calculateDevicePositions(
        viewportSize,
        center,
        [
          PortDevice(
              portId: 'p1', portNumber: 1, deviceName: 'A', connectionStatus: 0),
          PortDevice(
              portId: 'p25',
              portNumber: 25,
              deviceName: 'B',
              connectionStatus: 0),
        ],
        ports,
      );

      expect(positions.baselineDevices, isEmpty);
      expect(positions.exploreDevices, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/strategies/switch_rectangle_layout_strategy_test.dart`

Expected: all tests PASS (the filtering logic from Task 5 already handles this). If any test fails, the Task 5 implementation is buggy — inspect the `_isStacked` + part-filter block.

- [ ] **Step 3: Commit.**

```bash
git add test/strategies/switch_rectangle_layout_strategy_test.dart
git commit -m "test: cover stacked-switch part filtering for rectangle strategy"
```

---

## Task 9: Wire `switchLayoutMode` into `DeviceTopologyView`

**Files:**
- Modify: `lib/src/device_topology_view.dart`
- Create: `test/widgets/rectangle_layout_widget_test.dart`

- [ ] **Step 1: Write the failing widget test.**

Write `test/widgets/rectangle_layout_widget_test.dart`:

```dart
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
    // Widget renders without throwing — smoke test for dispatch.
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
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test test/widgets/rectangle_layout_widget_test.dart`

Expected: FAIL — `SwitchLayoutMode` is not a known symbol on `DeviceTopologyView`, so the test file won't compile.

- [ ] **Step 3: Add the `switchLayoutMode` field and import to the widget.**

Edit `lib/src/device_topology_view.dart`.

(a) Add this import below the existing `'models/device_type.dart'` import:

```dart
import 'models/switch_layout_mode.dart';
```

(b) Add a new strategy import below the existing `'strategies/switch_layout_strategy.dart'` import:

```dart
import 'strategies/switch_rectangle_layout_strategy.dart';
```

(c) Add the new constructor parameter. Locate the existing `this.labelBottomPadding = 40.0,` line in the constructor and insert a new line immediately below it:

```dart
    this.switchLayoutMode = SwitchLayoutMode.circle,
```

(d) Add the matching field declaration. Find the existing `final double labelBottomPadding;` field (around line 59) and insert below it:

```dart
  /// Layout mode for switch topology views. Ignored for host/agent.
  /// Defaults to [SwitchLayoutMode.circle] for backwards compatibility.
  final SwitchLayoutMode switchLayoutMode;
```

(e) Update `_createStrategy()` to dispatch on the new mode. Replace the existing `case DeviceType.switch_:` branch with:

```dart
      case DeviceType.switch_:
        if (widget.switchLayoutMode == SwitchLayoutMode.rectangle) {
          _strategy = SwitchRectangleLayoutStrategy(
            isConfig: widget.isConfig,
            stackedSwitchSelectedPart: _stackedSwitchSelectedPart,
            labelBottomPadding: widget.labelBottomPadding,
          );
        } else {
          _strategy = SwitchLayoutStrategy(
            isConfig: widget.isConfig,
            stackedSwitchSelectedPart: _stackedSwitchSelectedPart,
            labelBottomPadding: widget.labelBottomPadding,
          );
        }
        break;
```

(f) Extend `didUpdateWidget` so mode changes rebuild the layout. Locate the existing condition in `didUpdateWidget`:

```dart
    if (widget.size != oldWidget.size ||
        widget.deviceType != oldWidget.deviceType ||
        widget.format != oldWidget.format ||
        widget.isConfig != oldWidget.isConfig ||
        !identical(widget.portDevices, oldWidget.portDevices) ||
        !identical(widget.portStatusMap, oldWidget.portStatusMap)) {
```

Replace it with:

```dart
    if (widget.size != oldWidget.size ||
        widget.deviceType != oldWidget.deviceType ||
        widget.format != oldWidget.format ||
        widget.isConfig != oldWidget.isConfig ||
        widget.switchLayoutMode != oldWidget.switchLayoutMode ||
        !identical(widget.portDevices, oldWidget.portDevices) ||
        !identical(widget.portStatusMap, oldWidget.portStatusMap)) {
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter test`

Expected: all tests PASS.

- [ ] **Step 5: Verify analyzer is clean.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze`

Expected: `No issues found!` (or only pre-existing warnings — no new ones).

- [ ] **Step 6: Commit.**

```bash
git add lib/src/device_topology_view.dart test/widgets/rectangle_layout_widget_test.dart
git commit -m "feat: expose switchLayoutMode on DeviceTopologyView and dispatch to new strategy"
```

---

## Task 10: Example app mode toggle

Let the example app flip between circle and rectangle so manual verification is one click away.

**Files:**
- Modify: `example/lib/app.dart`
- Modify: `example/lib/controls/control_panel.dart`

- [ ] **Step 1: Add state + callback to the app shell.**

Edit `example/lib/app.dart`:

(a) Add a field to `_AppState`, next to the other bool/int state at the top of the class (near `_isConfig`, `_showOuterRing`):

```dart
  SwitchLayoutMode _switchLayoutMode = SwitchLayoutMode.circle;
```

(b) In the `DeviceTopologyView(...)` call inside `LayoutBuilder`, insert the new argument just below `showOuterRing: _showOuterRing,`:

```dart
                  switchLayoutMode: _switchLayoutMode,
```

(c) In the `ControlPanel(...)` arguments, just below `stackedPart: _stackedPart,` insert:

```dart
              switchLayoutMode: _switchLayoutMode,
              onSwitchLayoutModeChanged: (mode) =>
                  setState(() => _switchLayoutMode = mode),
```

- [ ] **Step 2: Accept and render the toggle in the control panel.**

Edit `example/lib/controls/control_panel.dart`:

(a) Add two new constructor parameters. Locate the existing `this.onStackedPartChanged,` line and insert immediately below:

```dart
    this.switchLayoutMode = SwitchLayoutMode.circle,
    this.onSwitchLayoutModeChanged,
```

(b) Add matching field declarations. Find `final ValueChanged<int>? onStackedPartChanged;` near the top of the class and insert two new fields below it:

```dart
  final SwitchLayoutMode switchLayoutMode;
  final ValueChanged<SwitchLayoutMode>? onSwitchLayoutModeChanged;
```

(c) Add the toggle UI inside the existing control panel layout. In the `build` method, find the spot where other switch-specific controls are rendered (for example near the stacked-part dropdown — search for `onStackedPartChanged`). Insert a new `Row` there, gated on `deviceType == DeviceType.switch_`:

```dart
          if (deviceType == DeviceType.switch_) ...[
            const SizedBox(height: 8),
            const Text('Layout mode',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            SegmentedButton<SwitchLayoutMode>(
              segments: const [
                ButtonSegment(
                  value: SwitchLayoutMode.circle,
                  label: Text('Circle'),
                ),
                ButtonSegment(
                  value: SwitchLayoutMode.rectangle,
                  label: Text('Rectangle'),
                ),
              ],
              selected: {switchLayoutMode},
              onSelectionChanged: (sel) {
                if (onSwitchLayoutModeChanged != null && sel.isNotEmpty) {
                  onSwitchLayoutModeChanged!(sel.first);
                }
              },
            ),
          ],
```

- [ ] **Step 3: Launch the example app and manually verify both modes render.**

Run: `cd /Users/hualinliang/Project/device_topology_view/example && flutter run -d chrome`

Expected: example launches in Chrome with the indigo-themed topology view. Open the settings panel (top-right gear icon). When a switch scenario is active, you should see a "Layout mode" segmented button. Toggle between Circle and Rectangle. Each click should:
- Redraw the floating devices (rings ↔ columns).
- Keep the switch chassis centered-ish.
- Preserve port hover/selection spotlight behavior.
- Work on the Switch28P scenario, `isConfig` on/off, and the mismatch scenario.

If something looks visually wrong (icons clipped, columns misaligned, curves crossing neighbors), note the specific issue and fix the rectangle strategy before committing. Stacked-switch visual polish is addressed in Task 11.

- [ ] **Step 4: Commit.**

```bash
git add example/lib/app.dart example/lib/controls/control_panel.dart
git commit -m "feat(example): add Circle/Rectangle layout-mode toggle to control panel"
```

---

## Task 11: Hide the unselected half of a stacked chassis in rectangle mode

`flutter_switch_device` always renders both halves of a stacked chassis. In rectangle mode, device columns only exist for one part, so the unused half-chassis needs to be visually hidden. The simplest approach (no upstream-package change) is to overlay a white rectangle covering the unused half when `switchLayoutMode == rectangle` on a stacked format.

**Files:**
- Modify: `lib/src/device_topology_view.dart`

- [ ] **Step 1: Inspect the stacked chassis layout to determine the unused half's rect.**

The chassis is rendered by `SwitchDeviceView` at `_centerLayout.position` with size `_centerLayout.size`. For stacked formats the top half covers roughly the first 50% of the chassis height and the bottom half the latter 50%. We'll cover whichever is not the selected part.

Run: `cd /Users/hualinliang/Project/device_topology_view && grep -rn "isStacked\|stackedPart" lib/src/ | head -40`

Expected: a handful of references — enough to confirm we use `widget.format is SwitchFormat && (widget.format as SwitchFormat).isStacked` and `_stackedSwitchSelectedPart` here too.

- [ ] **Step 2: Add a helper method on `_DeviceTopologyViewState` that returns the cover rect, and overlay it in rectangle mode.**

Edit `lib/src/device_topology_view.dart`.

(a) Inside `_DeviceTopologyViewState`, add this helper near the other private helpers (e.g., above `_buildSwitchPortStatuses`):

```dart
  /// When in rectangle mode on a stacked format, returns the rect covering
  /// the unused half of the chassis so rectangle columns don't visually
  /// compete with it. Returns null when no cover is needed.
  Rect? _stackedCoverRect() {
    if (widget.switchLayoutMode != SwitchLayoutMode.rectangle) return null;
    if (widget.format is! SwitchFormat) return null;
    final sf = widget.format as SwitchFormat;
    if (!sf.isStacked) return null;
    if (_stackedSwitchSelectedPart != 1 && _stackedSwitchSelectedPart != 2) {
      return null;
    }

    final double left = _centerLayout.position.dx;
    final double width = _centerLayout.size;
    final double halfH = _centerLayout.size / 2;
    // Part 1 is the top half of the stacked chassis → cover the bottom.
    // Part 2 is the bottom half → cover the top.
    if (_stackedSwitchSelectedPart == 1) {
      return Rect.fromLTWH(
          left, _centerLayout.position.dy + halfH, width, halfH);
    } else {
      return Rect.fromLTWH(left, _centerLayout.position.dy, width, halfH);
    }
  }
```

(b) In the `build()` method, locate the top of the `Stack children:` list — specifically the `SwitchDeviceView(...)` placement. Right *after* it (inside the same `if (widget.deviceType == DeviceType.switch_ && widget.format is SwitchFormat)` block), overlay the cover. Replace the existing:

```dart
                  if (widget.deviceType == DeviceType.switch_ &&
                      widget.format is SwitchFormat)
                    SwitchDeviceView(
                      ...
                    )
```

with a list (note the wrapping `...[ ]`):

```dart
                  if (widget.deviceType == DeviceType.switch_ &&
                      widget.format is SwitchFormat) ...[
                    SwitchDeviceView(
                      size: Size(_contentWidth, _contentHeight),
                      format: widget.format as SwitchFormat,
                      portStatuses: _buildSwitchPortStatuses(),
                      isConfig: widget.isConfig,
                      onPortHover: _handlePortHover,
                      onPortHoverExit: _handlePortHoverExit,
                      onPortTap: _handlePortTap,
                      stackedPart: _stackedSwitchSelectedPart,
                      onStackedPartChanged: _handleStackedPartChanged,
                      selectedPorts: _selectedPorts,
                    ),
                    if (_stackedCoverRect() != null)
                      Positioned.fromRect(
                        rect: _stackedCoverRect()!,
                        child: const IgnorePointer(
                          child: ColoredBox(color: Colors.white),
                        ),
                      ),
                  ]
```

- [ ] **Step 3: Manual verification in the example app.**

Run: `cd /Users/hualinliang/Project/device_topology_view/example && flutter run -d chrome`

Expected: select a stacked scenario (e.g., Switch48PStacked from the scenario dropdown). Toggle to Rectangle mode. Expected behavior:
- Only the selected part's chassis half is visible; the unused half is covered by a white rectangle.
- Columns appear only around the visible half.
- Switching the active part (via the part toggle) flips which half is covered.
- Switching back to Circle mode restores both halves.

If the cover misaligns (e.g., wrong half hidden, sized incorrectly), adjust the rect math in `_stackedCoverRect()` and re-run.

- [ ] **Step 4: Commit.**

```bash
git add lib/src/device_topology_view.dart
git commit -m "feat: hide unused stacked chassis half in rectangle mode"
```

---

## Task 12: Version bump, changelog, final checks

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump the version.**

Edit `pubspec.yaml`. Change:

```yaml
version: 1.3.4
```

to:

```yaml
version: 1.4.0
```

- [ ] **Step 2: Add a CHANGELOG entry.**

Edit `CHANGELOG.md` and prepend (above the existing `## 1.3.4`):

```markdown
## 1.4.0

### New Features
- **Rectangle switch layout (`SwitchLayoutMode.rectangle`)**: New opt-in layout for `DeviceType.switch_` that arranges floating devices in column sections above and below the chassis instead of two concentric rings. Pass `switchLayoutMode: SwitchLayoutMode.rectangle` on `DeviceTopologyView` to enable. The default `SwitchLayoutMode.circle` preserves today's behavior.

### New API
- `SwitchLayoutMode` enum exported from `package:device_topology_view/device_topology_view.dart`.
- `DeviceTopologyView.switchLayoutMode` parameter (defaults to `SwitchLayoutMode.circle`).

### Internal
- Added `SwitchRectangleLayoutStrategy` alongside `SwitchLayoutStrategy`. Circle rendering is unchanged.
- Rectangle mode centers the chassis vertically via its own `calculateCenterLayout` override.
- Rectangle mode on stacked switches hides the unused chassis half.

```

- [ ] **Step 3: Run the full test suite and analyzer one last time.**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze && flutter test`

Expected: `No issues found!` followed by all tests passing.

- [ ] **Step 4: Verify the example still launches and both modes work end-to-end.**

Run: `cd /Users/hualinliang/Project/device_topology_view/example && flutter run -d chrome`

Expected: example launches. Toggle layout mode on a Switch28P scenario, a mismatch scenario, a config-mode scenario, and a Switch48PStacked scenario. Spot-check:
- All 4 connection situations render correctly in rectangle (green straight, black dashed, red straight, mismatch with baseline curving around actual).
- Config mode in rectangle shows grey-dashed straight lines to outer-slot baselines only.
- Stacked rectangle shows only the selected half.
- Port hover / selection spotlight still works.

- [ ] **Step 5: Commit.**

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to 1.4.0 for rectangle switch layout"
```

---

## Appendix: post-implementation memory update

After the feature lands, update the stale project memory about the red-line curve behavior (which no longer matches the current code since explore-ring lines are straight):

File: `/Users/hualinliang/.claude/projects/-Users-hualinliang-Project-device-topology-view/memory/project_connection_model.md`

Replace the outdated "Red curved only" row with:
- Explore lines (real/actual devices) are **straight**.
- Only baseline (outer-ring) lines are curved, and only when `!isConfig` in circle mode or when the rectangle strategy detects a mismatch on that port.

This is a memory-maintenance task, not code. Run it at the end of implementation.
