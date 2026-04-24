# Rectangle switch layout — design spec

**Date:** 2026-04-24
**Scope:** Add a second layout mode for `DeviceType.switch_` that lays floating devices in rectangular column sections above and below the chassis instead of two concentric rings. Today's circle layout stays the default; the new mode is opt-in.

## Motivation

Today's `SwitchLayoutStrategy` arranges floating devices around the switch chassis in two concentric rings (inner = real/explored, outer = baseline/config). It works well for moderately connected switches but:

- Correspondence between a port and its device is implicit — the user has to follow the angle of the connection line to figure out which port goes with which device.
- For switches with many ports (14–24 per row), the rings get dense and angles cluster tightly.
- It does not map visually onto the chassis itself: ports sit on the top/bottom edges of the chassis, but ring devices sit at arbitrary angles around it.

A rectangular layout that places each device in a column directly above/below its port makes the port→device mapping immediate and visually obvious — each device is literally "above" or "below" the port it belongs to.

## Goal

Introduce a new layout mode (`SwitchLayoutMode.rectangle`) that renders:

- Top 40% of the viewport: one column per **odd-numbered** port (top chassis row)
- Middle 20% of the viewport: the switch chassis, unchanged from today
- Bottom 40% of the viewport: one column per **even-numbered** port (bottom chassis row)

Each column has two vertical slots:
- **Outer slot** (at the screen edge, farther from the chassis) — hosts the baseline/config device
- **Actual slot** (adjacent to the chassis) — hosts the real/explored device

Actual devices always sit closer to the chassis; baseline devices always sit farther. This preserves today's "real is close, config is far" semantic from the two-ring layout, translated into vertical columns.

The 40/20/40 ratio is approximate — it describes the intended visual balance, not a hard constraint. The chassis is positioned by today's `calculateCenterLayout`, which already lands it roughly in the vertical middle.

## Non-goals

- Not changing the circle layout. Today's `SwitchLayoutStrategy` is untouched.
- Not changing how the chassis itself is drawn. `flutter_switch_device` rendering stays as-is.
- Not changing the 4 connection situations (green / black / red / black+red) — only where devices and lines are placed.
- Not changing host or agent layouts. `switchLayoutMode` is ignored when `deviceType != switch_`.
- Not exposing a runtime toggle widget. The host app sets `switchLayoutMode` via `setState` if it wants a user-facing switcher.

## Architecture

### New enum

```dart
enum SwitchLayoutMode { circle, rectangle }
```

Exported from `package:device_topology_view/device_topology_view.dart`.

### New parameter on `DeviceTopologyView`

```dart
DeviceTopologyView(
  ...,
  switchLayoutMode: SwitchLayoutMode.rectangle, // NEW, default: .circle
)
```

All other parameters keep their current meaning. When `switchLayoutMode` is omitted, the widget behaves exactly as today.

### New strategy class

`SwitchRectangleLayoutStrategy` in `lib/src/strategies/switch_rectangle_layout_strategy.dart`, implementing `DeviceLayoutStrategy` alongside the existing `SwitchLayoutStrategy`. It accepts the same constructor arguments (`isConfig`, `stackedSwitchSelectedPart`, `labelBottomPadding`) so the dispatch site can pick between the two symmetrically.

Alternatives considered and rejected:
- **Flag-inside-existing-strategy.** Adding a mode flag to `SwitchLayoutStrategy` and branching inside each method. Rejected because `calculateDevicePositions` is fundamentally different between circle (radial angles, ring radii) and rectangle (column grid), and internal branching would muddy both paths.
- **Shared base class refactor.** Splitting `SwitchLayoutStrategy` into `SwitchCircleLayoutStrategy` + `SwitchRectangleLayoutStrategy` over a shared base. Rejected because the shared surface is small (`calculateCenterLayout` and `calculatePortPositions` already delegate to `SwitchDeviceView`), so the refactor buys little and churns existing code.

### Dispatch point

Wherever `SwitchLayoutStrategy` is instantiated today in the widget layer, add:

```dart
final strategy = (deviceType == DeviceType.switch_ &&
                   switchLayoutMode == SwitchLayoutMode.rectangle)
    ? SwitchRectangleLayoutStrategy(
        isConfig: isConfig,
        stackedSwitchSelectedPart: ...,
        labelBottomPadding: ...,
      )
    : SwitchLayoutStrategy(...);  // today's path
```

## Layout algorithm

### Inputs reused from today's strategy
- `calculatePortPositions(center, format, statusMap)` — unchanged; delegates to `SwitchDeviceView.getPortPositions()`.

### `calculateCenterLayout` override (rectangle strategy only)

Today's circle strategy offsets the chassis downward via `posY = (H - Cs + Cs*0.35)/2 + Cs*0.1 - 10`, which is asymmetric by design — the ring math wants more space above the chassis center. In rectangle mode the top and bottom sections are meant to be roughly equal, so `SwitchRectangleLayoutStrategy` overrides `calculateCenterLayout` to place the chassis centered:

```dart
final double posY = (contentHeight - centerSize) / 2;
```

