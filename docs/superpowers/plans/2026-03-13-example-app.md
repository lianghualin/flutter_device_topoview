# device_topology_view Example App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter web example app that demonstrates all `DeviceTopologyView` features with 14 interactive scenarios, a floating control panel, and real-time event logging.

**Architecture:** Single-page `StatefulWidget` app with dropdown scenario selector, full-screen topology view, and overlay control panel. State is local — no Provider/Bloc. Scenarios are immutable data objects; the app holds mutable copies for interactive manipulation.

**Tech Stack:** Flutter (web-only), `device_topology_view` package (path dependency)

**Spec:** `docs/superpowers/specs/2026-03-13-example-app-design.md`

---

## Chunk 1: Scaffolding & Foundation

### Task 1: Scaffold the Flutter example app

**Files:**
- Create: `example/` (via `flutter create`)
- Modify: `example/pubspec.yaml`

- [ ] **Step 1: Scaffold the example project**

Run from the package root (`/Users/hualinliang/Project/device_topology_view/`):

```bash
cd /Users/hualinliang/Project/device_topology_view
flutter create --template=app --platforms=web example
```

- [ ] **Step 2: Update `example/pubspec.yaml`**

Replace the generated `pubspec.yaml` with:

```yaml
name: device_topology_view_example
description: Example app for device_topology_view package.
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  device_topology_view:
    path: ../

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Run `flutter pub get`**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter pub get
```

Expected: Dependencies resolve successfully.

- [ ] **Step 4: Verify the app builds**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter build web --no-pub
```

Expected: Build succeeds (we'll replace the boilerplate code in later tasks).

- [ ] **Step 5: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/
git commit -m "chore: scaffold example app with flutter create"
```

---

### Task 2: Create the Scenario model

**Files:**
- Create: `example/lib/scenarios/scenario.dart`

- [ ] **Step 1: Create the Scenario class**

```dart
import 'package:device_topology_view/device_topology_view.dart';

class Scenario {
  const Scenario({
    required this.label,
    required this.deviceType,
    required this.format,
    required this.portDevices,
    required this.portStatusMap,
    required this.centerLabel,
  });

  final String label;
  final DeviceType deviceType;
  final DeviceFormat format;
  final List<PortDevice> portDevices;
  final Map<String, PortStatus> portStatusMap;
  final String centerLabel;

  /// Maximum number of devices the slider can add for this scenario.
  int get maxDevices {
    if (deviceType == DeviceType.host) return 6;
    if (deviceType == DeviceType.dpu) return 2;
    if (format is SwitchDeviceFormat) {
      final sf = format as SwitchDeviceFormat;
      return sf.validPortsNum ?? sf.totalPortsNum;
    }
    return 6;
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/scenarios/scenario.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/scenarios/scenario.dart
git commit -m "feat(example): add Scenario model"
```

---

### Task 3: Create the randomizer utilities

**Files:**
- Create: `example/lib/utils/randomizer.dart`

- [ ] **Step 1: Create the randomizer functions**

```dart
import 'dart:math';

import 'package:device_topology_view/device_topology_view.dart';

final _random = Random();

const _deviceTypes = ['Switch', 'Host', 'MMI', 'DPU', 'Unknown'];

/// Returns a new map with every port status randomized.
Map<String, PortStatus> randomizePortStatuses(Map<String, PortStatus> original) {
  final values = PortStatus.values;
  return original.map(
    (key, _) => MapEntry(key, values[_random.nextInt(values.length)]),
  );
}

/// Generates [count] PortDevice entries for switch scenarios.
/// Port numbers are assigned sequentially starting from 1.
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

/// Generates [count] PortDevice entries for host scenarios.
/// Each device uses a unique slot-based portId.
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

/// Generates [count] PortDevice entries for DPU scenarios (max 2).
/// First device goes to slotA, second to slotB.
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
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/utils/randomizer.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/utils/randomizer.dart
git commit -m "feat(example): add randomizer utilities"
```

---

### Task 4: Create sample data for all 14 scenarios

**Files:**
- Create: `example/lib/scenarios/sample_data.dart`

This is the largest single file. It defines all 14 scenarios with pre-built device lists and port status maps.

- [ ] **Step 1: Create `sample_data.dart`**

