## 1.6.0

### New Features
- **Switch-unknown device float**: A `PortDevice` with `deviceType: 'SwitchUnknown'` now renders the switch-shaped unknown icon (`TopoDeviceType.switchUnknown` from `topology_view_icons`) instead of falling through to the host-shaped "?" `Unknown` float. Use it for a port that likely cascades an undeclared downstream switch (e.g. a port that learned ≥2 MACs with no baseline switch), so it no longer reads as a failed host probe. Supported in both `SwitchLayoutMode.circle` and `SwitchLayoutMode.rectangle`. Any unrecognized `deviceType` still falls back to the `Unknown` float, so existing callers are unaffected.

### Notes
- The example app's switch view now includes a `SwitchUnknown` port so the new icon is visible out of the box.

## 1.5.0

### New Features
- **Scale-to-fit (`fit` parameter)**: New optional `BoxFit? fit` on `DeviceTopologyView` that wraps the rendered topology in a `FittedBox` so it scales to the actual viewport. Use `BoxFit.scaleDown` to only shrink when the viewport is smaller than the layout strategy's minimum size (1500×800 for switch layouts), or `BoxFit.contain` to always fit. When omitted (the default), behavior is unchanged — the diagram still renders at its strategy minimum and may overflow smaller viewports, preserving backwards compatibility.

### New API
- `DeviceTopologyView.fit` parameter (defaults to `null`).

### Notes
- Pan/zoom interactions remain available when `fit` is enabled. The user-driven `Transform` (scroll-wheel zoom, drag-to-pan) operates inside the `FittedBox`, so wheel zoom continues to scale relative to the on-screen content. Drag deltas are still measured in logical pixels, so panning while the content is fitted-down can feel slightly faster than 1:1 — acceptable for the opt-in fit mode.

## 1.4.0

### New Features
- **Rectangle switch layout (`SwitchLayoutMode.rectangle`)**: New opt-in layout for `DeviceType.switch_` that arranges floating devices in column sections above and below the chassis instead of two concentric rings. Only ports with a connected device get a column; those columns are distributed evenly across the full viewport width with a small edge margin, and connection lines slant from each port on the chassis to its device column. Pass `switchLayoutMode: SwitchLayoutMode.rectangle` on `DeviceTopologyView` to enable. The default `SwitchLayoutMode.circle` preserves the original behavior — existing callers are unaffected.
- **Four connection situations preserved**: green (matched), black dashed (configured-only), red (probed / explore-only), and black+red (mismatch) all render in rectangle mode. In the mismatch case, the baseline line curves around the actual device icon.
- **Stacked-switch handling**: On `Switch30PStacked`–`Switch48PStacked`, rectangle mode hides the unused half of the chassis so device columns only surround the active part.
- **Config mode**: `isConfig: true` in rectangle mode collapses to baseline-only columns on the outer row with straight grey-dashed lines, mirroring circle-mode semantics.

### New API
- `SwitchLayoutMode` enum exported from `package:device_topology_view/device_topology_view.dart`.
- `DeviceTopologyView.switchLayoutMode` parameter (defaults to `SwitchLayoutMode.circle`).

### Layout tuning
- Chassis is vertically centered in rectangle mode (the circle strategy's asymmetric offset is specific to the ring layout).
- Actual devices anchor close to the chassis edge (top section: 15 px gap; bottom section: flush) so the port→actual line reads as a short vertical link. Baseline icons sit in the outer quarter of their section, near the screen edge.

### Internal
- Added `SwitchRectangleLayoutStrategy` alongside `SwitchLayoutStrategy`. Circle rendering is entirely unchanged.
- Rectangle mode overrides `calculateCenterLayout` to center the chassis and generates context-sensitive curve flags on connection lines (baseline curve only when the same port also has an actual device).

## 1.3.4

### Bug Fixes
- **Label alignment for non-ring devices**: Wrapped the Column layout in a `SizedBox(width: visualSize)` so long device labels no longer shift the icon center horizontally, keeping connection line endpoints aligned
- **Bottom label clipping**: Added extra bottom margin to device position clamping in all layout strategies (switch, host, agent) so labels near the viewport edge are fully visible

### New Parameters
- **`labelBottomPadding`**: Configurable extra bottom margin (default `40.0`) to prevent device labels from being clipped at the viewport edge. Increase for longer device names.

## 1.3.3

### Improvements
- **Double-tap to navigate**: Single tap on a floating device now only toggles port spotlight; double-tap triggers the external navigation callback (`onDeviceTappedExternally`)

### Dependencies
- Upgraded `flutter_device_ring` to `^0.3.0`

## 1.3.2

### Bug Fixes
- **Baseline connection alignment**: Dashed baseline connection lines now target the center of the device icon instead of the center of the status halo. Removed erroneous bottom padding from `buildDeviceIcon()` in all device types (host, switch, agent, unknown) that shifted icons 8px above the halo center.

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
