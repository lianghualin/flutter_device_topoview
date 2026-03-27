# Package Migration Design — device_topology_view v1.2.0

## Goal

Replace custom SVG-based rendering with three pub.dev packages, rename `dpu` to `agent`, bump to v1.2.0.

## Packages

| Package | Version | Replaces |
|---|---|---|
| `topology_view_icons` | ^1.3.0 | All 32 SVG assets, `flutter_svg`, `path_drawing`, `SvgClip`, `SimpleShadow` |
| `flutter_switch_device` | ^0.3.0 | Switch center body, switch port rendering, switch presets |
| `flutter_host_device` | ^0.3.0 | Host center body, host port arc rendering, host presets |

## Migration Strategy

**Incremental** — 3 phases + cross-cutting rename, each independently testable.

## Phase 1: `topology_view_icons` — Replace all SVG assets

### Add/Remove Dependencies

- Add: `topology_view_icons: ^1.3.0`
- Remove: `flutter_svg: ^2.0.9`, `path_drawing: ^1.0.0`

### Delete Assets

- All 32 SVG files in `/assets/images/`
- Remove `assets` section from `pubspec.yaml`

### Delete Custom Widgets

- `lib/src/widgets/svg_widget.dart` (`SvgClip`, `SimpleShadow`)

### Replace Icon Rendering

**Floating device widgets** (`lib/src/widgets/floating_devices/`):
- `SwitchDevFloat`: `SvgClip('switch_float.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.switch_))`
- `HostDevFloat`: `SvgClip('host_float.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.host))`
- `DpuDevFloat`: `SvgClip('dpu_float.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.agent))`
- `UnknownDevFloat`: `SvgClip('unknown_float.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.unknown))`

**Port widget** (`lib/src/widgets/port_widget.dart`):
- Replace `SvgPicture.asset('port_up_green.svg')` etc. with `CustomPaint(painter: TopoPortPainter(isUp: true/false, direction: PortDirection.up/down))`
- Map: `PortStatus.up` → `isUp: true`, `PortStatus.down` → `isUp: false`, `PortStatus.unknown` → `isDisabled: true`
- Odd ports: `direction: PortDirection.up`, even ports: `direction: PortDirection.down`

**Center device widget** (`lib/src/widgets/center_device_widget.dart`):
- Host center: `SvgPicture.asset('host_center.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.host))`
- DPU center: `SvgPicture.asset('dpu_center.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.agent))`
- Switch center: `SvgClip('switch_N.svg')` → `CustomPaint(painter: TopoIconPainter(deviceType: TopoDeviceType.switch_))`

**Shadow replacement:**
- Where `SimpleShadow` or `SvgClip` with elevation was used, add `Canvas.drawShadow()` or `Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)` beneath the icon paint.

## Phase 2: `flutter_switch_device` — Replace switch body + ports

### Add Dependency

- Add: `flutter_switch_device: ^0.3.0`

### Replace Switch Presets

- Delete `lib/src/presets/switch_presets.dart`
- Replace all `SwitchUD1U*P` references with `Switch*P` from package (e.g., `SwitchUD1U24P` → `Switch24P`)
- Replace `SwitchDeviceFormat` model with `SwitchFormat` from package

### Replace Switch Center Rendering

- In `CenterDeviceWidget._buildSwitchCenter()` and `_buildSwitchStackedCenter()`:
  - Replace with embedded `SwitchDeviceView` widget from package
  - Wire through: `portStatuses`, `selectedPorts`, `unselectedPortOpacity`, `isConfig`, `stackedPart`, `onStackedPartChanged`, `onPortSelected`, `onPortHover`, `onPortHoverExit`, `onPortTap`

### Replace Switch Port Rendering

- Switch ports are now rendered by `SwitchDeviceView` internally — remove switch-specific port logic from `PortLayer`/`PortWidget`
- The topology view no longer needs to position switch ports itself

### Connection Line Coordinates

- Use `SwitchDeviceView.getPortPositions(format, size, parentOffset: switchOffset)` to get port positions for connection line drawing
- Replace `SwitchLayoutStrategy.calculatePortPositions()` with package API

### Files Modified

- `lib/src/strategies/switch_layout_strategy.dart` — simplify; delegate port/center to package
- `lib/src/widgets/center_device_widget.dart` — switch case uses `SwitchDeviceView`
- `lib/src/models/device_format.dart` — remove `SwitchDeviceFormat` (use `SwitchFormat` from package)

### Files Deleted

- `lib/src/presets/switch_presets.dart`

## Phase 3: `flutter_host_device` — Replace host center + ports

### Add Dependency

- Add: `flutter_host_device: ^0.3.0`

### Replace Host Center + Port Arc

- In `CenterDeviceWidget._buildHostCenter()`:
  - Replace with embedded `HostDeviceView` widget from package
  - Wire through: `portStatuses`, `portLabels`, `selectedPortNumbers`, `unselectedPortOpacity`, `isConfig`, `onPortTap`, `onPortHover`, `onPortHoverExit`
  - Compute `centerYFactor` from device count: 1-2 → 0.55, 3-4 → 0.63, 5+ → 0.72
  - Pass to `HostDeviceView(centerYFactor: computedValue)`

### Connection Line Coordinates

- Use `HostDeviceView.getPortPositions(portCount, viewportSize, centerYFactor:)` for port positions
- Replace `HostLayoutStrategy.calculatePortPositions()` with package API

### Keep Agent (DPU) Layout

- Agent/DPU continues to use the old layout strategy (renamed in cross-cutting phase)
- `flutter_host_device` is only used for `DeviceType.host`, not `DeviceType.agent`

### Files Modified

- `lib/src/strategies/host_layout_strategy.dart` — simplify; delegate port/center to package
- `lib/src/widgets/center_device_widget.dart` — host case uses `HostDeviceView`

### Files Deleted

- `lib/src/presets/host_presets.dart`

## Cross-cutting: `dpu` → `agent` rename

### Renames

| From | To |
|---|---|
| `DeviceType.dpu` | `DeviceType.agent` |
| String `'DPU'` in PortDevice.deviceType | `'Agent'` |
| `DpuLayoutStrategy` | `AgentLayoutStrategy` |
| `DpuTemplate` | `AgentTemplate` |
| `dpu_layout_strategy.dart` | `agent_layout_strategy.dart` |
| `dpu_presets.dart` | `agent_presets.dart` |
| `DpuDevFloat` | `AgentDevFloat` |
| `DpuDevFloatWidget` | `AgentDevFloatWidget` |
| `dpu_dev_float.dart` | `agent_dev_float.dart` |

### Version Bump

- `pubspec.yaml` version: `1.0.0` → `1.2.0`

### Public API Exports

- Update `lib/device_topology_view.dart` barrel exports to reflect new names

## What Stays Unchanged

- `DeviceTopologyView` main widget (orchestration, layer stacking)
- `PanZoomMixin` (gesture handling)
- `ConnectionLine` model and `ConnectionsPainter` (connection line rendering)
- `DevLayer` (floating device container)
- `DevFloat` base class and widget hierarchy (except rename DPU → Agent)
- `SlotBasedLayoutStrategy` (shared base for host/agent)
- `DeviceRing` integration (`flutter_device_ring` dependency stays)
- Spotlight/dimming system
- Two-tier baseline/explore architecture
- Example app structure (update to use new APIs)

## Testing

Each phase should be verified by:
1. Running `flutter analyze` — no errors
2. Running `flutter test` — all existing tests pass
3. Running the example app — visual verification of all device types
4. Checking connection lines render correctly with new port position APIs
