# Package Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace custom SVG-based rendering with `topology_view_icons` v1.3.0, `flutter_switch_device` v0.3.0, and `flutter_host_device` v0.3.0; rename `dpu` to `agent`; bump to v1.2.0.

**Architecture:** Incremental 3-phase migration. Phase 1 swaps all SVG assets for Canvas painters. Phase 2 replaces switch body+ports with `SwitchDeviceView`. Phase 3 replaces host center+ports with `HostDeviceView`. A cross-cutting `dpu→agent` rename happens first.

**Tech Stack:** Flutter, topology_view_icons ^1.3.0, flutter_switch_device ^0.3.0, flutter_host_device ^0.3.0, flutter_device_ring ^0.2.0

**Spec:** `docs/superpowers/specs/2026-03-27-package-migration-design.md`

---

## File Map

### Files to Create
- `lib/src/strategies/agent_layout_strategy.dart` — renamed from dpu_layout_strategy.dart
- `lib/src/presets/agent_presets.dart` — renamed from dpu_presets.dart
- `lib/src/widgets/floating_devices/agent_dev_float.dart` — renamed from dpu_dev_float.dart

### Files to Delete
- `lib/src/widgets/svg_widget.dart` — SvgClip, SimpleShadow (replaced by Canvas)
- `lib/src/presets/switch_presets.dart` — replaced by flutter_switch_device presets
- `lib/src/presets/host_presets.dart` — replaced by flutter_host_device
- `lib/src/presets/dpu_presets.dart` — replaced by agent_presets.dart
- `lib/src/strategies/dpu_layout_strategy.dart` — replaced by agent_layout_strategy.dart
- `lib/src/widgets/floating_devices/dpu_dev_float.dart` — replaced by agent_dev_float.dart
- All 32 files in `assets/images/`

### Files to Modify
- `pubspec.yaml` — dependencies, version, remove assets section
- `lib/device_topology_view.dart` — update exports
- `lib/src/models/device_type.dart` — rename enum value
- `lib/src/models/device_format.dart` — remove SwitchDeviceFormat (Phase 2)
- `lib/src/widgets/port_widget.dart` — SVG → TopoPortPainter (Phase 1), then delegate to packages (Phases 2-3)
- `lib/src/widgets/port_layer.dart` — minor updates
- `lib/src/widgets/center_device_widget.dart` — SVG → Canvas (Phase 1), then SwitchDeviceView/HostDeviceView (Phases 2-3)
- `lib/src/widgets/floating_devices/dev_float.dart` — 'DPU' → 'Agent' string references
- `lib/src/widgets/floating_devices/switch_dev_float.dart` — SVG → TopoIconPainter
- `lib/src/widgets/floating_devices/host_dev_float.dart` — SVG → TopoIconPainter
- `lib/src/widgets/floating_devices/unknown_dev_float.dart` — SVG → TopoIconPainter
- `lib/src/device_topology_view.dart` — strategy references, port wiring
- `lib/src/strategies/switch_layout_strategy.dart` — use SwitchDeviceView.getPortPositions()
- `lib/src/strategies/host_layout_strategy.dart` — use HostDeviceView.getPortPositions()
- `lib/src/strategies/slot_based_layout_strategy.dart` — rename DPU references
- `lib/src/strategies/device_layout_strategy.dart` — no changes expected
- `example/lib/scenarios/sample_data.dart` — DPU → Agent
- `example/lib/app.dart` — DPU → Agent

---

## Task 1: Rename `dpu` → `agent` (cross-cutting)

**Files:**
- Modify: `lib/src/models/device_type.dart`
- Create: `lib/src/presets/agent_presets.dart`
- Create: `lib/src/strategies/agent_layout_strategy.dart`
- Create: `lib/src/widgets/floating_devices/agent_dev_float.dart`
- Delete: `lib/src/presets/dpu_presets.dart`
- Delete: `lib/src/strategies/dpu_layout_strategy.dart`
- Delete: `lib/src/widgets/floating_devices/dpu_dev_float.dart`
- Modify: `lib/device_topology_view.dart`
- Modify: `lib/src/device_topology_view.dart`
- Modify: `lib/src/widgets/center_device_widget.dart`
- Modify: `lib/src/widgets/floating_devices/dev_float.dart`
- Modify: `lib/src/strategies/slot_based_layout_strategy.dart`
- Modify: `example/lib/scenarios/sample_data.dart`
- Modify: `example/lib/app.dart`

