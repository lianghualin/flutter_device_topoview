# device_topology_view Example App Design

## Goal

Build an example Flutter web app that serves as both a developer reference (copy-paste sample code, understand the API) and a presentable demo (screenshots, client demos) for the `device_topology_view` package.

## Architecture

Single-page web app with a dropdown scenario selector, full-screen topology view, and a floating overlay control panel toggled by a gear icon. State is managed with a simple `StatefulWidget` — no external state management needed.

**Tech Stack:** Flutter (web-only), depends on `device_topology_view` via path dependency (`../`).

---

## Scenarios

14 pre-built scenarios covering all 3 device types with varying complexity:

### Host Scenarios (6)

| # | Label | Devices | Purpose |
|---|-------|---------|---------|
| 1 | Host (1 device) | 1 switch | Minimal host topology |
| 2 | Host (2 devices) | 2 switches (baseline + explore) | Host with explore tier |
| 3 | Host (3 devices) | 3 switches | Scaling demo |
| 4 | Host (4 devices) | 4 switches | Scaling demo |
| 5 | Host (5 devices) | 5 switches | Scaling demo |
| 6 | Host (6 devices) | 6 switches | Maximum host demo |

All host scenarios use `SimpleDeviceFormat` via `HostTemplate` with semi-ellipse port layout. Port status maps use slot-based keys (e.g., `slotA_port1`). Each scenario includes a mix of up/down/unknown port statuses.

### DPU Scenario (1)

| # | Label | Devices | Purpose |
|---|-------|---------|---------|
| 7 | DPU | 2 switches (slotA + slotB) | Dual-slot DPU layout |

Uses `SimpleDeviceFormat` via `DPUTemplate`. Port status map uses `slotA`/`slotB` prefixed keys. Shows both slot groups with baseline devices positioned left (slotA) and right (slotB).

### Switch Scenarios (7)

| # | Label | Format | Devices | Purpose |
|---|-------|--------|---------|---------|
| 8 | Switch 6P | SwitchUD1U6P | 3 (Switch, Host, Unknown) | Smallest switch |
| 9 | Switch 10P | SwitchUD1U10P | 4 devices | Small switch |
| 10 | Switch 16P | SwitchUD1U16P | 5 devices | Mid-range |
| 11 | Switch 24P | SwitchUD1U24P | 8 devices (all 4 types) | Full single-tier |
| 12 | Switch 28P | SwitchUD1U28P | 6 devices | Max single-tier |
| 13 | Switch 30P (Stacked) | SwitchUD1U30PStacked | 6 devices | Smallest stacked |
| 14 | Switch 48P (Stacked) | SwitchUD1U48PStacked | 10 devices | Full stacked |

Switch scenarios use `SwitchDeviceFormat` presets from the package. Port status maps use numeric string keys (`"1"`, `"2"`, etc.). Device types vary across scenarios to demonstrate all 4 floating device types (Switch, Host/MMI, DPU, Unknown). Stacked scenarios demonstrate part selection (Part 1 / Part 2).

---

## Layout

### Top Bar

- Left: app title "device_topology_view"
- Center: dropdown selector with all 14 scenario labels
- Right: gear icon button to toggle the control panel overlay

### Main Area

Full-screen `DeviceTopologyView` widget filling all remaining space below the top bar. Uses `LayoutBuilder` to pass the available `Size` to the widget.

### Overlay Control Panel

Floating panel that slides in from the right edge when the gear icon is tapped. Semi-transparent backdrop. Dismissible by tapping the gear icon again or tapping outside the panel.

Panel width: ~300px fixed. Full height of the topology area.

---

## Control Panel Contents

### Data Controls (always visible)

- **isConfig toggle** — `Switch` widget. Toggles `DeviceTopologyView.isConfig`. Default: `false`.
- **Port status randomizer** — `ElevatedButton`. Randomizes all port statuses in the current scenario's `portStatusMap` to random up/down/unknown values.
- **Device count slider** — `Slider` widget. Adjusts the number of devices in the current scenario. Range depends on device type and format (e.g., 0 to total ports for switch). Adding devices generates new `PortDevice` entries with sequential port numbers and random device types. Removing devices trims from the end of the list.
- **Device status toggle** — List of device names with `Switch` widgets to flip `deviceStatus` between `true` (normal/green) and `false` (abnormal/red).
- **Reset button** — `OutlinedButton`. Restores the current scenario to its original sample data (devices, port statuses, isConfig).

