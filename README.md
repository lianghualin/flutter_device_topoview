# device_topology_view

A Flutter widget for visualizing device-centric network topologies with interactive port-level connections.

## Features

- **Three device types**: Host, Agent (DPU), and Switch center devices
- **Switch topology**: Interactive ports with multi-select spotlight, flowing dash animations, stacked switch support (up to 48 ports)
- **Host topology**: Semi-elliptical port arc with connected floating devices
- **Agent topology**: Slot-based port layout (slotA/slotB)
- **Two-tier architecture**: Baseline (configured) and explore (discovered) device layers
- **Connection lines**: Straight, curved, dashed, and animated flowing dash styles with status colors (green/red/black)
- **Spotlight mode**: Hover or click ports to dim unrelated connections and highlight the active path
- **Bidirectional interaction**: Click a port or its connected device for the same spotlight effect
- **Multi-port selection**: Select multiple ports simultaneously to compare connections
- **Traffic visualization**: Inbound/outbound utilization rings on explore devices via `flutter_device_ring`
- **Config mode**: Strips explore data, shows baseline connections as grey dashed lines
- **Pan & zoom**: Gesture-based navigation with scroll zoom
- **Canvas-drawn icons**: All device and port icons rendered via `topology_view_icons` -- zero SVG assets

## Installation

```yaml
dependencies:
  device_topology_view: ^1.5.0
```

## Quick Start

```dart
import 'package:device_topology_view/device_topology_view.dart';

DeviceTopologyView(
  size: Size(800, 600),
  deviceType: DeviceType.switch_,
  format: Switch24P(),
  portDevices: portDevices,
  portStatusMap: {'1': PortStatus.up, '2': PortStatus.down},
  centerLabel: 'Core-Switch',
)
```

## Device Types

### Switch

Renders a switch chassis with 6-48 ports in single-row, two-row, or stacked layouts. Supports interactive port spotlight with multi-selection.

```dart
DeviceTopologyView(
  deviceType: DeviceType.switch_,
  format: Switch24P(),         // 22 presets available: Switch6P through Switch48PStacked
  // ...
)
```

**Available presets**: `Switch6P`, `Switch8P`, `Switch10P`, `Switch12P`, `Switch14P`, `Switch16P`, `Switch18P`, `Switch20P`, `Switch22P`, `Switch24P`, `Switch26P`, `Switch28P`, `Switch30PStacked`, `Switch32PStacked`, `Switch34PStacked`, `Switch36PStacked`, `Switch38PStacked`, `Switch40PStacked`, `Switch42PStacked`, `Switch44PStacked`, `Switch46PStacked`, `Switch48PStacked`

#### Switch layout mode

Switch topologies support two layout modes:

- `SwitchLayoutMode.circle` (default) — floating devices arranged in two concentric rings around the chassis. Inner ring holds real/discovered devices, outer ring holds baseline/configured devices.
- `SwitchLayoutMode.rectangle` — floating devices arranged in column sections above and below the chassis. Each connected port gets one column; devices spread evenly across the full viewport width, with the actual device anchored close to the chassis edge and the baseline device sitting near the screen edge.

```dart
DeviceTopologyView(
  size: Size(1500, 1000),
  deviceType: DeviceType.switch_,
  format: Switch28P(),
  portDevices: portDevices,
  portStatusMap: portStatusMap,
  centerLabel: 'Core-Switch',
  switchLayoutMode: SwitchLayoutMode.rectangle, // opt-in, defaults to .circle
)
```

All other parameters — `isConfig`, `onDeviceSelected`, `initialStackedSwitchPart`, `onStackedSwitchPartChanged`, `enableAnimations`, `showOuterRing`, `labelBottomPadding` — work identically in both modes. The parameter is ignored for `DeviceType.host` and `DeviceType.agent`.

**When to use rectangle mode:** dense topologies where seeing each port's connection as a clear vertical column (rather than an angular ring spoke) is easier to read, or when the viewport is wider than it is tall so the ring layout pushes icons off-screen.

**Stacked switches:** in rectangle mode, only the selected part's chassis is visible. Use `initialStackedSwitchPart` / `onStackedSwitchPartChanged` as you would in circle mode; the inactive half is hidden automatically.

### Host

Renders a host device with ports arranged in a semi-elliptical arc above the center.

```dart
DeviceTopologyView(
  deviceType: DeviceType.host,
  format: SimpleDeviceFormat(imgPath: ''),
  // ...
)
```

### Agent

Renders an agent (DPU) device with slot-based port layout.

```dart
DeviceTopologyView(
  deviceType: DeviceType.agent,
  format: AgentTemplate(),
  // ...
)
```

## Data Model

### PortDevice

Represents a network device connected to a port:

```dart
PortDevice(
  portId: 'Port1',
  portNumber: 1,
  deviceName: 'Switch-A',
  deviceType: 'Switch',           // 'Switch', 'Host', 'Agent', 'Unknown'
  deviceIp: '192.168.1.1',
  deviceStatus: true,             // true = normal (green), false = abnormal (red)
  connectionStatus: 1,            // 1 = connected, 0 = baseline, -1 = probed
  exploreDevName: 'Discovered-A', // Explore tier device name
  exploreDevIp: '10.0.0.1',
  exploreInboundUtilization: 0.45,
  exploreOutboundUtilization: 0.30,
)
```

### PortStatus

```dart
enum PortStatus { up, down, unknown }
```

### DeviceType

```dart
enum DeviceType { host, agent, switch_ }
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `size` | `Size` | required | Viewport size |
| `deviceType` | `DeviceType` | required | Center device type |
| `format` | `Object` | required | Device layout format (`SwitchFormat` or `SimpleDeviceFormat`) |
| `portDevices` | `List<PortDevice>` | required | Connected devices |
| `portStatusMap` | `Map<String, PortStatus>` | required | Port status by port ID |
| `centerLabel` | `String` | required | Center device label |
| `isConfig` | `bool` | `false` | Config mode (strips explore data) |
| `onDeviceSelected` | `Function?` | `null` | Callback when a device is tapped |
| `initialStackedSwitchPart` | `int?` | `null` | Initial stacked switch part (1 or 2) |
| `onStackedSwitchPartChanged` | `Function?` | `null` | Callback when stacked part changes |
| `enableAnimations` | `bool` | `true` | Enable/disable animations |
| `showOuterRing` | `bool` | `true` | Show baseline (outer ring) connections |
| `labelBottomPadding` | `double` | `40.0` | Extra bottom margin to prevent device labels from being clipped |
| `switchLayoutMode` | `SwitchLayoutMode` | `SwitchLayoutMode.circle` | Switch-only: `.circle` (two rings) or `.rectangle` (column sections above/below the chassis). Ignored for host/agent. |

## Dependencies

| Package | Purpose |
|---|---|
| `topology_view_icons` | Canvas-drawn device and port icons |
| `flutter_switch_device` | Switch body, ports, and format presets |
| `flutter_host_device` | Host body and port arc layout |
| `flutter_device_ring` | Traffic utilization ring visualization |

## License

MIT