- [ ] **Step 1: Rename DeviceType enum**

In `lib/src/models/device_type.dart`, change:
```dart
enum DeviceType { host, dpu, switch_ }
```
to:
```dart
enum DeviceType { host, agent, switch_ }
```

- [ ] **Step 2: Create agent_presets.dart**

Create `lib/src/presets/agent_presets.dart`:
```dart
import '../models/device_format.dart';

class AgentTemplate extends SimpleDeviceFormat {
  const AgentTemplate()
      : super(imgPath: 'assets/images/dpu_center.svg');
}
```

Delete `lib/src/presets/dpu_presets.dart`.

- [ ] **Step 3: Create agent_layout_strategy.dart**

Copy `lib/src/strategies/dpu_layout_strategy.dart` to `lib/src/strategies/agent_layout_strategy.dart`. In the new file:
- Rename class `DpuLayoutStrategy` → `AgentLayoutStrategy`
- Update doc comment: `/// Layout strategy for DPU topology views.` → `/// Layout strategy for Agent topology views.`
- Update all internal variable names: `dpuCenterX` → `agentCenterX`, etc.

Delete `lib/src/strategies/dpu_layout_strategy.dart`.

- [ ] **Step 4: Create agent_dev_float.dart**

Copy `lib/src/widgets/floating_devices/dpu_dev_float.dart` to `lib/src/widgets/floating_devices/agent_dev_float.dart`. In the new file:
- Rename `DpuDevFloat` → `AgentDevFloat`
- Rename `DpuDevFloatWidget` → `AgentDevFloatWidget`
- Rename `_DpuDevFloatWidgetState` → `_AgentDevFloatWidgetState`
- Change `super(deviceType: 'DPU')` → `super(deviceType: 'Agent')`

Delete `lib/src/widgets/floating_devices/dpu_dev_float.dart`.

- [ ] **Step 5: Update barrel exports**

In `lib/device_topology_view.dart`, change:
```dart
export 'src/presets/dpu_presets.dart';
```
to:
```dart
export 'src/presets/agent_presets.dart';
```

- [ ] **Step 6: Update main widget imports and references**

In `lib/src/device_topology_view.dart`:
- Change import `'strategies/dpu_layout_strategy.dart'` → `'strategies/agent_layout_strategy.dart'`
- Change `case DeviceType.dpu:` → `case DeviceType.agent:`
- Change `DpuLayoutStrategy` → `AgentLayoutStrategy`

- [ ] **Step 7: Update center_device_widget.dart**

In `lib/src/widgets/center_device_widget.dart`:
- Change `case DeviceType.dpu:` → `case DeviceType.agent:`
- Rename `_buildDpuCenter()` → `_buildAgentCenter()`
- Update the call site to match

- [ ] **Step 8: Update dev_float.dart base class**

In `lib/src/widgets/floating_devices/dev_float.dart`:
- Change `widget.deviceType == 'DPU'` → `widget.deviceType == 'Agent'` (around line 187)

- [ ] **Step 9: Update slot_based_layout_strategy.dart**

In `lib/src/strategies/slot_based_layout_strategy.dart`:
- Change import of `dpu_dev_float.dart` → `agent_dev_float.dart`
- Change any `DpuDevFloat` references → `AgentDevFloat`

- [ ] **Step 10: Update example app**

In `example/lib/scenarios/sample_data.dart`:
- Change `DeviceType.dpu` → `DeviceType.agent`
- Change `DPUTemplate()` → `AgentTemplate()`
- Change label strings: `'DPU'` → `'Agent'`
- Update import for `dpu_presets.dart` → `agent_presets.dart`

In `example/lib/app.dart`:
- Change any `dpu`/`DPU` references to `agent`/`Agent`

- [ ] **Step 11: Verify**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze`
Expected: No errors.

Run: `cd /Users/hualinliang/Project/device_topology_view/example && flutter analyze`
Expected: No errors.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "refactor: rename dpu to agent throughout codebase"
```

---

## Task 2: Add topology_view_icons, update dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Update pubspec.yaml dependencies**

