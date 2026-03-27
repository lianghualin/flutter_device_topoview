import 'package:flutter/material.dart';
import 'package:flutter_host_device/flutter_host_device.dart' hide PortStatus;
import 'package:flutter_host_device/flutter_host_device.dart'
    as host_pkg show PortStatus;
import 'package:flutter_switch_device/flutter_switch_device.dart' hide PortStatus;
import 'package:flutter_switch_device/flutter_switch_device.dart'
    as switch_pkg show PortStatus;
import 'models/device_type.dart';
import 'models/port_device.dart';
import 'models/device_format.dart';
import 'models/port_status.dart';
import 'models/port.dart';
import 'models/connection_line.dart';
import 'widgets/floating_devices/dev_float.dart';
import 'widgets/center_device_widget.dart';
import 'widgets/connections_painter.dart';
import 'widgets/dev_layer.dart';
import 'widgets/port_layer.dart';
import 'strategies/device_layout_strategy.dart';
import 'strategies/host_layout_strategy.dart';
import 'strategies/agent_layout_strategy.dart';
import 'strategies/switch_layout_strategy.dart';
import 'mixins/pan_zoom_mixin.dart';

class DeviceTopologyView extends StatefulWidget {
  const DeviceTopologyView({
    required this.size,
    required this.deviceType,
    required this.format,
    required this.portDevices,
    required this.portStatusMap,
    required this.centerLabel,
    this.isConfig = false,
    this.onDeviceSelected,
    this.initialStackedSwitchPart,
    this.onStackedSwitchPartChanged,
    this.enableAnimations = true,
    this.showOuterRing = true,
    super.key,
  });

  final Size size;
  final DeviceType deviceType;
  final Object format;
  final List<PortDevice> portDevices;
  final Map<String, PortStatus> portStatusMap;
  final String centerLabel;
  final bool isConfig;
  final void Function(String deviceName, String deviceType, int? portNum)?
      onDeviceSelected;
  final int? initialStackedSwitchPart;
  final void Function(int part)? onStackedSwitchPartChanged;
  final bool enableAnimations;
  final bool showOuterRing;

  @override
  State<DeviceTopologyView> createState() => _DeviceTopologyViewState();
}

