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
    throw UnimplementedError('Task 5: calculateDevicePositions');
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
}