In `pubspec.yaml`, add `topology_view_icons` and keep existing deps for now (remove flutter_svg/path_drawing in a later task after all SVG usages are gone):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg: ^2.0.9
  flutter_device_ring: ^0.2.0
  path_drawing: ^1.0.0
  topology_view_icons: ^1.3.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter pub get`
Expected: Resolving dependencies... Done.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add topology_view_icons ^1.3.0"
```

---

## Task 3: Replace port SVGs with TopoPortPainter

**Files:**
- Modify: `lib/src/widgets/port_widget.dart`

- [ ] **Step 1: Update imports in port_widget.dart**

Replace the flutter_svg import with topology_view_icons:
```dart
import 'package:topology_view_icons/topology_view_icons.dart';
```

Remove any `flutter_svg` import if present.

- [ ] **Step 2: Replace SVG asset selection with TopoPortPainter**

In `_PortWidgetState.build()`, replace the SVG asset selection logic (the block that selects `port_up_green.svg` etc. based on status) with:

```dart
// Determine port painter parameters
final bool isDisabled;
final bool isUp;
final PortDirection direction;

if (widget.port.isInvalid) {
  isDisabled = true;
  isUp = false;
  direction = widget.port.portNumber != null && widget.port.portNumber! % 2 == 0
      ? PortDirection.down
      : PortDirection.up;
} else if (widget.isConfig) {
  isDisabled = false;
  isUp = false; // grey = down status
  direction = widget.port.portNumber != null && widget.port.portNumber! % 2 == 0
      ? PortDirection.down
      : PortDirection.up;
} else {
  isDisabled = widget.port.isUp == null; // unknown = disabled look
  isUp = widget.port.isUp == true;
  direction = widget.port.portNumber != null && widget.port.portNumber! % 2 == 0
      ? PortDirection.down
      : PortDirection.up;
}
```

Replace the `SvgPicture.asset(...)` widget with:
```dart
CustomPaint(
  size: Size(widget.port.width, widget.port.height),
  painter: TopoPortPainter(
    isUp: isUp,
    isDisabled: isDisabled,
    direction: direction,
  ),
)
```

- [ ] **Step 3: Verify**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/src/widgets/port_widget.dart
git commit -m "refactor: replace port SVGs with TopoPortPainter"
```

---

## Task 4: Replace floating device SVGs with TopoIconPainter

**Files:**
- Modify: `lib/src/widgets/floating_devices/switch_dev_float.dart`
- Modify: `lib/src/widgets/floating_devices/host_dev_float.dart`
- Modify: `lib/src/widgets/floating_devices/agent_dev_float.dart`
- Modify: `lib/src/widgets/floating_devices/unknown_dev_float.dart`

- [ ] **Step 1: Update switch_dev_float.dart**

Add import:
```dart
import 'package:topology_view_icons/topology_view_icons.dart';
```

In `buildCompactIcon()` and `buildDeviceIcon()`, replace `SvgClip` / `SvgPicture.asset('assets/images/switch_float.svg', ...)` with:
```dart
CustomPaint(
  size: Size(size, size),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.switch_,
    style: TopoIconStyle.lnm,
  ),
)
```

Remove any `flutter_svg` or `svg_widget.dart` imports.

- [ ] **Step 2: Update host_dev_float.dart**

Add import:
```dart
import 'package:topology_view_icons/topology_view_icons.dart';
```

Replace `SvgClip` / `SvgPicture.asset('assets/images/host_float.svg', ...)` with:
```dart
CustomPaint(
  size: Size(size, size),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.host,
    style: TopoIconStyle.lnm,
  ),
)
```

Remove SVG imports.

- [ ] **Step 3: Update agent_dev_float.dart**

Add import:
```dart
import 'package:topology_view_icons/topology_view_icons.dart';
```

Replace `SvgPicture.asset('assets/images/dpu_float.svg', ...)` with:
```dart
CustomPaint(
  size: Size(size, size),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.agent,
    style: TopoIconStyle.lnm,
  ),
)
```

Remove SVG imports. Also remove `PhysicalModel` elevation wrapper — replace with Canvas shadow if needed.

- [ ] **Step 4: Update unknown_dev_float.dart**

Add import:
```dart
import 'package:topology_view_icons/topology_view_icons.dart';
```

Replace `SvgClip` / `SvgPicture.asset('assets/images/unknown_float.svg', ...)` with:
```dart
CustomPaint(
  size: Size(size, size),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.unknown,
    style: TopoIconStyle.lnm,
  ),
)
```

Remove SVG imports.

- [ ] **Step 5: Verify**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/src/widgets/floating_devices/
git commit -m "refactor: replace floating device SVGs with TopoIconPainter"
```

