import 'dart:math';

import 'package:flutter/material.dart';
import '../models/port_device.dart';
import '../models/device_format.dart';
import '../models/port_status.dart';
import '../models/port.dart';
import '../widgets/center_device_widget.dart';
import 'device_layout_strategy.dart';
import 'slot_based_layout_strategy.dart';

/// Layout strategy for host topology views.
///
/// Ports are arranged in a semi-ellipse above the center device.
/// Floating switch devices are positioned radially outward from their
/// connected port, so each connection line fans out without crossing.
/// Explore devices use the same radial direction but at greater distance
/// with smaller size and reduced visual weight.
class HostLayoutStrategy extends SlotBasedLayoutStrategy {
  final int deviceCount;

  HostLayoutStrategy({this.deviceCount = 1});

  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, DeviceFormat format) {
    final double width = viewportSize.width;
    final double height = viewportSize.height;

    // Center size based on viewport dimensions
    final double minDimension = min(width, height);
    final double centerSize = minDimension * 0.3;

    // Dynamic vertical position: fewer devices → higher, more → lower
    // 1-2 devices: 55%, 3-4: 63%, 5-6: 72%
    final double centerYFactor = deviceCount <= 2
        ? 0.55
        : deviceCount <= 4
            ? 0.63
            : 0.72;

    final double centerX = width / 2;
    final double centerY = height * centerYFactor;

    // Top-left offset to center the widget
    final double positionDx = centerX - centerSize / 2;
    final double positionDy = centerY - centerSize / 2;

    return CenterDeviceLayout(
      position: Offset(positionDx, positionDy),
      size: centerSize,
    );
  }

  // ---------------------------------------------------------------------------
  // calculatePortPositions  -- semi-elliptical positioning above center
  // ---------------------------------------------------------------------------

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    DeviceFormat format,
    Map<String, PortStatus> statusMap,
  ) {
    // Calculate the center point of the center widget
    final double hostCenterX = center.position.dx + center.size / 2;
    final double hostCenterY = center.position.dy + center.size / 2;
    final Offset centerPoint = Offset(hostCenterX, hostCenterY);

    final int numPorts = statusMap.length;
    final List<Offset> portPositions = _calculatePortPositions(
      centerPoint,
      center.size,
      numPorts,
      radiusFactor: 1.2,
      isUpward: true,
    );

    final List<Port> ports = [];
    const double portWidth = 30.0;
    const double portHeight = 30.0;

    // Iterate in reverse to match original host_topoview ordering
    int i = 0;
    for (final entry in statusMap.entries.toList().reversed) {
      final Offset adjustedPosition = Offset(
        portPositions[i].dx - portWidth / 2,
        portPositions[i].dy - portHeight / 2,
      );

      // Convert PortStatus to bool? for isUp
      final bool? isUp = _portStatusToBool(entry.value);

      ports.add(Port(
        position: adjustedPosition,
        isUp: isUp,
        width: portWidth,
        height: portHeight,
        label: entry.key,
        showLabel: true,
        rotation: 0,
      ));
      i++;
    }
    return ports;
  }

  // ---------------------------------------------------------------------------
  // calculateDevicePositions  -- radial fan positioning
  // ---------------------------------------------------------------------------

  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports,
  ) {
    final double minDimension = min(viewportSize.width, viewportSize.height);

    // Auto-fit: scale device size based on device count
    // Fewer devices → larger, more devices → smaller
    final double deviceSizeFactor = deviceCount <= 1
        ? 0.12
        : deviceCount <= 2
            ? 0.10
            : deviceCount <= 4
                ? 0.08
                : 0.065;
    final double deviceSize = minDimension * deviceSizeFactor;

    // Host center point
    final double hostCenterX = center.position.dx + center.size / 2;
    final double hostCenterY = center.position.dy + center.size / 2;
    final Offset hostCenter = Offset(hostCenterX, hostCenterY);

    // Build port lookup: portId -> Port
    final Map<String, Port> portMap = {};
    for (final port in ports) {
      if (port.label != null) {
        portMap[port.label!] = port;
      }
    }

    // Auto-fit radial distance: fewer devices → longer reach
    final double baseDistFactor = deviceCount <= 2 ? 0.30 : 0.24;
    final double baselineDistance = minDimension * baseDistFactor;

    // Margin to keep devices within viewport bounds
    final double visualPadding = (deviceSize + 30) / 2 + 10;

    // ---- Baseline devices ----
    final List<PortDevice> validDevices = devices
        .where((d) =>
            d.deviceName.isNotEmpty ||
            (d.deviceIp != null && d.deviceIp!.isNotEmpty))
        .toList();

    final List<PositionedDevice> baselinePositioned = [];
    for (final device in validDevices) {
      final Port? port = portMap[device.portId];
      if (port == null) continue;

      Offset devicePosition = _radialPosition(
        hostCenter, port, baselineDistance,
      );
      devicePosition = _clampToViewport(
        devicePosition, viewportSize, visualPadding,
      );

      baselinePositioned.add(PositionedDevice(
        position: devicePosition,
        size: deviceSize,
        device: device,
      ));
    }

    // ---- Explore devices (satellite positioning) ----
    final List<PortDevice> exploreDevices = devices
        .where((d) =>
            ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
                (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
            !(d.deviceName == d.exploreDevName &&
                d.deviceIp == d.exploreDevIp))
        .toList();

    final double exploreDeviceSize = deviceSize * 0.7;
    final double exploreVisualPadding = (exploreDeviceSize + 30) / 2 + 10;
    final List<PositionedDevice> explorePositioned = [];

    for (final device in exploreDevices) {
      // Find matching baseline device
      PositionedDevice? matchingBaseline;
      for (final b in baselinePositioned) {
        if (b.device.portId == device.portId) {
          matchingBaseline = b;
          break;
        }
      }

      if (matchingBaseline == null) {
        // No baseline match — position radially from port
        final Port? port = portMap[device.portId];
        if (port == null) continue;
        Offset pos = _radialPosition(hostCenter, port, baselineDistance * 1.4);
        pos = _clampToViewport(pos, viewportSize, exploreVisualPadding);
        explorePositioned.add(PositionedDevice(
          position: pos, size: exploreDeviceSize, device: device,
        ));
        continue;
      }

      // Satellite offset: place on the outer side of baseline, away from center
      final double separation =
          (deviceSize + 30) / 2 + (exploreDeviceSize + 30) / 2 + 8;
      final double dx = matchingBaseline.position.dx - hostCenter.dx;
      final double dy = matchingBaseline.position.dy - hostCenter.dy;

      // Offset along the dominant axis to guarantee no rectangular overlap
      Offset satellitePos;
      if (dx.abs() > dy.abs()) {
        // Mostly horizontal: push satellite further along X (same side)
        satellitePos = Offset(
          matchingBaseline.position.dx + (dx >= 0 ? separation : -separation),
          matchingBaseline.position.dy - separation * 0.25,
        );
      } else {
        // Mostly vertical (top): push satellite sideways
        // Left of center → go left, right of center → go right,
        // at center → go right
        final double sideX = dx >= 0 ? separation : -separation;
        satellitePos = Offset(
          matchingBaseline.position.dx + sideX,
          matchingBaseline.position.dy - separation * 0.15,
        );
      }

      satellitePos = _clampToViewport(
          satellitePos, viewportSize, exploreVisualPadding);

      explorePositioned.add(PositionedDevice(
        position: satellitePos,
        size: exploreDeviceSize,
        device: device,
      ));
    }

    return DevicePositions(
      baselineDevices: baselinePositioned,
      exploreDevices: explorePositioned,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Calculate port positions in a semi-ellipse.
  List<Offset> _calculatePortPositions(
    Offset center,
    double centerSize,
    int numPorts, {
    double? radiusFactor,
    bool isUpward = true,
    double ellipseRatio = 1.2,
  }) {
    final List<Offset> positions = [];
    if (numPorts <= 0) return positions;

    final double horizontalRadius = (radiusFactor ?? 0.6) * centerSize;
    final double verticalRadius = horizontalRadius / ellipseRatio;

    // Special case: single port directly above/below center
    if (numPorts == 1) {
      final double angle = isUpward ? -pi / 2 : pi / 2;
      final double x = center.dx + horizontalRadius * cos(angle);
      final double y = center.dy + verticalRadius * sin(angle);
      positions.add(Offset(x, y));
      return positions;
    }

    // Multiple ports distributed along an arc.
    // Inset the angles so ports always have an upward component
    // (avoids pure horizontal placement with 2 ports).
    const double anglePadding = pi / 6;
    final double startAngle = isUpward ? anglePadding : pi + anglePadding;
    final double endAngle = isUpward ? pi - anglePadding : 2 * pi - anglePadding;
    final double totalAngle = endAngle - startAngle;
    final double angleStep =
        numPorts > 1 ? totalAngle / (numPorts - 1) : 0;

    for (int i = 0; i < numPorts; i++) {
      final double currentAngle = startAngle + (angleStep * i);
      final double x = center.dx + horizontalRadius * cos(currentAngle);
      final double y = isUpward
          ? center.dy - verticalRadius * sin(currentAngle)
          : center.dy + verticalRadius * sin(currentAngle);
      positions.add(Offset(x, y));
    }
    return positions;
  }

  /// Clamp a position to stay within the viewport with a margin.
  Offset _clampToViewport(Offset position, Size viewport, double margin) {
    return Offset(
      position.dx.clamp(margin, viewport.width - margin),
      position.dy.clamp(margin, viewport.height - margin),
    );
  }

  /// Position a device radially outward from the host center, along the
  /// same direction as its connected [port].
  Offset _radialPosition(Offset hostCenter, Port port, double distance) {
    final Offset portCenter = Offset(
      port.position.dx + port.width / 2,
      port.position.dy + port.height / 2,
    );

    final Offset direction = portCenter - hostCenter;
    final double dist = direction.distance;

    if (dist > 0) {
      final Offset normalizedDir = direction / dist;
      return portCenter + normalizedDir * distance;
    }
    // Fallback: place directly above if port is at center
    return Offset(portCenter.dx, portCenter.dy - distance);
  }

  /// Convert PortStatus enum to bool? for Port.isUp.
  bool? _portStatusToBool(PortStatus status) {
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