class _DeviceTopologyViewState extends State<DeviceTopologyView>
    with PanZoomMixin, TickerProviderStateMixin {
  // Layout strategy
  late DeviceLayoutStrategy _strategy;

  // Dash flow animation for connection lines
  late AnimationController _dashFlowController;

  // Computed layout state
  late CenterDeviceLayout _centerLayout;
  List<Port> _ports = [];
  late DevicePositions _devicePositions;
  List<DevFloat> _baseDevices = [];
  List<DevFloat> _exploreDevices = [];
  List<ConnectionLine> _baseConnections = [];
  List<ConnectionLine> _exploreConnections = [];
  double _contentWidth = 0;
  double _contentHeight = 0;

  // Switch-specific state
  int _stackedSwitchSelectedPart = 0;
  Set<int> _selectedPorts = {};
  int? _hoveredPortNumber;

  /// Active port for spotlight dimming (switch only).
  /// Returns a port number when a port is hovered or selected (spotlight mode).
  /// Returns null when no port interaction (no dimming).
  int? get _switchActivePort {
    if (widget.deviceType != DeviceType.switch_) return null;
    if (_selectedPorts.isNotEmpty) return _selectedPorts.first;
    if (_hoveredPortNumber != null) return _hoveredPortNumber;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _dashFlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Don't start yet — only runs when spotlight is active
    _stackedSwitchSelectedPart = widget.initialStackedSwitchPart ?? 0;
    _createStrategy();
    _initializeLayout();
  }

  @override
  void dispose() {
    _dashFlowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DeviceTopologyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size ||
        widget.deviceType != oldWidget.deviceType ||
        widget.format != oldWidget.format ||
        widget.isConfig != oldWidget.isConfig ||
        !identical(widget.portDevices, oldWidget.portDevices) ||
        !identical(widget.portStatusMap, oldWidget.portStatusMap)) {
      _createStrategy();
      _initializeLayout();
    }
    if (widget.enableAnimations != oldWidget.enableAnimations) {
      _updateDashFlow();
    }
  }

  void _createStrategy() {
    switch (widget.deviceType) {
      case DeviceType.host:
        _strategy = HostLayoutStrategy(
          deviceCount: widget.portDevices.length,
        );
        break;
      case DeviceType.agent:
        _strategy = AgentLayoutStrategy();
        break;
      case DeviceType.switch_:
        _strategy = SwitchLayoutStrategy(
          isConfig: widget.isConfig,
          stackedSwitchSelectedPart: _stackedSwitchSelectedPart,
        );
        break;
    }
  }

  void _initializeLayout() {
    // Determine content size
    if (widget.deviceType == DeviceType.switch_ &&
        widget.format is SwitchFormat) {
      final switchFormat = widget.format as SwitchFormat;
      _contentWidth = widget.size.width < switchFormat.minWidth
          ? switchFormat.minWidth
          : widget.size.width;
      _contentHeight = widget.size.height < switchFormat.minHeight
          ? switchFormat.minHeight
          : widget.size.height;
    } else {
      _contentWidth = widget.size.width;
      _contentHeight = widget.size.height;
    }

    final viewportSize = Size(_contentWidth, _contentHeight);

    // Step 1: Calculate center layout
    _centerLayout =
        _strategy.calculateCenterLayout(viewportSize, widget.format);

    // Step 2: Calculate port positions
    _ports = _strategy.calculatePortPositions(
        _centerLayout, widget.format, widget.portStatusMap);

    // Step 3: Calculate device positions
    _devicePositions = _strategy.calculateDevicePositions(
        viewportSize, _centerLayout, widget.portDevices, _ports);

    // Step 4: Build floating devices
    final allDevFloats =
        _strategy.buildFloatingDevices(_devicePositions, widget.portDevices);

    // Split into base and explore devices
    final int baseCount = _devicePositions.baselineDevices.length;
    _baseDevices = allDevFloats.take(baseCount).toList();
    _exploreDevices = allDevFloats.skip(baseCount).toList();

    // Step 5: Generate connection lines
    _baseConnections =
        _strategy.generateConnections(_ports, _baseDevices, widget.portDevices);
    if (widget.isConfig) {
      // Config mode: no explore data, only baseline
      _exploreConnections = [];
      _exploreDevices = [];
    } else {
      _exploreConnections = _strategy.generateExploreConnections(
          _ports, _exploreDevices, widget.portDevices);
    }

    // Debug: print all element positions
    debugPrint('=== LAYOUT DEBUG ===');
    debugPrint('Viewport: ${_contentWidth.toStringAsFixed(0)} x ${_contentHeight.toStringAsFixed(0)}');
    debugPrint('Center: pos=(${_centerLayout.position.dx.toStringAsFixed(0)}, ${_centerLayout.position.dy.toStringAsFixed(0)}) size=${_centerLayout.size.toStringAsFixed(0)}');
    for (int i = 0; i < _ports.length; i++) {
      final p = _ports[i];
      final cx = (p.position.dx + p.width / 2).toStringAsFixed(0);
      final cy = (p.position.dy + p.height / 2).toStringAsFixed(0);
      debugPrint('Port[$i] "${p.label}": center=($cx, $cy)');
    }
    for (int i = 0; i < _devicePositions.baselineDevices.length; i++) {
      final d = _devicePositions.baselineDevices[i];
      final name = d.device.deviceName;
      debugPrint('Baseline[$i] "$name": pos=(${d.position.dx.toStringAsFixed(0)}, ${d.position.dy.toStringAsFixed(0)}) size=${d.size.toStringAsFixed(0)}');
      final visualTop = d.position.dy - (d.size + 30) / 2;
      final visualLeft = d.position.dx - (d.size + 30) / 2;
      final visualBottom = d.position.dy + (d.size + 30) / 2;
      final visualRight = d.position.dx + (d.size + 30) / 2;
      debugPrint('  visual bounds: (${visualLeft.toStringAsFixed(0)}, ${visualTop.toStringAsFixed(0)}) -> (${visualRight.toStringAsFixed(0)}, ${visualBottom.toStringAsFixed(0)})');
      if (visualTop < 0 || visualLeft < 0 || visualBottom > _contentHeight || visualRight > _contentWidth) {
        debugPrint('  ⚠️ OUT OF BOUNDS!');
      }
    }
    for (int i = 0; i < _devicePositions.exploreDevices.length; i++) {
      final d = _devicePositions.exploreDevices[i];
      final name = d.device.exploreDevName ?? d.device.deviceName;
      debugPrint('Explore[$i] "$name": pos=(${d.position.dx.toStringAsFixed(0)}, ${d.position.dy.toStringAsFixed(0)}) size=${d.size.toStringAsFixed(0)}');
      final visualTop = d.position.dy - (d.size + 30) / 2;
      final visualLeft = d.position.dx - (d.size + 30) / 2;
      final visualBottom = d.position.dy + (d.size + 30) / 2;
      final visualRight = d.position.dx + (d.size + 30) / 2;
      debugPrint('  visual bounds: (${visualLeft.toStringAsFixed(0)}, ${visualTop.toStringAsFixed(0)}) -> (${visualRight.toStringAsFixed(0)}, ${visualBottom.toStringAsFixed(0)})');
      if (visualTop < 0 || visualLeft < 0 || visualBottom > _contentHeight || visualRight > _contentWidth) {
        debugPrint('  ⚠️ OUT OF BOUNDS!');
      }
    }
    // Check for overlaps between all elements
    final List<_DebugRect> allRects = [];
    // Center device — use actual rendered dimensions (wSizeFactor × hSizeFactor)
    final double debugWSizeFactor = widget.format is DeviceFormat
        ? (widget.format as DeviceFormat).wSizeFactor
        : widget.format is SwitchFormat
            ? (widget.format as SwitchFormat).wSizeFactor
            : 1.0;
    final double debugHSizeFactor = widget.format is DeviceFormat
        ? (widget.format as DeviceFormat).hSizeFactor
        : widget.format is SwitchFormat
            ? (widget.format as SwitchFormat).hSizeFactor
            : 0.15;
    final double centerW = _centerLayout.size * debugWSizeFactor;
    final double centerH = _centerLayout.size * debugHSizeFactor;
    final double centerLeft = _centerLayout.position.dx + _centerLayout.size * (1 - debugWSizeFactor);
    final double centerTop = _centerLayout.position.dy + _centerLayout.size * debugHSizeFactor;
    allRects.add(_DebugRect(
      'Center',
      centerLeft,
      centerTop,
      centerLeft + centerW,
      centerTop + centerH,
    ));
    // Baseline devices
    for (int i = 0; i < _devicePositions.baselineDevices.length; i++) {
      final d = _devicePositions.baselineDevices[i];
      final half = (d.size + 30) / 2;
      allRects.add(_DebugRect(
        'Baseline "${d.device.deviceName}"',
        d.position.dx - half, d.position.dy - half,
        d.position.dx + half, d.position.dy + half,
      ));
    }
    // Explore devices
    for (int i = 0; i < _devicePositions.exploreDevices.length; i++) {
      final d = _devicePositions.exploreDevices[i];
      final half = (d.size + 30) / 2;
      allRects.add(_DebugRect(
        'Explore "${d.device.exploreDevName ?? d.device.deviceName}"',
        d.position.dx - half, d.position.dy - half,
        d.position.dx + half, d.position.dy + half,
      ));
    }
    // Check all pairs
    for (int i = 0; i < allRects.length; i++) {
      for (int j = i + 1; j < allRects.length; j++) {
        final a = allRects[i];
        final b = allRects[j];
        if (a.left < b.right && a.right > b.left &&
            a.top < b.bottom && a.bottom > b.top) {
          final overlapX = (a.right.clamp(b.left, b.right) - a.left.clamp(b.left, b.right)).abs();
          final overlapY = (a.bottom.clamp(b.top, b.bottom) - a.top.clamp(b.top, b.bottom)).abs();
          debugPrint('  🔴 OVERLAP: ${a.name} ↔ ${b.name} (${overlapX.toStringAsFixed(0)}x${overlapY.toStringAsFixed(0)}px)');
        }
      }
    }
    debugPrint('===================');

    // Apply highlight states for switch mode
    if (widget.deviceType == DeviceType.switch_) {
      _updateHighlightStates();
    }
  }

  // ---------------------------------------------------------------------------
  // Switch-specific highlight logic
  // ---------------------------------------------------------------------------

  void _updateHighlightStates() {
    // Reset all ports to non-highlighted
    _ports = _ports
        .map((p) => p.copyWith(isSelected: false, isHovered: false))
        .toList();

    // Reset all connections to non-highlighted
    _baseConnections = _baseConnections
        .map((c) => ConnectionLine(
              sourceOffset: c.sourceOffset,
              targetOffset: c.targetOffset,
              status: c.status,
              isHighlighted: false,
              slotId: c.slotId,
              portNumber: c.portNumber,
              isConfig: c.isConfig,
              curveDirection: c.curveDirection,
              forceCurve: c.forceCurve,
            ))
        .toList();
    _exploreConnections = _exploreConnections
        .map((c) => ConnectionLine(
              sourceOffset: c.sourceOffset,
              targetOffset: c.targetOffset,
              status: c.status,
              isHighlighted: false,
              slotId: c.slotId,
              portNumber: c.portNumber,
              isConfig: c.isConfig,
              curveDirection: c.curveDirection,
              forceCurve: c.forceCurve,
            ))
        .toList();

    // Reset all devices to non-highlighted
    for (final device in _baseDevices) {
      device.isHighlighted = false;
    }
    for (final device in _exploreDevices) {
      device.isHighlighted = false;
    }

    // Collect all active ports: selected ports + hovered port
    final Set<int> activePorts = {..._selectedPorts};
    if (_hoveredPortNumber != null) {
      activePorts.add(_hoveredPortNumber!);
    }

    if (activePorts.isNotEmpty) {
      // Highlight matching ports
      _ports = _ports.map((p) {
        if (activePorts.contains(p.portNumber)) {
          return p.copyWith(
            isSelected: _selectedPorts.contains(p.portNumber),
            isHovered: _hoveredPortNumber == p.portNumber &&
                !_selectedPorts.contains(p.portNumber),
          );
        }
        return p;
      }).toList();

      // Highlight matching connections (baseline)
      _baseConnections = _baseConnections.map((c) {
        if (activePorts.contains(c.portNumber)) {
          return ConnectionLine(
            sourceOffset: c.sourceOffset,
            targetOffset: c.targetOffset,
            status: c.status,
            isHighlighted: true,
            slotId: c.slotId,
            portNumber: c.portNumber,
            isConfig: c.isConfig,
            curveDirection: c.curveDirection,
            forceCurve: c.forceCurve,
          );
        }
        return c;
      }).toList();

      // Highlight matching connections (explore)
      _exploreConnections = _exploreConnections.map((c) {
        if (activePorts.contains(c.portNumber)) {
          return ConnectionLine(
            sourceOffset: c.sourceOffset,
            targetOffset: c.targetOffset,
            status: c.status,
            isHighlighted: true,
            slotId: c.slotId,
            portNumber: c.portNumber,
            isConfig: c.isConfig,
            curveDirection: c.curveDirection,
            forceCurve: c.forceCurve,
          );
        }
        return c;
      }).toList();

      // Highlight matching devices (baseline)
      for (final device in _baseDevices) {
        if (activePorts.contains(device.connectedPortNum)) {
          device.isHighlighted = true;
        }
      }

      // Highlight matching devices (explore)
      for (final device in _exploreDevices) {
        if (activePorts.contains(device.connectedPortNum)) {
          device.isHighlighted = true;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _handleStackedPartChanged(int part) {
    setState(() {
      _stackedSwitchSelectedPart = part;
      _createStrategy();
      _initializeLayout();
    });
    widget.onStackedSwitchPartChanged?.call(part);
  }

  void _handlePortTap(int portNum) {
    setState(() {
      // Toggle: if already selected, deselect; otherwise add to selection
      if (_selectedPorts.contains(portNum)) {
        _selectedPorts.remove(portNum);
      } else {
        _selectedPorts.add(portNum);

        // For stacked switches: auto-switch to the correct part
        if (widget.format is SwitchFormat) {
          final switchFormat = widget.format as SwitchFormat;
          if (switchFormat.isStacked) {
            final int halfPorts = switchFormat.totalPortsNum ~/ 2;
            final int targetPart = portNum <= halfPorts ? 1 : 2;
            if (_stackedSwitchSelectedPart != targetPart) {
              _stackedSwitchSelectedPart = targetPart;
              _createStrategy();
              _initializeLayout();
            }
            widget.onStackedSwitchPartChanged?.call(targetPart);
          }
        }
      }
      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  /// Start or stop the dash flow animation based on spotlight state.
  void _updateDashFlow() {
    if (widget.enableAnimations && _switchActivePort != null && _switchActivePort != -1) {
      if (!_dashFlowController.isAnimating) {
        _dashFlowController.repeat();
      }
    } else {
      if (_dashFlowController.isAnimating) {
        _dashFlowController.stop();
        _dashFlowController.value = 0;
      }
    }
  }

  void _handlePortHover(int portNum) {
    setState(() {
      _hoveredPortNumber = portNum;
      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  void _handlePortHoverExit() {
    setState(() {
      _hoveredPortNumber = null;
      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  // Note: onSwitchHover/onSwitchHoverExit from SwitchDeviceView are not used
  // because the package wraps a MouseRegion around the full viewport, which
  // would dim everything whenever the mouse is anywhere in the view.
  // Dimming is instead triggered only by port hover/selection.

  void _handleDeviceSelected(int deviceId) {
    setState(() {
      // Find the port number connected to this device
      final device = [..._baseDevices, ..._exploreDevices]
          .where((d) => d.deviceId == deviceId)
          .firstOrNull;

      if (device != null) {
        final portNum = device.connectedPortNum;
        if (_selectedPorts.contains(portNum)) {
          _selectedPorts.remove(portNum);
        } else {
          _selectedPorts.add(portNum);
        }
      }

      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  void _handleTapBlank() {
    setState(() {
      _selectedPorts.clear();
      _hoveredPortNumber = null;
      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  void _handleClearPortHighlight({int? deviceToKeepHighlighted}) {
    setState(() {
      _selectedPorts.clear();
      _hoveredPortNumber = null;
      if (deviceToKeepHighlighted != null) {
        // Device ID is the same as connectedPortNum, so add it as a selected port
        _selectedPorts.add(deviceToKeepHighlighted);
      }
      _updateHighlightStates();
      _updateDashFlow();
    });
  }

  // ---------------------------------------------------------------------------
  // Host port status / label conversion
  // ---------------------------------------------------------------------------

  /// Converts the local [PortStatus] map (String keys) to the package's
  /// [host_pkg.PortStatus] map (int keys) for [HostDeviceView].
  ///
  /// Host ports use the same reversed-entry ordering as the layout strategy:
  /// port 1 = last statusMap entry, port 2 = second-to-last, etc.
  Map<int, host_pkg.PortStatus> _buildHostPortStatuses() {
    final result = <int, host_pkg.PortStatus>{};
    final reversed = widget.portStatusMap.entries.toList().reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      final int portNum = i + 1;
      switch (reversed[i].value) {
        case PortStatus.up:
          result[portNum] = host_pkg.PortStatus.up;
          break;
        case PortStatus.down:
          result[portNum] = host_pkg.PortStatus.down;
          break;
        case PortStatus.unknown:
          result[portNum] = host_pkg.PortStatus.unknown;
          break;
      }
    }
    return result;
  }

  /// Builds port labels for [HostDeviceView].
  /// Maps 1-based port numbers to the portId strings from the statusMap.
  Map<int, String> _buildHostPortLabels() {
    final result = <int, String>{};
    final reversed = widget.portStatusMap.entries.toList().reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      result[i + 1] = reversed[i].key;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Switch port status conversion
  // ---------------------------------------------------------------------------

  /// Converts the local [PortStatus] map (String keys) to the package's
  /// [switch_pkg.PortStatus] map (int keys) for [SwitchDeviceView].
  Map<int, switch_pkg.PortStatus> _buildSwitchPortStatuses() {
    final result = <int, switch_pkg.PortStatus>{};
    for (final entry in widget.portStatusMap.entries) {
      final portNum = int.tryParse(entry.key);
      if (portNum == null) continue;
      switch (entry.value) {
        case PortStatus.up:
          result[portNum] = switch_pkg.PortStatus.up;
          break;
        case PortStatus.down:
          result[portNum] = switch_pkg.PortStatus.down;
          break;
        case PortStatus.unknown:
          result[portNum] = switch_pkg.PortStatus.unknown;
          break;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: GestureDetector(
        onTap: _handleTapBlank,
        behavior: HitTestBehavior.translucent,
        child: GestureDetector(
        onPanStart: handlePanStart,
        onPanUpdate: (details) =>
            handlePanUpdate(details, _contentWidth, _contentHeight),
        onPanEnd: handlePanEnd,
        child: Listener(
          onPointerSignal: (event) =>
              handlePointerSignal(event, _contentWidth, _contentHeight),
          child: Transform(
            transform: transformMatrix,
            alignment: Alignment.center,
            child: SizedBox(
              width: _contentWidth,
              height: _contentHeight,
              child: Stack(
                children: [
                  // Layer 1: Center device (+ ports for switch/host mode)
                  if (widget.deviceType == DeviceType.switch_ &&
                      widget.format is SwitchFormat)
                    SwitchDeviceView(
                      size: Size(_contentWidth, _contentHeight),
                      format: widget.format as SwitchFormat,
                      portStatuses: _buildSwitchPortStatuses(),
                      isConfig: widget.isConfig,
                      onPortHover: _handlePortHover,
                      onPortHoverExit: _handlePortHoverExit,
                      onPortTap: _handlePortTap,
                      stackedPart: _stackedSwitchSelectedPart,
                      onStackedPartChanged: _handleStackedPartChanged,
                      selectedPorts: _selectedPorts,
                    )
                  else if (widget.deviceType == DeviceType.host)
                    HostDeviceView(
                      size: Size(_contentWidth, _contentHeight),
                      portCount: widget.portStatusMap.length,
                      portStatuses: _buildHostPortStatuses(),
                      portLabels: _buildHostPortLabels(),
                      isConfig: widget.isConfig,
                      centerLabel: widget.centerLabel,
                      centerYFactor: widget.portDevices.length <= 2
                          ? 0.55
                          : widget.portDevices.length <= 4
                              ? 0.63
                              : 0.72,
                    )
                  else
                    CenterDeviceLayer(
                      layout: _centerLayout,
                      format: widget.format,
                      label: widget.centerLabel,
                      deviceType: widget.deviceType,
                      stackedSwitchPart: _stackedSwitchSelectedPart,
                      onStackedPartChanged: _handleStackedPartChanged,
                    ),
                  // Layer 2: Explore connections
                  AnimatedBuilder(
                    animation: _dashFlowController,
                    builder: (context, _) => ConnectionsLayer(
                      connections: _exploreConnections,
                      activePortNumber: _switchActivePort,
                      dashFlowValue: widget.enableAnimations ? _dashFlowController.value : 0,
                    ),
                  ),
                  // Layer 3: Explore floating devices
                  DevLayer(
                    devices: _exploreDevices,
                    onExternalDeviceSelected: widget.onDeviceSelected,
                    activePortNumber: _switchActivePort,
                    enableAnimations: widget.enableAnimations,
                  ),
                  // Layer 4: Outer ring connections (config/baseline)
                  if (widget.showOuterRing)
                    AnimatedBuilder(
                      animation: _dashFlowController,
                      builder: (context, _) => ConnectionsLayer(
                        connections: _baseConnections,
                        activePortNumber: _switchActivePort,
                        dashFlowValue: widget.enableAnimations ? _dashFlowController.value : 0,
                        dimOnly: true,
                      ),
                    ),
                  // Layer 5: Outer ring floating devices (config/baseline)
                  if (widget.showOuterRing)
                    DevLayer(
                      devices: _baseDevices,
                      onDeviceSelected: _handleDeviceSelected,
                      onClearPortHighlight: _handleClearPortHighlight,
                      onExternalDeviceSelected: widget.onDeviceSelected,
                      activePortNumber: _switchActivePort,
                      enableAnimations: widget.enableAnimations,
                    ),
                  // Layer 6: Ports (agent only; Switch/HostDeviceView render their own)
                  if (widget.deviceType == DeviceType.agent)
                    PortLayer(
                      ports: _ports,
                      onPortHover: null,
                      onPortHoverExit: null,
                      onPortTap: null,
                      isConfig: widget.isConfig,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _DebugRect {
  final String name;
  final double left, top, right, bottom;
  const _DebugRect(this.name, this.left, this.top, this.right, this.bottom);
}