---

## Task 5: Replace center device SVGs with TopoIconPainter

**Files:**
- Modify: `lib/src/widgets/center_device_widget.dart`

- [ ] **Step 1: Update imports**

In `center_device_widget.dart`:
- Add: `import 'package:topology_view_icons/topology_view_icons.dart';`
- Remove: `import 'package:flutter_svg/flutter_svg.dart';`
- Remove: `import 'svg_widget.dart';`

- [ ] **Step 2: Replace _buildHostCenter()**

Replace `SimpleShadow` + `SvgPicture.asset('host_center.svg')` with:
```dart
CustomPaint(
  size: Size(deviceWidth, deviceHeight),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.host,
    style: TopoIconStyle.lnm,
  ),
)
```

Keep the label rendering below the icon unchanged.

- [ ] **Step 3: Replace _buildAgentCenter()**

Replace `SimpleShadow` + `SvgPicture.asset('dpu_center.svg')` with:
```dart
CustomPaint(
  size: Size(deviceWidth, deviceHeight),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.agent,
    style: TopoIconStyle.lnm,
  ),
)
```

Keep the label rendering unchanged.

- [ ] **Step 4: Replace _buildSwitchCenter()**

Replace `SvgClip` with `switch_N.svg` with:
```dart
CustomPaint(
  size: Size(switchWidth, switchHeight),
  painter: TopoIconPainter(
    deviceType: TopoDeviceType.switch_,
    style: TopoIconStyle.lnm,
  ),
)
```

- [ ] **Step 5: Replace _buildSwitchStackedCenter()**

Replace both `SvgClip` bodies (each using `switch_24.svg`) with `CustomPaint` using `TopoIconPainter(deviceType: TopoDeviceType.switch_)`. Keep the stacked part selection logic (GestureDetector, opacity) unchanged.

- [ ] **Step 6: Verify**

Run: `cd /Users/hualinliang/Project/device_topology_view && flutter analyze`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/src/widgets/center_device_widget.dart
git commit -m "refactor: replace center device SVGs with TopoIconPainter"
```

---

## Task 6: Delete SVG assets and remove flutter_svg/path_drawing

**Files:**
- Delete: all files in `assets/images/`
- Delete: `lib/src/widgets/svg_widget.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Delete all SVG assets**

```bash
rm -rf /Users/hualinliang/Project/device_topology_view/assets/
```

- [ ] **Step 2: Remove assets section from pubspec.yaml**

Remove the `flutter:` assets section:
```yaml
flutter:
  assets:
    - assets/images/
```

Change to just:
```yaml
flutter:
```

- [ ] **Step 3: Remove flutter_svg and path_drawing dependencies**

In `pubspec.yaml`, remove:
```yaml
  flutter_svg: ^2.0.9
  path_drawing: ^1.0.0
```

Final dependencies section:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_device_ring: ^0.2.0
  topology_view_icons: ^1.3.0
```

- [ ] **Step 4: Delete svg_widget.dart**

```bash
rm /Users/hualinliang/Project/device_topology_view/lib/src/widgets/svg_widget.dart
```

- [ ] **Step 5: Remove any remaining svg_widget.dart imports**

Search all `.dart` files for `import.*svg_widget` or `import.*flutter_svg` or `import.*path_drawing` and remove them.

- [ ] **Step 6: Run flutter pub get**

```bash
cd /Users/hualinliang/Project/device_topology_view && flutter pub get
```

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: No errors. No references to deleted files.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove all SVG assets and flutter_svg/path_drawing deps"
```

---

## Task 7: Add flutter_switch_device and replace switch presets

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/src/models/device_format.dart`
- Delete: `lib/src/presets/switch_presets.dart`
- Modify: `lib/device_topology_view.dart`
- Modify: `lib/src/strategies/switch_layout_strategy.dart`
- Modify: `lib/src/device_topology_view.dart`
- Modify: `example/lib/scenarios/sample_data.dart`

- [ ] **Step 1: Add flutter_switch_device dependency**

In `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_device_ring: ^0.2.0
  topology_view_icons: ^1.3.0
  flutter_switch_device: ^0.3.0
