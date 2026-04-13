# Package Migration Analysis

## Overview

Migrate current custom widgets to pub.dev packages:
- `topology_view_icons` v1.3.0
- `flutter_host_device` v0.3.0
- `flutter_switch_device` v0.3.0

---

## 1. `topology_view_icons` v1.3.0 — ALL ISSUES RESOLVED

**Status:** Ready for migration.

### Mapping

| Current SVG Asset | Replacement |
|---|---|
| `host_float.svg`, `host_center.svg` | `TopoIconPainter(deviceType: .host)` |
| `dpu_float.svg`, `dpu_center.svg` | `TopoIconPainter(deviceType: .agent)` — agent ≈ DPU |
| `switch_float.svg`, `switch_6–28.svg` | `TopoIconPainter(deviceType: .switch_)` + disable extra ports |
| `unknown_float.svg` | `TopoIconPainter(deviceType: .unknown)` |
| `port_up_green/grey/black.svg` | `TopoPortPainter(status: ..., direction: PortDirection.up)` |
| `port_down_green/grey/black.svg` | `TopoPortPainter(status: ..., direction: PortDirection.down)` |
| Shadow/elevation effect | `Canvas.drawShadow()` or `MaskFilter.blur` |

### Gap Resolutions

1. **No DPU type** → Use `agent`, they are essentially the same.
2. **No port-count-specific switch chassis** → Use larger preset and black/disable unused ports at end.
3. **No port orientation** → Resolved in v1.3.0 via `direction: PortDirection.up/down/left/right`.
4. **No SvgClip / elevation / shadow** → Use pure Canvas (`Canvas.drawShadow()` or `MaskFilter.blur()`).

### What Gets Eliminated

- All 32 SVG files in `/assets/images/`
- `flutter_svg` dependency
- `path_drawing` dependency
- `SvgClip` and `SimpleShadow` custom widgets

### What Gets Gained

- Zero-asset bundle
- Dark/light theme support with auto-detection
- Built-in error state rendering
- LNM hardware illustration style
- 6 additional device types (network, router, firewall, server, generic, switchUnknown)
- 4-direction port support (up/down/left/right)

---

## 2. `flutter_host_device` v0.3.0 — ALL ISSUES RESOLVED

**Status:** Ready for migration.

### Features

- Semi-elliptical port arc layout
- Config mode support
- Static `getPortPositions()` API
- Dark/light theme support
- `centerDeviceBuilder` escape hatch
- `selectedPortNumbers: Set<int>` for multi-select
- `unselectedPortOpacity: double` for spotlight dimming
- Selected ports hold hover animation forward

### Decisions

| Topic | Decision |
|---|---|
| DPU slot-based layout | Keep old DPU layout for now; rename `dpu` → `agent`. Package can add agent slot layout later. |
| Alternating port direction | Non-issue — host ports on arc all face same direction. |
| Connection line generation | Topology view's job — uses `getPortPositions()` output. |
| Arc dimensions (1.44x vs 1.2x) | Acceptable — wider arc, more breathing room. |
| `centerYFactor` not auto-calculated | Acceptable — topology view passes the right value based on device count. |

---

## 3. `flutter_switch_device` v0.3.0 — ALL ISSUES RESOLVED

**Status:** Ready for migration.

### Features

- Full 1:1 preset coverage — all 22 presets (6P–48P stacked)
- Config mode support
- Static `getPortPositions(format, size, parentOffset:)` API
- Dark/light theme support
- `selectedPorts: Set<int>` for multi-select (note: different name from host's `selectedPortNumbers`)
- `unselectedPortOpacity: double` (default 0.15) for spotlight dimming
- Directional hover: top-row up, bottom-row down
- Stacked part deselect on re-tap (sets to 0)

### Decisions

| Topic | Decision |
|---|---|
| Opacity when no part selected | Auto-select upper switch by default |
| Small presets (6P–12P) single-row | Acceptable — port locations are correct |
| `getPortPositions()` offset | Convenience param added; consumer still obtains offset via RenderBox |

### Gains

- Active body green border indicator
- Adaptive port label colors
- Zero SVG dependency

---

## 4. `flutter_topology_view` — NOT relevant

Not related to this project. Different purpose (network graph overview vs single-device detail view). Skipped.

---

## Migration Summary

All 6 issues resolved. All 3 packages at latest versions and ready.

| Package | Version | Status |
|---|---|---|
| `topology_view_icons` | v1.3.0 | Ready |
| `flutter_host_device` | v0.3.0 | Ready |
| `flutter_switch_device` | v0.3.0 | Ready |
