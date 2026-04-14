## 1.3.1

### Bug Fixes
- **Viewport-aware icon sizing**: Floating device icons now scale up when the widget is used in a constrained viewport (e.g., 1200x300 with sidebar/header). Previously, icons were sized for the inflated internal canvas (1500x800) and looked disproportionately small in the visible area. Icons now boost up to 1.4x in tight viewports while remaining unchanged at full screen.

## 1.3.0

### Breaking Changes
- **Renamed `dpu` to `agent`** throughout the API:
  - `DeviceType.dpu` -> `DeviceType.agent`
  - `DPUTemplate` -> `AgentTemplate`
  - `PortDevice.deviceType` string value `'DPU'` -> `'Agent'`

### Package Migration
- Replaced all SVG assets with canvas-drawn icons via `topology_view_icons` package
- Replaced switch body and port rendering with `flutter_switch_device` package
- Replaced host body and port rendering with `flutter_host_device` package
- Removed `flutter_svg` and `path_drawing` dependencies
- Zero-asset bundle: no SVG files required

### New Dependencies
- `topology_view_icons: ^1.3.0` -- canvas-drawn device and port icons
- `flutter_switch_device: ^0.3.0` -- switch body, ports, and presets
- `flutter_host_device: ^0.3.0` -- host body and port arc layout

### Removed Dependencies
- `flutter_svg` -- no longer needed
- `path_drawing` -- no longer needed

### Interaction Improvements
- **Multi-port selection**: click multiple ports to spotlight their connections simultaneously
- **Bidirectional device-port interaction**: clicking a connected device spotlights the same connection as clicking its port
- **Connection lines follow port hover animation**: line endpoints shift with the port float (3px, 300ms easeInOut)
- **Port number overlay**: switch port labels render on top of all layers for readability

### Host/Agent Layout
- Host and agent floating devices no longer have hover/click animations (no spotlight system for these modes)
- Host ports rendered on top of connection lines for visibility
- Port labels rendered below ports with background pill for readability
- Adjusted `centerYFactor` for better vertical spacing (devices no longer clip viewport edge)

### Switch Presets
- Local switch presets (`SwitchUD1U*P`) replaced by `flutter_switch_device` presets (`Switch*P`)
- All 22 presets (6P through 48P stacked) available via package re-exports
- `SwitchDeviceFormat` replaced by `SwitchFormat` from the package

## 1.0.0
- Initial release: unified device topology view widget
- Supports host, DPU, and switch device types
- Strategy pattern for extensible layouts