```

Run: `flutter pub get`

- [ ] **Step 2: Delete switch_presets.dart**

```bash
rm /Users/hualinliang/Project/device_topology_view/lib/src/presets/switch_presets.dart
```

- [ ] **Step 3: Update barrel exports**

In `lib/device_topology_view.dart`, remove:
```dart
export 'src/presets/switch_presets.dart';
```

Add re-export of flutter_switch_device presets:
```dart
export 'package:flutter_switch_device/flutter_switch_device.dart' show
    SwitchFormat,
    Switch6P, Switch8P, Switch10P, Switch12P, Switch14P,
    Switch16P, Switch18P, Switch20P, Switch22P, Switch24P,
    Switch26P, Switch28P,
    Switch30PStacked, Switch32PStacked, Switch34PStacked,
    Switch36PStacked, Switch38PStacked, Switch40PStacked,
    Switch42PStacked, Switch44PStacked, Switch46PStacked,
    Switch48PStacked;
```

- [ ] **Step 4: Remove SwitchDeviceFormat from device_format.dart**

In `lib/src/models/device_format.dart`, remove the `SwitchDeviceFormat` class (lines 31-54). Keep `DeviceFormat` abstract base and `SimpleDeviceFormat`.

- [ ] **Step 5: Update switch_layout_strategy.dart imports**

Replace import of `switch_presets.dart` and `device_format.dart` SwitchDeviceFormat references with:
```dart
import 'package:flutter_switch_device/flutter_switch_device.dart';
```

Change all `SwitchDeviceFormat` references to `SwitchFormat`.

- [ ] **Step 6: Update example sample_data.dart**

Replace all `SwitchUD1U*P` references with package equivalents:
- `SwitchUD1U6P()` → `Switch6P()`
- `SwitchUD1U8P()` → `Switch8P()`
- ... through all presets
- `SwitchUD1U30PStacked()` → `Switch30PStacked()`
- `SwitchUD1U48PStacked()` → `Switch48PStacked()`

Update imports accordingly.

- [ ] **Step 7: Update device_topology_view.dart main widget**

In `lib/src/device_topology_view.dart`, update any `SwitchDeviceFormat` references to `SwitchFormat`. Update the import.

- [ ] **Step 8: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: replace switch presets with flutter_switch_device package"
```

---

## Task 8: Replace switch center rendering with SwitchDeviceView

**Files:**
- Modify: `lib/src/widgets/center_device_widget.dart`
- Modify: `lib/src/device_topology_view.dart`

- [ ] **Step 1: Update center_device_widget.dart for switch**

Add import:
```dart
import 'package:flutter_switch_device/flutter_switch_device.dart';
```

Replace `_buildSwitchCenter()` and `_buildSwitchStackedCenter()` with methods that embed `SwitchDeviceView`:

```dart
Widget _buildSwitchCenter() {
  return SwitchDeviceView(
    format: widget.format as SwitchFormat,
    portStatuses: widget.portStatuses,
    selectedPorts: widget.selectedPorts,
    unselectedPortOpacity: widget.unselectedPortOpacity,
    isConfig: widget.isConfig,
    onPortTap: widget.onPortTap,
    onPortHover: widget.onPortHover,
    onPortHoverExit: widget.onPortHoverExit,
  );
}
```

For stacked switches:
```dart
Widget _buildSwitchStackedCenter() {
  return SwitchDeviceView(
    format: widget.format as SwitchFormat,
    portStatuses: widget.portStatuses,
    selectedPorts: widget.selectedPorts,
    unselectedPortOpacity: widget.unselectedPortOpacity,
    isConfig: widget.isConfig,
    stackedPart: widget.stackedPart,
    onStackedPartChanged: widget.onStackedPartChanged,
    onPortTap: widget.onPortTap,
    onPortHover: widget.onPortHover,
    onPortHoverExit: widget.onPortHoverExit,
  );
}
```

- [ ] **Step 2: Pass port interaction callbacks through CenterDeviceWidget**

