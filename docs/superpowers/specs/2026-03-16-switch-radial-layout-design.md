# Switch Floating Device Layout Redesign — Radial Surround

**Date:** 2026-03-16
**Status:** Approved

## Problem

The current switch floating device layout has several issues:
- Devices overlap and crowd each other with many connections
- Devices are too close to the center switch
- The odd-above / even-below split feels arbitrary and unbalanced
- Connection lines cross and tangle, making port-to-device tracing difficult

These issues are most visible on medium switches (16-28 ports) with varying device density (sparse to dense).

## Solution

Replace the current column-based odd/even positioning with a **radial surround layout**. Devices are placed on an adaptive ellipse around the center switch, with each device's angle determined by its port's horizontal position on the switch.

## Design

### 1. Ellipse Definition

The layout ellipse is centered on the center switch widget's center point (from `CenterDeviceLayout`):

```
ellipseCenterX = center.position.dx + center.size / 2
ellipseCenterY = center.position.dy + center.size / 2
```

The ellipse uses separate horizontal and vertical radii with a fixed aspect ratio of **1.2** (wider than tall), matching the host strategy convention:

```
radiusX = radius * 1.2
radiusY = radius
```

### 2. Angle Mapping

Each device's angular position on the ellipse is derived from its connected port's horizontal position.

**Port position normalization:** Normalize using the actual port offset range (min to max X among all ports in the current layout), not the full switch widget width. This ensures devices fan across the full angular range even though port offsets cluster in the center ~25% of the SVG.

```
normalizedX = (portX - minPortX) / (maxPortX - minPortX)  // [0, 1]
```

**Angle calculation:**
- **Top-row ports (odd portNumber):** Upper half, angles from 160° (left) to 20° (right)
  ```
  angle = 160° - normalizedX * 140°   // 160° → 20°
  ```
- **Bottom-row ports (even portNumber):** Lower half, angles from 200° (left) to 340° (right)
  ```
  angle = 200° + normalizedX * 140°   // 200° → 340°
  ```

**Fallback:** If `portNumber` is null or 0, assign angle 90° (directly above center) for odd-index devices, 270° (directly below) for even-index, to avoid clustering at 0°.

**Duplicate port numbers:** If multiple devices share the same port number, they receive the same initial angle and are separated by the collision avoidance pass (Section 4).

### 3. Adaptive Radius & Device Sizing

The ellipse radius and device icon size adapt to device count.

**Radius:**
```
minDimension = min(viewportSize.width, viewportSize.height)
baseRadius = minDimension * 0.25
growthFactor = 12.0    // pixels per device
radius = (baseRadius + deviceCount * growthFactor).clamp(minDimension * 0.20, minDimension * 0.42)
```

**Device size by density tier:**

| Devices | Size Factor (of minDimension) | Clamp Range |
|---------|------------------------------|-------------|
| 1-3     | 0.10                         | [55, 100]   |
| 4-6     | 0.08                         | [45, 85]    |
| 7+      | 0.065                        | [40, 75]    |

Non-switch device types (Host, MMI, DPU, Unknown) get 0.8x multiplier as they do today.

### 4. Collision Avoidance

After initial angular placement, resolve overlaps:

1. Sort all devices by angle
2. For each adjacent pair (including wrap-around from last to first), compute Euclidean distance between centers
3. If distance < `minGap`, nudge both devices apart symmetrically along the ellipse by adjusting their angles
4. Run up to **3 passes** to handle cascading nudges (sufficient for up to 12 devices)

```
minGap = deviceSize + 30 + 8
// deviceSize = icon size
// 30 = label area (matches DevFloat circle padding convention)
// 8 = minimum visual padding between device circles
```

### 5. Viewport Clamping

All computed device positions are clamped to stay within viewport bounds:

```
margin = (deviceSize + 30) / 2 + 10
position.dx.clamp(margin, viewport.width - margin)
position.dy.clamp(margin, viewport.height - margin)
```

### 6. Connection Lines

Connection lines run from the port center to the device center. The radial layout naturally reduces crossing because the angle mapping preserves the left-to-right ordering of ports.

No changes to connection rendering (status colors, dash patterns, highlighting) or `generateConnections()` — only the device positions change, which automatically flow through to connection endpoints via `DevFloat.position`.

### 7. connectionStatus and isConfig Behavior

The current code applies different Y-offsets based on `connectionStatus` and `isConfig`. In the radial layout:

- **connectionStatus** no longer affects radial distance. All devices sit on the same ellipse regardless of status. Status is conveyed visually through connection line color/style (green solid, black dashed, red) and device circle color, which remain unchanged.
- **isConfig mode** continues to filter devices before positioning (only baseline devices with status >= 0). The filtered set is then positioned radially as normal.

### 8. Stacked Switch Handling

For stacked switches (30-48 ports):
- Port numbers are filtered by the selected part (1-24 or 25-48) as they are today
- For the filtered subset, port numbers are re-normalized to [0, 1] using the min/max port X positions within that subset (not the full 1-48 range)
- The ellipse adapts its radius to the filtered device count

### 9. Structural Change

The current `_calculateDevicePosition()` is a per-device pure function. The radial approach requires knowledge of all devices for:
- Computing the port X normalization range (min/max)
- Collision avoidance (sorting, adjacent pair comparison)

Therefore, `_calculateDevicePosition()` will be removed and its logic folded into `calculateDevicePositions()`, which will:
1. Compute all angles from port positions
2. Compute adaptive radius from device count
3. Place all devices on the ellipse
4. Run collision avoidance across the full set
5. Clamp to viewport

## Scope

### In Scope
- `SwitchLayoutStrategy.calculateDevicePositions()` — rewrite with radial ellipse positioning
- `SwitchLayoutStrategy._calculateDevicePosition()` — remove, fold logic into `calculateDevicePositions()`
- Adaptive radius and device sizing based on device count
- Collision avoidance (up to 3 passes)
- Viewport clamping

### Out of Scope
- Center device positioning (unchanged)
- Port positioning (unchanged — driven by SVG format templates)
- Connection rendering logic (unchanged)
- Floating device widgets (unchanged)
- Port interaction / highlight logic (unchanged)
- Explore connections (switch has none)

## Files to Modify

| File | Change |
|------|--------|
| `lib/src/strategies/switch_layout_strategy.dart` | Rewrite `calculateDevicePositions()`, remove `_calculateDevicePosition()` |

Single file change. No new files, no model changes, no widget changes.
