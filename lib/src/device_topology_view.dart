import 'package:flutter/material.dart';
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
import 'strategies/dpu_layout_strategy.dart';
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
    super.key,
  });

  final Size size;
  final DeviceType deviceType;
  final DeviceFormat format;
  final List<PortDevice> portDevices;
  final Map<String, PortStatus> portStatusMap;
  final String centerLabel;
  final bool isConfig;
  final void Function(String deviceName, String deviceType, int? portNum)?
      onDeviceSelected;
  final int? initialStackedSwitchPart;
  final void Function(int part)? onStackedSwitchPartChanged;

  @override
  State<DeviceTopologyView> createState() => _DeviceTopologyViewState();
}

class _DeviceTopologyViewState extends State<DeviceTopologyView>
    with PanZoomMixin {
  // Layout strategy
  late DeviceLayoutStrategy _strategy;

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
  int? _selectedDeviceId;
  int _stackedSwitchSelectedPart = 0;
  int? _selectedPortNumber;
  int? _hoveredPortNumber;

  @override
  void initState() {
    super.initState();
    _stackedSwitchSelectedPart = widget.initialStackedSwitchPart ?? 0;
    _createStrategy();
    _initializeLayout();
  }

  @override
  void didUpdateWidget(DeviceTopologyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size ||
        !identical(widget.portDevices, oldWidget.portDevices) ||
        !identical(widget.portStatusMap, oldWidget.portStatusMap)) {
      _createStrategy();
      _initializeLayout();
    }
  }

  void _createStrategy() {
    switch (widget.deviceType) {
      case DeviceType.host:
        _strategy = HostLayoutStrategy();
        break;
      case DeviceType.dpu:
        _strategy = DpuLayoutStrategy();
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
        widget.format is SwitchDeviceFormat) {
      final switchFormat = widget.format as SwitchDeviceFormat;
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
    _exploreConnections = _strategy.generateExploreConnections(
        _ports, _exploreDevices, widget.portDevices);

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
            ))
        .toList();

    // Reset all devices to non-highlighted
    for (final device in _baseDevices) {
      device.isHighlighted = false;
    }

    // Determine the active port (selected takes priority over hovered)
    final int? activePort = _selectedPortNumber ?? _hoveredPortNumber;

    if (activePort != null) {
      // Highlight the matching port
      _ports = _ports.map((p) {
        if (p.portNumber == activePort) {
          return p.copyWith(
            isSelected: _selectedPortNumber == activePort,
            isHovered: _hoveredPortNumber == activePort &&
                _selectedPortNumber != activePort,
          );
        }
        return p;
      }).toList();

      // Highlight the matching connection
      _baseConnections = _baseConnections.map((c) {
        if (c.portNumber == activePort) {
          return ConnectionLine(
            sourceOffset: c.sourceOffset,
            targetOffset: c.targetOffset,
            status: c.status,
            isHighlighted: true,
            slotId: c.slotId,
            portNumber: c.portNumber,
            isConfig: c.isConfig,
          );
        }
        return c;
      }).toList();

      // Highlight the matching device
      for (final device in _baseDevices) {
        if (device.connectedPortNum == activePort) {
          device.isHighlighted = true;
        }
      }
    } else if (_selectedDeviceId != null) {
      // If no active port but a device is selected, highlight its connection
      for (final device in _baseDevices) {
        if (device.deviceId == _selectedDeviceId) {
          device.isHighlighted = true;
          // Also highlight the connection to this device
          _baseConnections = _baseConnections.map((c) {
            if (c.portNumber == device.connectedPortNum) {
              return ConnectionLine(
                sourceOffset: c.sourceOffset,
                targetOffset: c.targetOffset,
                status: c.status,
                isHighlighted: true,
                slotId: c.slotId,
                portNumber: c.portNumber,
                isConfig: c.isConfig,
              );
            }
            return c;
          }).toList();
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
      widget.onStackedSwitchPartChanged?.call(part);
      // Recreate strategy with the new part and re-initialize layout
      _createStrategy();
      _initializeLayout();
    });
  }

  void _handlePortTap(int portNum) {
    setState(() {
      // Toggle: if already selected, deselect; otherwise select
      if (_selectedPortNumber == portNum) {
        _selectedPortNumber = null;
      } else {
        _selectedPortNumber = portNum;

        // For stacked switches: auto-switch to the correct part
        if (widget.format is SwitchDeviceFormat) {
          final switchFormat = widget.format as SwitchDeviceFormat;
          if (switchFormat.isStacked) {
            final int targetPart = portNum <= 24 ? 1 : 2;
            if (_stackedSwitchSelectedPart != targetPart) {
              _stackedSwitchSelectedPart = targetPart;
              widget.onStackedSwitchPartChanged?.call(targetPart);
              _createStrategy();
              _initializeLayout();
              // _updateHighlightStates will be called below
            }
          }
        }
      }
      _updateHighlightStates();
    });
  }

  void _handlePortHover(int portNum) {
    setState(() {
      _hoveredPortNumber = portNum;
      _updateHighlightStates();
    });
  }

  void _handlePortHoverExit() {
    setState(() {
      _hoveredPortNumber = null;
      _updateHighlightStates();
    });
  }

  void _handleDeviceSelected(int deviceId) {
    setState(() {
      // Toggle: if already selected, deselect; otherwise select
      if (_selectedDeviceId == deviceId) {
        _selectedDeviceId = null;
      } else {
        _selectedDeviceId = deviceId;
      }
      _updateHighlightStates();
    });
  }

  void _handleClearPortHighlight({int? deviceToKeepHighlighted}) {
    setState(() {
      _selectedPortNumber = null;
      _hoveredPortNumber = null;
      if (deviceToKeepHighlighted != null) {
        _selectedDeviceId = deviceToKeepHighlighted;
      }
      _updateHighlightStates();
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
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
                  // Layer 1: Center device
                  CenterDeviceLayer(
                    layout: _centerLayout,
                    format: widget.format,
                    label: widget.centerLabel,
                    deviceType: widget.deviceType,
                    stackedSwitchPart: _stackedSwitchSelectedPart,
                    onStackedPartChanged: _handleStackedPartChanged,
                  ),
                  // Layer 2: Explore connections
                  ConnectionsLayer(connections: _exploreConnections),
                  // Layer 3: Explore floating devices
                  DevLayer(
                    devices: _exploreDevices,
                    onExternalDeviceSelected: widget.onDeviceSelected,
                  ),
                  // Layer 4: Baseline connections
                  ConnectionsLayer(connections: _baseConnections),
                  // Layer 5: Baseline floating devices
                  DevLayer(
                    devices: _baseDevices,
                    selectedDeviceId: _selectedDeviceId,
                    onDeviceSelected: _handleDeviceSelected,
                    onClearPortHighlight: _handleClearPortHighlight,
                    onExternalDeviceSelected: widget.onDeviceSelected,
                  ),
                  // Layer 6: Ports
                  PortLayer(
                    ports: _ports,
                    onPortHover: widget.deviceType == DeviceType.switch_
                        ? _handlePortHover
                        : null,
                    onPortHoverExit: widget.deviceType == DeviceType.switch_
                        ? _handlePortHoverExit
                        : null,
                    onPortTap: widget.deviceType == DeviceType.switch_
                        ? _handlePortTap
                        : null,
                    isConfig: widget.isConfig,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