### Switch-Specific Controls (visible only for switch_ scenarios)

- **Stacked part selector** — `SegmentedButton` with Part 1 / Part 2. Only visible when the current scenario uses a stacked `SwitchDeviceFormat`. Sets `initialStackedSwitchPart`.

### Event Log (bottom section)

- Scrollable list of callback events with timestamps.
- Captures: `onDeviceSelected(deviceName, deviceType, portNum)` and `onStackedSwitchPartChanged(part)`.
- Each entry shows: `[HH:MM:SS] eventName — details`.
- **Clear button** at the top of the log section.

---

## Interaction Flow

1. **App startup** — loads scenario #1 (Host 1 device). Topology renders. Gear icon visible.
2. **Dropdown selection** — swaps the entire scenario. Topology rebuilds. Control panel state resets (isConfig = false, event log cleared). Overlay stays open/closed as-is.
3. **Gear icon tap** — overlay slides in/out with animation (~200ms).
4. **Control changes** — each control modifies a mutable copy of the current scenario's data. Topology rebuilds reactively via `setState`. Original sample data is preserved for reset.
5. **Reset** — restores current scenario to its original sample data.
6. **Widget callbacks** — `onDeviceSelected` and `onStackedSwitchPartChanged` append entries to the event log.

### State Management

Simple `StatefulWidget` in `app.dart`. State variables:

- `_currentScenarioIndex` (int) — which scenario is selected
- `_portDevices` (List<PortDevice>) — mutable copy of current devices
- `_portStatusMap` (Map<String, PortStatus>) — mutable copy of current port statuses
- `_isConfig` (bool) — config mode toggle
- `_showPanel` (bool) — overlay visibility
- `_stackedPart` (int?) — stacked switch part selection
- `_eventLog` (List<String>) — callback log entries

---

## File Structure

```
example/
├── lib/
│   ├── main.dart              # Entry point, MaterialApp, web-only
│   ├── app.dart               # Top-level layout: AppBar with dropdown + gear, topology, overlay
│   ├── scenarios/
│   │   ├── scenario.dart      # Scenario model (label, deviceType, format, devices, portStatusMap, centerLabel)
│   │   └── sample_data.dart   # All 14 scenarios with pre-built sample data
│   ├── controls/
│   │   ├── control_panel.dart # Floating overlay panel widget
│   │   └── event_log.dart     # Scrollable callback event log widget
│   └── utils/
│       └── randomizer.dart    # Port status randomizer, device generator helpers
├── web/
│   ├── index.html             # Flutter web entry point
│   └── manifest.json          # Web manifest
└── pubspec.yaml               # Depends on device_topology_view (path: ../)
```

### File Responsibilities

- **main.dart** — `runApp()`, `MaterialApp` with theme, routes to `App`.
- **app.dart** — `StatefulWidget`. Holds all mutable state. Builds the AppBar (title, dropdown, gear icon), the `DeviceTopologyView`, and conditionally the overlay `ControlPanel`. Handles all callbacks.
- **scenario.dart** — Immutable `Scenario` class: `label`, `deviceType`, `format`, `portDevices`, `portStatusMap`, `centerLabel`. Factory method `copyWith()` not needed — `app.dart` holds mutable copies of the lists/maps separately.
- **sample_data.dart** — `final List<Scenario> allScenarios` with all 14 entries. Each constructs its `PortDevice` list and `portStatusMap` inline. This is the single source of truth for default data.
- **control_panel.dart** — `StatelessWidget`. Receives current state via constructor params, emits changes via callbacks (onIsConfigChanged, onRandomize, onDeviceCountChanged, onDeviceStatusChanged, onReset, onStackedPartChanged). Renders controls in a scrollable column.
- **event_log.dart** — `StatelessWidget`. Receives `List<String>` entries and `onClear` callback. Renders a scrollable list with monospace text.
- **randomizer.dart** — Pure functions: `randomizePortStatuses(Map)`, `generateDevices(int count, DeviceType)`. No state.

---

## Visual Design

- Material 3 theme with dark color scheme (matches the topology's white background for contrast)
- AppBar: standard Material elevation, dropdown uses `DropdownButton`
- Overlay: `AnimatedPositioned` or `SlideTransition` for slide-in animation. Background: semi-transparent black (`Colors.black26`). Panel: `Material` with elevation, white/light surface.
- Control sections separated by `Divider` widgets with section headers
- Event log uses `ListView.builder` with `SelectableText` for copy-paste