```dart
import 'package:device_topology_view/device_topology_view.dart';

import 'scenario.dart';

final List<Scenario> allScenarios = [
  // ── Host Scenarios (1–6 devices) ──────────────────────────────────────────
  _hostScenario(1),
  _hostScenario(2),
  _hostScenario(3),
  _hostScenario(4),
  _hostScenario(5),
  _hostScenario(6),

  // ── DPU Scenario ──────────────────────────────────────────────────────────
  _dpuScenario(),

  // ── Switch Scenarios ──────────────────────────────────────────────────────
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
    isStacked: true,
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
    isStacked: true,
  ),
];

// ── Helper: Host scenario builder ─────────────────────────────────────────

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

// ── Helper: DPU scenario builder ──────────────────────────────────────────

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

// ── Helper: Switch scenario builder ───────────────────────────────────────

Scenario _switchScenario({
  required String label,
  required SwitchDeviceFormat format,
  required List<PortDevice> devices,
  required int totalPorts,
  bool isStacked = false,
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
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/scenarios/sample_data.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/scenarios/sample_data.dart
git commit -m "feat(example): add 14 sample data scenarios"
```

---

## Chunk 2: UI Components

### Task 5: Create the EventLog widget

**Files:**
- Create: `example/lib/controls/event_log.dart`

- [ ] **Step 1: Create the EventLog widget**

```dart
import 'package:flutter/material.dart';

class EventLog extends StatelessWidget {
  const EventLog({
    required this.entries,
    required this.onClear,
    super.key,
  });

  final List<String> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Event Log',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton.icon(
              onPressed: entries.isEmpty ? null : onClear,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet.\nInteract with the topology to see callbacks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 8),
                      child: SelectableText(
                        entry,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/controls/event_log.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/controls/event_log.dart
git commit -m "feat(example): add EventLog widget"
```

---

### Task 6: Create the ControlPanel widget

**Files:**
- Create: `example/lib/controls/control_panel.dart`

- [ ] **Step 1: Create the ControlPanel widget**

```dart
import 'package:flutter/material.dart';

import 'package:device_topology_view/device_topology_view.dart';

import 'event_log.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    required this.isConfig,
    required this.onIsConfigChanged,
    required this.onRandomize,
    required this.deviceCount,
    required this.maxDevices,
    required this.onDeviceCountChanged,
    required this.portDevices,
    required this.onDeviceStatusChanged,
    required this.onReset,
    required this.eventLog,
    required this.onClearLog,
    this.deviceType,
    this.isStacked = false,
    this.stackedPart = 1,
    this.onStackedPartChanged,
    super.key,
  });

  final bool isConfig;
  final ValueChanged<bool> onIsConfigChanged;
  final VoidCallback onRandomize;
  final int deviceCount;
  final int maxDevices;
  final ValueChanged<int> onDeviceCountChanged;
  final List<PortDevice> portDevices;
  final void Function(int index, bool status) onDeviceStatusChanged;
  final VoidCallback onReset;
  final List<String> eventLog;
  final VoidCallback onClearLog;
  final DeviceType? deviceType;
  final bool isStacked;
  final int stackedPart;
  final ValueChanged<int>? onStackedPartChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 300,
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Controls',
                      style: Theme.of(context).textTheme.titleMedium),
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            // ── Scrollable controls ──
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // isConfig toggle
                  _SectionHeader(title: 'Mode'),
                  SwitchListTile(
                    title: const Text('isConfig'),
                    subtitle: const Text('Configuration mode'),
                    value: isConfig,
                    onChanged: onIsConfigChanged,
                    dense: true,
                  ),
                  const SizedBox(height: 8),

                  // Port status randomizer
                  _SectionHeader(title: 'Port Statuses'),
                  ElevatedButton.icon(
                    onPressed: onRandomize,
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Randomize'),
                  ),
                  const SizedBox(height: 16),

                  // Device count slider
                  _SectionHeader(title: 'Device Count: $deviceCount'),
                  Slider(
                    value: deviceCount.toDouble(),
                    min: 0,
                    max: maxDevices.toDouble(),
                    divisions: maxDevices > 0 ? maxDevices : 1,
                    label: deviceCount.toString(),
                    onChanged: (v) => onDeviceCountChanged(v.round()),
                  ),
                  const SizedBox(height: 8),

                  // Stacked part selector (switch only)
                  if (deviceType == DeviceType.switch_ && isStacked) ...[
                    _SectionHeader(title: 'Stacked Part'),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Part 1')),
                        ButtonSegment(value: 2, label: Text('Part 2')),
                      ],
                      selected: {stackedPart},
                      onSelectionChanged: (set) {
                        onStackedPartChanged?.call(set.first);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Device status toggles
                  _SectionHeader(title: 'Device Status'),
                  if (portDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No devices',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ...List.generate(portDevices.length, (i) {
                    final dev = portDevices[i];
                    return SwitchListTile(
                      title: Text(dev.deviceName, overflow: TextOverflow.ellipsis),
                      subtitle: Text(dev.deviceType, style: const TextStyle(fontSize: 11)),
                      value: dev.deviceStatus,
                      onChanged: (v) => onDeviceStatusChanged(i, v),
                      dense: true,
                    );
                  }),
                ],
              ),
            ),
            // ── Event log ──
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: EventLog(
                entries: eventLog,
                onClear: onClearLog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/controls/control_panel.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/controls/control_panel.dart
git commit -m "feat(example): add ControlPanel widget"
```