`centerSize` and `posX` are computed the same way as the circle strategy. This override is **local to the rectangle strategy only** — `SwitchLayoutStrategy` is not touched.

### Viewport division

Given viewport `(W, H)`, chassis at `(Cx, Cy)` with size `Cs`:

| Region | Y range | Contents |
|---|---|---|
| Top section | `[0, Cy]` | Columns for **odd-numbered** ports (top chassis row) |
| Middle | `[Cy, Cy + Cs]` | Chassis only; no floating devices |
| Bottom section | `[Cy + Cs, H]` | Columns for **even-numbered** ports (bottom chassis row) |

### Column placement (per section)

1. Collect the ports in the relevant row (odd or even), filtered to the currently selected stacked part if applicable.
2. Read each port's center X from `SwitchDeviceView.getPortPositions()`.
3. Compute `rangeMin = min(portX)`, `rangeMax = max(portX)`, and `columnCount = number of ports in that row`.
4. `columnWidth = (rangeMax - rangeMin) / (columnCount - 1)`.
5. For port at index `i` in the sorted row, column center X = `rangeMin + i * columnWidth`.

Columns are **evenly distributed between the first and last port's X** — they do not exactly align with individual port X positions when the chassis has port-group gaps (per the user's explicit pick in brainstorming). This matches the clean grid preference and avoids uneven column widths.

### Slot placement within a column

Each column has two vertical slots:
- **Outer slot** — screen edge
- **Actual slot** — adjacent to chassis

Top section: outer at the top, actual at the bottom (near the chassis).
Bottom section: actual at the top (near the chassis), outer at the bottom.

Vertical split within the section: ~55% of section height allocated to the outer slot, ~45% to the actual slot, leaving `labelBottomPadding` of margin. Actual is slightly closer to the chassis so the traffic ring has breathing room without colliding with port indicators.

### Icon sizing

Same density tiers as today's circle strategy:

| Device count | `baseDeviceSize` clamp |
|---|---|
| ≤ 3 | `[55, 100]` |
| ≤ 6 | `[45, 85]` |
| > 6 | `[40, 75]` |

- **Actual device** uses `baseDeviceSize`.
- **Baseline device** uses `baseDeviceSize * 0.7` (matches today's outer-ring device scaling).
- Non-`Switch` device types scale to 80% of their tier's size (matches today's `deviceType != 'Switch'` scaling).
- The same viewport-boost factor (`sqrt(canvasMinDim / viewportMinDim)`, clamped to `[1.0, 1.4]`) applies when the visible viewport is smaller than the canvas.

### Empty slots and ports with no device

- A port with **no device**: column is present but empty (no icons, no lines).
- A port with **only one tier filled**: the other slot is empty.

Column spacing is consistent across all ports in a row — we do not compact to skip empty ports.

### Stacked switches

For stacked formats (`Switch30PStacked` through `Switch48PStacked`) in rectangle mode:

- **Port and device filtering** matches today's behavior: `stackedSwitchSelectedPart == 1` shows ports/devices 1–24; `== 2` shows 25–48; `== 0` shows nothing.
- **Chassis visibility**: only the selected half of the stacked chassis is visible. The unselected half is hidden (opacity 0 / clipped / format substitution — exact mechanism decided during implementation, depending on what `flutter_switch_device` exposes). The top and bottom sections wrap only around the visible half-chassis.

## Connections

All connection lines reuse the existing `ConnectionLine`, `ConnectionsPainter`, and `ConnectionsLayer`. The rectangle strategy's `generateConnections` and `generateExploreConnections` produce the same `ConnectionLine` objects the painter already knows how to draw — only the source/target offsets and `forceCurve` flag differ from the circle strategy.

### Line routing by situation

| Situation | Baseline line (→ outer slot) | Actual line (→ actual slot) |
|---|---|---|
| Green only (status 1, matched) | — | **straight** green, port → actual |
| Black only (status 0, no explore) | **straight** black dashed, port → baseline | — |
| Red only (status -1, or explore-only) | — | **straight** red, port → actual |
| Black + Red mismatch (status 0 + explore) | **curved** black dashed, port → baseline (arc around actual) | **straight** red, port → actual |

The curve is applied **only** when both tiers exist on the same port — that is the only case where a straight port→baseline line would pass through the actual icon. Everywhere else, lines stay straight.

Implementation: the strategy sets `forceCurve: hasBothTiers` per-baseline-line. Today's `generateConnections` uses `forceCurve: !isConfig` unconditionally; rectangle mode makes it context-sensitive. `curveDirection` follows the same left/right stagger convention as today's outer-ring curves so the arc visibly passes around the actual icon rather than through it.

### Config mode (`isConfig: true`)

- Explore data is stripped (same as today) — actual slots stay empty.
- All baseline devices render in the outer slot with **straight grey dashed** lines. `forceCurve: false`, `isConfig: true` on every line.

### Preserved interactions

- **Port float animation**: odd ports shift up 3px, even ports shift down 3px on hover/select. `ConnectionsPainter`'s source-offset adjustment works unchanged — the target can be anywhere.
- **Spotlight / multi-select / dim-others / flowing-dash animation**: unchanged. Same painter, same `activePortNumber` / `selectedPorts` / `dashFlowValue` inputs.
- **`enableAnimations: false`**: still disables dash flow and port float.

