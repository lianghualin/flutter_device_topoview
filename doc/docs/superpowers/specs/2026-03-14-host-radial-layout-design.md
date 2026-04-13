# Host Layout Redesign: Radial Fan

## Problem

The current Host topology layout has several visual issues:
- Ports in a wide semi-ellipse, floating devices in a flat row — no spatial relationship between a port and its connected switch
- Connection lines cross each other chaotically
- Explore/probe devices overlap with baseline devices, causing visual confusion
- Port labels extend the widget bounding box, causing connection line misalignment (already fixed)

## Design

### Layout: Radial Fan

Each floating device is positioned along the same radial line as its connected port, extending outward from the center device. This guarantees that connection lines fan out naturally without crossing.

**Port positions:** Semi-ellipse above the center device (unchanged from current behavior).

**Baseline device positions:** For each port at angle θ on the semi-ellipse, its connected switch is placed at the same angle θ but at a greater radius (baseline radius factor ~1.6x the port ellipse radius). This means:
- The vector from the center device to the port, extended outward, determines where the switch goes
- All connection lines point radially outward — zero crossing

**Explore device positions:** Same radial direction as the baseline device for the same port, but:
- Pushed further out (explore radius factor ~1.5x baseline radius)
- Smaller icon size (0.7x baseline device size)
- Reduced opacity (0.5–0.7) so baseline devices are visually dominant

### Connection Lines

- Baseline connections: from port center to baseline device center (existing line styles: dashed for status 0, green solid for status 1)
- Explore connections: from port center to explore device center (red, thinner, semi-transparent to match the de-emphasized device)

### What Changes

**File: `host_layout_strategy.dart`**
- `calculateDevicePositions`: Replace `_positionDevicesRecursively` (binary space partitioning) with radial positioning that uses each port's angle from `_calculatePortPositions`
- Explore devices use the same radial angle as their baseline counterpart but at a larger radius and smaller size

**File: `slot_based_layout_strategy.dart`**
- No structural changes. Connection generation already uses `port.position + port.size/2` for source and `device.position` for target.

### What Doesn't Change

- Port semi-ellipse calculation (`_calculatePortPositions`)
- Center device layout (`calculateCenterLayout`)
- Floating device widget rendering (DevFloat, SwitchDevFloat)
- Connection line rendering (ConnectionLine, ConnectionsLayer)
- Port widget rendering (PortWidget)
- DPU and Switch layout strategies