---

## Chunk 3: App Shell & Integration

### Task 7: Create the main App widget

**Files:**
- Create: `example/lib/app.dart`

This is the core widget that wires everything together: AppBar with dropdown + gear icon, full-screen topology, and overlay control panel.

- [ ] **Step 1: Create `app.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:device_topology_view/device_topology_view.dart';

import 'scenarios/scenario.dart';
import 'scenarios/sample_data.dart';
import 'controls/control_panel.dart';
import 'utils/randomizer.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentScenarioIndex = 0;
  late List<PortDevice> _portDevices;
  late Map<String, PortStatus> _portStatusMap;
  bool _isConfig = false;
  bool _showPanel = false;
  int _stackedPart = 0;
  List<String> _eventLog = [];

  /// Unique key to force DeviceTopologyView rebuild when stacked part changes.
  int _topologyKey = 0;

  Scenario get _currentScenario => allScenarios[_currentScenarioIndex];

  @override
  void initState() {
    super.initState();
    _loadScenario(_currentScenarioIndex);
  }

  void _loadScenario(int index) {
    final scenario = allScenarios[index];
    _currentScenarioIndex = index;
    _portDevices = List.of(scenario.portDevices);
    _portStatusMap = Map.of(scenario.portStatusMap);
    _isConfig = false;
    _eventLog = [];
    _topologyKey++;

    // Set default stacked part
    if (scenario.format is SwitchDeviceFormat &&
        (scenario.format as SwitchDeviceFormat).isStacked) {
      _stackedPart = 1;
    } else {
      _stackedPart = 0;
    }
  }

  void _handleReset() {
    setState(() {
      _loadScenario(_currentScenarioIndex);
    });
  }

  void _handleRandomize() {
    setState(() {
      _portStatusMap = randomizePortStatuses(_portStatusMap);
    });
  }

  void _handleDeviceCountChanged(int count) {
    setState(() {
      if (count < _portDevices.length) {
        _portDevices = _portDevices.sublist(0, count);
      } else if (count > _portDevices.length) {
        final scenario = _currentScenario;
        final int existing = _portDevices.length;
        final int toAdd = count - existing;
        List<PortDevice> newDevices;
        switch (scenario.deviceType) {
          case DeviceType.host:
            newDevices = generateHostDevices(count).sublist(existing);
            break;
          case DeviceType.dpu:
            newDevices = generateDpuDevices(count).sublist(existing);
            break;
          case DeviceType.switch_:
            newDevices = generateSwitchDevices(count).sublist(existing);
            break;
        }
        _portDevices = [..._portDevices, ...newDevices.take(toAdd)];
      }
    });
  }

  void _handleDeviceStatusChanged(int index, bool status) {
    setState(() {
      final dev = _portDevices[index];
      _portDevices[index] = PortDevice(
        portId: dev.portId,
        deviceName: dev.deviceName,
        portNumber: dev.portNumber,
        deviceType: dev.deviceType,
        deviceIp: dev.deviceIp,
        exploreDevName: dev.exploreDevName,
        exploreDevIp: dev.exploreDevIp,
        connectionStatus: dev.connectionStatus,
        deviceStatus: status,
      );
    });
  }

  void _handleDeviceSelected(String name, String type, int? portNum) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _eventLog.add(
        '[$timestamp] onDeviceSelected — name: $name, type: $type, port: $portNum',
      );
    });
  }

  void _handleStackedPartChanged(int part) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _stackedPart = part;
      _eventLog.add(
        '[$timestamp] onStackedSwitchPartChanged — part: $part',
      );
    });
  }

  void _handleStackedPartFromPanel(int part) {
    setState(() {
      _stackedPart = part;
      _topologyKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _currentScenario;
    final bool isStacked = scenario.format is SwitchDeviceFormat &&
        (scenario.format as SwitchDeviceFormat).isStacked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('device_topology_view'),
        centerTitle: false,
        actions: [
          // Scenario dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<int>(
              value: _currentScenarioIndex,
              underline: const SizedBox.shrink(),
              items: List.generate(allScenarios.length, (i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text(allScenarios[i].label),
                );
              }),
              onChanged: (index) {
                if (index != null) {
                  setState(() {
                    _loadScenario(index);
                  });
                }
              },
            ),
          ),
          // Gear icon
          IconButton(
            icon: Icon(_showPanel ? Icons.settings : Icons.settings_outlined),
            tooltip: 'Toggle control panel',
            onPressed: () {
              setState(() {
                _showPanel = !_showPanel;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Topology view ──
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DeviceTopologyView(
                  key: ValueKey(_topologyKey),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  deviceType: scenario.deviceType,
                  format: scenario.format,
                  portDevices: _portDevices,
                  portStatusMap: _portStatusMap,
                  centerLabel: scenario.centerLabel,
                  isConfig: _isConfig,
                  onDeviceSelected: _handleDeviceSelected,
                  initialStackedSwitchPart: isStacked ? _stackedPart : null,
                  onStackedSwitchPartChanged: isStacked
                      ? _handleStackedPartChanged
                      : null,
                );
              },
            ),
          ),
          // ── Overlay backdrop ──
          if (_showPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showPanel = false),
                child: Container(color: Colors.black26),
              ),
            ),
          // ── Control panel overlay ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _showPanel ? 0 : -300,
            width: 300,
            child: ControlPanel(
              isConfig: _isConfig,
              onIsConfigChanged: (v) => setState(() => _isConfig = v),
              onRandomize: _handleRandomize,
              deviceCount: _portDevices.length,
              maxDevices: scenario.maxDevices,
              onDeviceCountChanged: _handleDeviceCountChanged,
              portDevices: _portDevices,
              onDeviceStatusChanged: _handleDeviceStatusChanged,
              onReset: _handleReset,
              eventLog: _eventLog,
              onClearLog: () => setState(() => _eventLog = []),
              deviceType: scenario.deviceType,
              isStacked: isStacked,
              stackedPart: _stackedPart,
              onStackedPartChanged: _handleStackedPartFromPanel,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze lib/app.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/app.dart
git commit -m "feat(example): add App widget with topology + controls integration"
```