## Public API summary

```dart
// lib/src/models/switch_layout_mode.dart (new)
enum SwitchLayoutMode { circle, rectangle }
```

```dart
// lib/device_topology_view.dart (new export)
export 'src/models/switch_layout_mode.dart';
```

```dart
// lib/src/device_topology_view.dart (widget — new field)
final SwitchLayoutMode switchLayoutMode;

const DeviceTopologyView({
  ...,
  this.switchLayoutMode = SwitchLayoutMode.circle,
});
```

The default `SwitchLayoutMode.circle` means every existing caller keeps today's behavior without any code change.

## Files changed

**New**
- `lib/src/strategies/switch_rectangle_layout_strategy.dart` — implements `DeviceLayoutStrategy` for rectangle mode.
- `lib/src/models/switch_layout_mode.dart` — the new enum.

**Modified**
- `lib/device_topology_view.dart` — export `SwitchLayoutMode`.
- `lib/src/device_topology_view.dart` — add `switchLayoutMode` field, thread it into the dispatch that picks a strategy.
- `example/lib/...` — add a mode toggle so the example demos both layouts.
- `pubspec.yaml` — bump 1.3.4 → 1.4.0.
- `CHANGELOG.md` — new entry.

**Not touched**
- `lib/src/strategies/switch_layout_strategy.dart` (circle — untouched)
- `lib/src/strategies/host_layout_strategy.dart`, `agent_layout_strategy.dart`, `slot_based_layout_strategy.dart` (other device types — untouched)
- `lib/src/models/connection_line.dart`, `lib/src/widgets/connections_painter.dart`, `dev_layer.dart`, `port_widget.dart`, `center_device_widget.dart` — reused as-is.
- All `lib/src/widgets/floating_devices/*.dart` — reused as-is.

## Edge cases

- **Very narrow viewports (W < ~500).** Columns compress but still render. Density tiers keep icons legible.
- **Ports with no device.** Empty column, no icons, no lines. Column position still reserved.
- **Switch with very few devices (e.g., 3 of 28 ports connected).** 14 columns per section still exist; 11 empty in each. Matches the user's explicit preference for port-range-based spacing.
- **Stacked format with `stackedSwitchSelectedPart == 0`.** No columns, no devices — chassis dimmed. Matches today's stacked behavior.
- **`deviceType != switch_` with `switchLayoutMode: rectangle`.** Parameter is ignored. Host and agent use their existing strategies.
- **Switch with only odd or only even ports connected.** The section for the empty row is still rendered (for chassis alignment) but contains no device icons.
- **Mismatch (baseline + explore) on a port at the leftmost or rightmost column.** The baseline curve arcs inward (away from the viewport edge) rather than outward, to stay on-canvas. Curve direction picks the side with more available horizontal space.

## Testing

**Unit tests** (`test/strategies/switch_rectangle_layout_strategy_test.dart`)
- `calculateDevicePositions` places actual devices in the adjacent slot and baseline in the outer slot for each of the 4 situations.
- Empty-port rows still reserve column space.
- Stacked-part filtering removes ports and devices outside the selected range.
- `isConfig: true` strips explore devices and puts all baselines in the outer slot.

**Widget tests** (`test/rectangle_layout_widget_test.dart`)
- Render `DeviceTopologyView` with `switchLayoutMode: rectangle` on `Switch28P` with a mix of matched / mismatch / config-only devices. Assert icon counts per section and approximate positions.
- Render same inputs in both circle and rectangle mode. Assert both produce the expected number of `DevFloat` widgets and `ConnectionLine` entries.

**Manual verification via example app**
- Add a toggle to the example so both layouts can be seen with identical data.
- Start the dev server (`flutter run -d chrome` or similar), use the toggle, and verify:
  - Toggling does not lose selection, spotlight, or stacked-part state.
  - All 4 connection situations render correctly in rectangle mode.
  - Stacked switches render only the selected half in rectangle mode.
  - `isConfig: true` renders the expected grey-dashed single-row layout in rectangle mode.

## Version bump and changelog

- `pubspec.yaml`: `version: 1.3.4` → `1.4.0` (new feature, additive API — minor bump).
- `CHANGELOG.md`: new entry describing the new layout mode, the `SwitchLayoutMode` enum, and the new `switchLayoutMode` parameter.

## Open questions for implementation planning

1. **Stacked-chassis half-hide mechanism.** Need to inspect `flutter_switch_device` to decide whether to (a) wrap the chassis in an `Opacity(opacity: 0)` clip for the unselected half, (b) apply a `ClipRect`, or (c) substitute the stacked format with a non-stacked equivalent (`Switch24P` for part 1, or similar) while keeping port numbers intact. The planning phase will pick one based on what the package exposes.
2. **Curve direction heuristic for mismatch lines at edge columns.** Simple rule: if column index is in the left half of the row, arc curves right; otherwise arc curves left. Refine during implementation if it visibly overlaps adjacent columns.
