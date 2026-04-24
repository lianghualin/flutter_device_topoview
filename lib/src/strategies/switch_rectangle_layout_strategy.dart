import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart' hide PortStatus;

import '../models/connection_line.dart';
import '../models/port.dart';
import '../models/port_device.dart';
import '../models/port_status.dart';
import '../widgets/center_device_widget.dart';
import '../widgets/floating_devices/dev_float.dart';
import 'device_layout_strategy.dart';

/// Layout strategy for switch topology views in rectangle mode.
///
/// Places floating devices in column sections above and below the chassis
/// instead of in two concentric rings. The chassis itself is rendered
/// vertically centered in the viewport. See the design spec at
/// `docs/superpowers/specs/2026-04-24-rectangle-switch-layout-design.md`.
class SwitchRectangleLayoutStrategy extends DeviceLayoutStrategy {
  final bool isConfig;
  final int stackedSwitchSelectedPart;
  final double labelBottomPadding;

  static const double _minWidth = 1500.0;
  static const double _minHeight = 800.0;

  SwitchRectangleLayoutStrategy({
    this.isConfig = false,
    this.stackedSwitchSelectedPart = 0,
    this.labelBottomPadding = 40.0,
  });

  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, Object format) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // Cache viewport size for use by calculatePortPositions.
    _cachedViewportSize = Size(contentWidth, contentHeight);

    // Same scaleFactor / centerSize derivation as the circle strategy.
    double scaleFactor = contentWidth / contentHeight;
    scaleFactor = scaleFactor.clamp(0.5, 1.0);
    final double centerSize = 500.0 * scaleFactor;

    // Centered vertically (rectangle-specific override). Horizontal
    // centering matches the circle strategy.
    final double posX = (contentWidth - centerSize) / 2;
    final double posY = (contentHeight - centerSize) / 2;

    return CenterDeviceLayout(
      position: Offset(posX, posY),
      size: centerSize,
    );
  }

  // Cached in calculateCenterLayout; read in calculatePortPositions.
  Size _cachedViewportSize = Size.zero;

  // ---------------------------------------------------------------------------
  // Placeholders — to be implemented in later tasks.
  // ---------------------------------------------------------------------------

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    Object format,
    Map<String, PortStatus> statusMap,
  ) {
    if (format is! SwitchFormat) {
      return [];
    }

    final SwitchFormat switchFormat = format;
    final int? validPortsNum = switchFormat.validPortsNum;

    final Map<int, Offset> portCenters = SwitchDeviceView.getPortPositions(
      switchFormat,
      _cachedViewportSize,
    );

    final double cs = _packageCenterSize(switchFormat, _cachedViewportSize);
    final double portWidth = _packagePortWidth(switchFormat, cs);
    final double portHeight = portWidth * 0.75;

    final List<Port> ports = [];

    for (final entry in portCenters.entries) {
      final int i = entry.key;
      final Offset portCenter = entry.value;
      final bool isInvalid = validPortsNum != null && i > validPortsNum;

      final PortStatus? portStatus = statusMap[i.toString()];
      final bool? isUp =
          portStatus != null ? _portStatusToBool(portStatus) : null;

      double opacity = 1.0;
      if (switchFormat.isStacked) {
        if (stackedSwitchSelectedPart == 1) {
          opacity = (i >= 1 && i <= 24) ? 1.0 : 0.3;
        } else if (stackedSwitchSelectedPart == 2) {
          opacity = (i >= 25 && i <= 48) ? 1.0 : 0.3;
        } else {
          opacity = 0.3;
        }
      }

      ports.add(Port(
        position: Offset(
          portCenter.dx - portWidth / 2,
          portCenter.dy - portHeight / 2,
        ),
        portNumber: i,
        width: portWidth,
        height: portHeight,
        isUp: isUp,
        isInvalid: isInvalid,
        opacity: opacity,
      ));
    }

    ports.sort((a, b) => (a.portNumber ?? 0).compareTo(b.portNumber ?? 0));
    return ports;
  }

  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports, {
    Size? actualViewport,
  }) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // --- Filter devices (config + stacked) -----------------------------
    List<PortDevice> filtered = List.of(devices);
    if (isConfig) {
      filtered = filtered.where((d) => d.connectionStatus >= 0).toList();
    }
    // Detect stacked on the ORIGINAL list — filtering first would hide the
    // >28 signal when isConfig drops probed devices.
    if (_isStacked(devices)) {
      if (stackedSwitchSelectedPart == 1) {
        filtered = filtered
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 1 &&
                d.portNumber! <= 24)
            .toList();
      } else if (stackedSwitchSelectedPart == 2) {
        filtered = filtered
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 25 &&
                d.portNumber! <= 48)
            .toList();
      } else {
        filtered = [];
      }
    }
    if (filtered.isEmpty) {
      return const DevicePositions(
        baselineDevices: [],
        exploreDevices: [],
      );
    }

    // --- Precompute column X lookups per row ---------------------------
    final topRow = _topRowPorts(ports);
    final bottomRow = _bottomRowPorts(ports);
    final topColumnXs = _columnXs(topRow);
    final bottomColumnXs = _columnXs(bottomRow);
    final Map<int, double> columnXByPort = {};
    for (int i = 0; i < topRow.length; i++) {
      final portNum = topRow[i].portNumber;
      if (portNum != null) columnXByPort[portNum] = topColumnXs[i];
    }
    for (int i = 0; i < bottomRow.length; i++) {
      final portNum = bottomRow[i].portNumber;
      if (portNum != null) columnXByPort[portNum] = bottomColumnXs[i];
    }

    // --- Section vertical extents --------------------------------------
    final double topSectionTop = 0.0;
    final double topSectionBottom = center.position.dy;
    final double bottomSectionTop = center.position.dy + center.size;
    final double bottomSectionBottom = contentHeight;

    // --- Device size tiers ---------------------------------------------
    final double visibleWidth = actualViewport?.width ?? contentWidth;
    final double visibleHeight = actualViewport?.height ?? contentHeight;
    final int deviceCount = filtered.length;
    final double canvasMinDim = math.min(contentWidth, contentHeight);

    double sizeFactor;
    double minSize;
    double maxSize;
    if (deviceCount <= 3) {
      sizeFactor = 0.10;
      minSize = 55;
      maxSize = 100;
    } else if (deviceCount <= 6) {
      sizeFactor = 0.08;
      minSize = 45;
      maxSize = 85;
    } else {
      sizeFactor = 0.065;
      minSize = 40;
      maxSize = 75;
    }
    double baseDeviceSize =
        (canvasMinDim * sizeFactor).clamp(minSize, maxSize);
    final double viewportMinDim = math.min(visibleWidth, visibleHeight);
    if (viewportMinDim < canvasMinDim) {
      final double boost =
          math.sqrt(canvasMinDim / viewportMinDim).clamp(1.0, 1.4);
      baseDeviceSize = (baseDeviceSize * boost).clamp(minSize, maxSize * 1.3);
    }
    final double baselineDeviceSize = baseDeviceSize * 0.7;

    // --- Per-device placement ------------------------------------------
    final List<PositionedDevice> baselineOut = [];
    final List<PositionedDevice> exploreOut = [];

    for (final dev in filtered) {
      final int portNum = dev.portNumber ?? 0;
      final bool isTop = portNum.isOdd;
      final double columnX = columnXByPort[portNum] ?? center.position.dx;

      final bool hasExplore =
          ((dev.exploreDevName != null && dev.exploreDevName!.isNotEmpty) ||
                  (dev.exploreDevIp != null && dev.exploreDevIp!.isNotEmpty)) &&
              !(dev.deviceName == dev.exploreDevName &&
                  dev.deviceIp == dev.exploreDevIp);
      final bool baselineIsReal =
          dev.connectionStatus == 1 || dev.connectionStatus == -1;

      double actualDeviceSize = baseDeviceSize;
      if (dev.deviceType != 'Switch') actualDeviceSize *= 0.8;
      double baselineIconSize = baselineDeviceSize;
      if (dev.deviceType != 'Switch') baselineIconSize *= 0.8;

      // Slot Y positions — outer slot sits nearer the screen edge; actual
      // slot sits nearer the chassis. 25/75 vertical split keeps a safe gap
      // between the two slots even at the minimum viewport height.
      double outerY;
      double actualY;
      if (isTop) {
        final double sectionH = topSectionBottom - topSectionTop;
        outerY = topSectionTop + sectionH * 0.25;
        actualY = topSectionTop + sectionH * 0.75;
      } else {
        final double sectionH = bottomSectionBottom - bottomSectionTop;
        outerY = bottomSectionTop + sectionH * 0.75;
        actualY = bottomSectionTop + sectionH * 0.25;
      }
      outerY = outerY.clamp(
        baselineIconSize / 2 + 10,
        contentHeight - baselineIconSize / 2 - 10 - labelBottomPadding,
      );
      actualY = actualY.clamp(
        actualDeviceSize / 2 + 10,
        contentHeight - actualDeviceSize / 2 - 10 - labelBottomPadding,
      );

      if (!isConfig && hasExplore) {
        // mismatch: baseline on outer, explore on actual (same columnX)
        baselineOut.add(PositionedDevice(
          position: Offset(columnX, outerY),
          size: baselineIconSize,
          device: dev,
        ));
        exploreOut.add(PositionedDevice(
          position: Offset(columnX, actualY),
          size: actualDeviceSize,
          device: dev,
        ));
      } else if (!isConfig && baselineIsReal) {
        // green (status 1) / red (status -1): single device on actual slot
        exploreOut.add(PositionedDevice(
          position: Offset(columnX, actualY),
          size: actualDeviceSize,
          device: dev,
        ));
      } else {
        // black-only OR any device in config mode → outer slot
        baselineOut.add(PositionedDevice(
          position: Offset(columnX, outerY),
          size: baselineIconSize,
          device: dev,
        ));
      }
    }

    return DevicePositions(
      baselineDevices: baselineOut,
      exploreDevices: exploreOut,
    );
  }

  /// Stacked if any device port number exceeds 28. Matches the heuristic
  /// used by the circle strategy.
  bool _isStacked(List<PortDevice> devices) {
    return devices.any(
        (d) => d.portNumber != null && d.portNumber! > 28);
  }

  @override
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  ) {
    throw UnimplementedError('Task 6: buildFloatingDevices');
  }

  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    throw UnimplementedError('Task 7: generateConnections');
  }

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    throw UnimplementedError('Task 7: generateExploreConnections');
  }

  static double _packageCenterSize(SwitchFormat format, Size viewportSize) {
    final scaleX = viewportSize.width / format.minWidth;
    final scaleY = viewportSize.height / format.minHeight;
    return 500.0 * math.min(scaleX, scaleY);
  }

  static double _packagePortWidth(SwitchFormat format, double cs) {
    final allX = <double>[
      for (final o in format.oddPortOffsetR) o.dx,
      for (final o in format.evenPortOffsetR) o.dx,
    ]..sort();
    if (allX.length < 2) return cs * 0.04;
    double minSpacing = double.infinity;
    for (int i = 1; i < allX.length; i++) {
      final spacing = allX[i] - allX[i - 1];
      if (spacing > 0 && spacing < minSpacing) {
        minSpacing = spacing;
      }
    }
    final rawWidth = cs * minSpacing * 0.8;
    return rawWidth.clamp(10.0, 25.0);
  }

  static bool? _portStatusToBool(PortStatus status) {
    switch (status) {
      case PortStatus.up:
        return true;
      case PortStatus.down:
        return false;
      case PortStatus.unknown:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Column-grid helpers (internal, exposed for testing via `debug*` shims)
  // ---------------------------------------------------------------------------

  List<Port> _topRowPorts(List<Port> ports) => ports
      .where((p) => p.portNumber != null && p.portNumber!.isOdd)
      .toList()
    ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

  List<Port> _bottomRowPorts(List<Port> ports) => ports
      .where((p) => p.portNumber != null && p.portNumber!.isEven)
      .toList()
    ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

  /// Returns column center-X positions, evenly distributed from the leftmost
  /// to the rightmost port in [rowPorts]. `rowPorts` must be sorted by X.
  List<double> _columnXs(List<Port> rowPorts) {
    if (rowPorts.isEmpty) return const [];
    if (rowPorts.length == 1) {
      return [rowPorts.first.position.dx + rowPorts.first.width / 2];
    }
    final double first = rowPorts.first.position.dx + rowPorts.first.width / 2;
    final double last = rowPorts.last.position.dx + rowPorts.last.width / 2;
    final double step = (last - first) / (rowPorts.length - 1);
    return List<double>.generate(
      rowPorts.length,
      (i) => first + step * i,
    );
  }

  // --- @visibleForTesting shims --------------------------------------------
  @visibleForTesting
  List<Port> debugTopRowPorts(List<Port> ports) => _topRowPorts(ports);

  @visibleForTesting
  List<Port> debugBottomRowPorts(List<Port> ports) => _bottomRowPorts(ports);

  @visibleForTesting
  List<double> debugColumnXs(List<Port> rowPorts) => _columnXs(rowPorts);
}