Add new constructor parameters to `CenterDeviceWidget`:
```dart
final Map<int, PortStatus>? portStatuses;
final Set<int> selectedPorts;
final double unselectedPortOpacity;
final bool isConfig;
final ValueChanged<int>? onPortTap;
final ValueChanged<int>? onPortHover;
final VoidCallback? onPortHoverExit;
final int stackedPart;
final ValueChanged<int>? onStackedPartChanged;
```

- [ ] **Step 3: Wire callbacks from DeviceTopologyView**

In `lib/src/device_topology_view.dart`, pass the port interaction state and callbacks through to `CenterDeviceWidget` when `deviceType == DeviceType.switch_`.

- [ ] **Step 4: Remove switch port rendering from PortLayer**

Since `SwitchDeviceView` now handles its own ports, the switch case in `PortLayer` should no longer render ports. Add a condition: if `deviceType == DeviceType.switch_`, the `PortLayer` renders nothing (ports are inside `SwitchDeviceView`).

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: replace switch center+ports with SwitchDeviceView"
```

---

## Task 9: Use SwitchDeviceView.getPortPositions() for connection lines

**Files:**
- Modify: `lib/src/strategies/switch_layout_strategy.dart`

- [ ] **Step 1: Replace port position calculation**

In `SwitchLayoutStrategy.calculatePortPositions()`, replace the manual port offset calculation with:

```dart
@override
List<Port> calculatePortPositions(CenterDeviceLayout center, DeviceFormat format) {
  final switchFormat = format as SwitchFormat;
  final viewportSize = Size(
    max(_viewportSize.width, switchFormat.minWidth),
    max(_viewportSize.height, switchFormat.minHeight),
  );

  final rawPositions = SwitchDeviceView.getPortPositions(
    switchFormat,
    viewportSize,
    parentOffset: center.position,
  );

  return rawPositions.entries.map((entry) {
    final portNum = entry.key;
    final position = entry.value;
    final status = _portStatusMap[portNum.toString()];
    final isInvalid = switchFormat.validPortsNum != null &&
        portNum > switchFormat.validPortsNum!;

    return Port(
      position: position,
      width: _portSize,
      height: _portSize,
      label: portNum.toString(),
      portNumber: portNum,
      isUp: status == PortStatus.up ? true : (status == PortStatus.down ? false : null),
      isInvalid: isInvalid,
      opacity: _getPortOpacity(portNum),
    );
  }).toList();
}
```

- [ ] **Step 2: Remove manual port offset arithmetic**

Delete the old manual port position calculation code that used `evenPortOffsetR` and `oddPortOffsetR` lists.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/src/strategies/switch_layout_strategy.dart
git commit -m "refactor: use SwitchDeviceView.getPortPositions() for switch connections"
```

---

## Task 10: Add flutter_host_device and replace host center + ports

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/src/widgets/center_device_widget.dart`
- Modify: `lib/src/device_topology_view.dart`
- Delete: `lib/src/presets/host_presets.dart`
- Modify: `lib/device_topology_view.dart`

- [ ] **Step 1: Add flutter_host_device dependency**

In `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_device_ring: ^0.2.0
  topology_view_icons: ^1.3.0
  flutter_switch_device: ^0.3.0
  flutter_host_device: ^0.3.0
