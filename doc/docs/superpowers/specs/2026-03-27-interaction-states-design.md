# Interaction States Design

## Goal

Fix 3 interaction issues in the switch topology view: switch body hover dimming, multi-port selection, and bidirectional device-port interaction.

## Changes — all in `lib/src/device_topology_view.dart`

### 1. Switch body hover → dim everything

**Problem:** `SwitchDeviceView` may not fire `onSwitchHover`/`onSwitchHoverExit`, or the dimming isn't propagating.

**Fix:** Verify callbacks are wired and firing. The `_switchActivePort` getter already returns `-1` (dim-all sentinel) when `_isHoveringSwitch` is true. If the package doesn't support these callbacks, wrap `SwitchDeviceView` in a `MouseRegion`.

**Expected behavior:** Hovering the switch center dims all ports, lines, and floating devices to 15% opacity. Hover exit restores everything.

### 2. Multi-port selection

**Problem:** `_selectedPortNumber` is `int?` — single selection only.

**Fix:** Change to `Set<int> _selectedPorts = {}`.

- `_handlePortTap(int portNum)`: toggle port in/out of the set
- Pass `_selectedPorts` directly to `SwitchDeviceView.selectedPorts`
- Update `_switchActivePort` getter: when `_selectedPorts` is non-empty, the spotlight system uses the set (not a single port)
- Update `_updateHighlightStates()`: highlight all ports/lines/devices whose port number is in `_selectedPorts`
- `_handleTapBlank()`: clears `_selectedPorts`

### 3. Bidirectional device ↔ port interaction

**Click device = click its port:**
- `_handleDeviceSelected(int deviceId)`: find the device's `connectedPortNum`, toggle that port in `_selectedPorts`. This triggers the same spotlight as clicking the port directly.
- Remove separate `_selectedDeviceId` state — device selection IS port selection.

**Hover device = emphasize only (no dimming):**
- Device hover already works via `DevFloatWidgetState._controller.forward()` which scales up + glows.
- No change needed — the existing hover animation provides emphasis without triggering the spotlight system.

### 4. _switchActivePort getter update

```
if _selectedPorts.isNotEmpty → return first selected port (for dash flow animation)
if _hoveredPortNumber != null → return _hoveredPortNumber
if _isHoveringSwitch → return -1
else → return null
```

For multi-select dimming, `_updateHighlightStates()` uses `_selectedPorts` directly (not `_switchActivePort`). The getter is only used for dash flow animation and the `-1` sentinel.

### State table

| Action | Active | Dimmed | Deselect |
|---|---|---|---|
| Hover switch body | Switch only | All ports/lines/devices → 15% | Hover exit |
| Hover port | Port + line + device | Others → 15% | Hover exit |
| Click port (toggle) | Port + line + device (persists) | Others → 15% | Click same port, or tap blank |
| Click multiple ports | All selected connections | Unselected → 15% | Click each to deselect, or tap blank |
| Click device | Device + line + port (= clicking its port) | Others → 15% | Click same device, or tap blank |
| Hover device | Device emphasized (scale+glow) | Nothing dimmed | Hover exit |
| Tap blank | — | — | Clears all |