---

### Task 8: Create main.dart entry point

**Files:**
- Modify: `example/lib/main.dart`

- [ ] **Step 1: Replace the generated `main.dart`**

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'device_topology_view Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const App(),
    );
  }
}
```

- [ ] **Step 2: Delete any generated test file that references the old boilerplate**

```bash
rm -f /Users/hualinliang/Project/device_topology_view/example/test/widget_test.dart
```

- [ ] **Step 3: Verify the full app builds**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter analyze
```

Expected: No errors.

- [ ] **Step 4: Build for web**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter build web
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add example/lib/main.dart
git add -u example/test/  # tracks deletion of widget_test.dart
git commit -m "feat(example): add main.dart entry point and wire up MaterialApp"
```

---

## Chunk 4: Smoke Test & Final Cleanup

### Task 9: Manual smoke test on web

- [ ] **Step 1: Run the example app on Chrome**

```bash
cd /Users/hualinliang/Project/device_topology_view/example
flutter run -d chrome
```

- [ ] **Step 2: Verify all 14 scenarios**

Walk through each scenario in the dropdown and confirm:
- Topology renders without errors
- Center device label shows correctly
- Ports are visible for each device type
- Floating devices appear in expected positions

- [ ] **Step 3: Verify control panel**

- Tap gear icon → panel slides in from right
- Toggle isConfig → topology redraws
- Click "Randomize" → port colors change
- Move device count slider → devices appear/disappear
- Toggle device status switches → device indicators change
- For stacked switches: Part 1 / Part 2 segmented button switches parts
- Click "Reset" → restores original data

- [ ] **Step 4: Verify event log**

- Click on a device in the topology → event appears in log
- For stacked switch: change part → event appears
- Click "Clear" → log empties

- [ ] **Step 5: Fix any issues found during smoke test**

Address any rendering or interaction bugs discovered.

**Known limitation:** For stacked switch scenarios, if the device count slider removes all devices with `portNumber > 24`, the package's `_isStacked` heuristic (`SwitchLayoutStrategy._isStacked`) returns `false` and stacked filtering is skipped. This is pre-existing package behavior — the slider may expose this edge case but it does not need to be fixed in the example app.

- [ ] **Step 6: Final commit**

```bash
cd /Users/hualinliang/Project/device_topology_view
git add -A example/
git commit -m "feat(example): complete example app with 14 scenarios and control panel"
```