```

Run: `flutter pub get`

- [ ] **Step 2: Delete host_presets.dart**

```bash
rm /Users/hualinliang/Project/device_topology_view/lib/src/presets/host_presets.dart
```

Update barrel exports in `lib/device_topology_view.dart`: remove `export 'src/presets/host_presets.dart';`

Re-export from flutter_host_device if needed:
```dart
export 'package:flutter_host_device/flutter_host_device.dart' show HostDeviceView;
```

- [ ] **Step 3: Replace _buildHostCenter() with HostDeviceView**

In `center_device_widget.dart`, replace `_buildHostCenter()`:

```dart
Widget _buildHostCenter() {
  return HostDeviceView(
    portCount: widget.portCount,
    portStatuses: widget.portStatuses ?? {},
    portLabels: widget.portLabels ?? {},
    selectedPortNumbers: widget.selectedPortNumbers,
    unselectedPortOpacity: widget.unselectedPortOpacity,
    isConfig: widget.isConfig,
    centerYFactor: widget.centerYFactor,
    deviceType: TopoDeviceType.host,
    onPortTap: widget.onPortTap,
    onPortHover: widget.onPortHover,
    onPortHoverExit: widget.onPortHoverExit,
  );
}
```

- [ ] **Step 4: Pass host-specific params through CenterDeviceWidget**

Add parameters:
```dart
final int portCount;
final Map<int, PortStatus>? portStatuses;
final Map<int, String>? portLabels;
final Set<int> selectedPortNumbers;
final double centerYFactor;
```

- [ ] **Step 5: Compute centerYFactor in DeviceTopologyView**

In `lib/src/device_topology_view.dart`, compute `centerYFactor` based on device count and pass to `CenterDeviceWidget`:

```dart
double _computeCenterYFactor() {
  final deviceCount = widget.portDevices.length;
  if (deviceCount <= 2) return 0.55;
  if (deviceCount <= 4) return 0.63;
  return 0.72;
}
```

- [ ] **Step 6: Remove host port rendering from PortLayer**

Similar to switch: if `deviceType == DeviceType.host`, `PortLayer` renders nothing (ports are inside `HostDeviceView`).

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: replace host center+ports with HostDeviceView"
```

---

## Task 11: Use HostDeviceView.getPortPositions() for connection lines

**Files:**
- Modify: `lib/src/strategies/host_layout_strategy.dart`

- [ ] **Step 1: Replace port position calculation**

In `HostLayoutStrategy.calculatePortPositions()`, replace the manual semi-ellipse calculation with:

```dart
@override
List<Port> calculatePortPositions(CenterDeviceLayout center, DeviceFormat format) {
  final portCount = _statusMap.length;
  final centerYFactor = _computeCenterYFactor();

  final rawPositions = HostDeviceView.getPortPositions(
    portCount,
    _viewportSize,
    centerYFactor: centerYFactor,
  );

  // Add center position offset for global coordinates
  return rawPositions.entries.map((entry) {
    final portNum = entry.key;
    final position = entry.value + center.position;
    final portId = _statusMap.keys.elementAt(portNum - 1);
    final status = _statusMap[portId];

    return Port(
      position: position,
      width: 30,
      height: 30,
      label: portId,
      portNumber: portNum,
      isUp: status == PortStatus.up ? true : (status == PortStatus.down ? false : null),
    );
  }).toList();
}
```

- [ ] **Step 2: Remove manual semi-ellipse arithmetic**

Delete the old `cos`/`sin` port position calculation code.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/src/strategies/host_layout_strategy.dart
git commit -m "refactor: use HostDeviceView.getPortPositions() for host connections"
```

---

## Task 12: Update example app and clean up

**Files:**
- Modify: `example/lib/app.dart`
- Modify: `example/lib/scenarios/sample_data.dart`
- Modify: `example/pubspec.yaml`

- [ ] **Step 1: Update example pubspec.yaml**

Ensure example's `pubspec.yaml` doesn't reference deleted assets or old deps. Run `flutter pub get` in example.

- [ ] **Step 2: Verify example builds and runs**

```bash
cd /Users/hualinliang/Project/device_topology_view/example && flutter analyze
```

Expected: No errors.

- [ ] **Step 3: Visual verification**

Run the example app and verify:
- Host view: center device renders, port arc visible, connections draw correctly
- Agent view: center device renders, slot-based ports visible, connections draw
- Switch view (all presets): body renders, ports render with correct colors, stacked switches work
- Config mode: all ports grey, explore data stripped
- Spotlight: port selection dims other elements
- Floating devices: all 4 types render with Canvas icons

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: update example app for package migration"
```

---

## Task 13: Version bump and final cleanup

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Bump version**

In `pubspec.yaml`, change:
```yaml
version: 1.0.0
```
to:
```yaml
version: 1.2.0
```

- [ ] **Step 2: Clean up unused imports across codebase**

Run: `flutter analyze`

Fix any warnings about unused imports or dead code.

- [ ] **Step 3: Final verification**

```bash
cd /Users/hualinliang/Project/device_topology_view && flutter analyze
cd /Users/hualinliang/Project/device_topology_view/example && flutter analyze
```

Expected: Zero errors, zero warnings.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: bump version to 1.2.0 — package migration complete"
```
