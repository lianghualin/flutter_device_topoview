import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_host_device/flutter_host_device.dart' hide PortStatus;
import '../models/port_device.dart';
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
  final double labelBottomPadding;

  HostLayoutStrategy({this.deviceCount = 1, this.labelBottomPadding = 40.0});

  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, Object format) {
    final double width = viewportSize.width;
    final double height = viewportSize.height;

    // Cache viewport size for use by calculatePortPositions
    _cachedViewportSize = viewportSize;

    // Center size based on viewport dimensions
    final double minDimension = min(width, height);
    final double centerSize = minDimension * 0.3;

    // Dynamic vertical position: push host down to leave room above for port arc + devices
    // 1-2 devices: 68%, 3-4: 72%, 5+: 78%
    final double centerYFactor = deviceCount <= 2
        ? 0.68
        : deviceCount <= 4
            ? 0.72
            : 0.78;

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
  // calculatePortPositions  -- delegates to HostDeviceView.getPortPositions()
  // ---------------------------------------------------------------------------

  /// Cached viewport size from [calculateCenterLayout], used by
  /// [calculatePortPositions] to call the package's layout engine.
  Size _cachedViewportSize = Size.zero;

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    Object format,
    Map<String, PortStatus> statusMap,
  ) {
    final int numPorts = statusMap.length;
    if (numPorts <= 0) return [];

    // Compute centerYFactor consistently with calculateCenterLayout
    final double centerYFactor = deviceCount <= 2
        ? 0.68
        : deviceCount <= 4
            ? 0.72
            : 0.78;

    // Use the package's layout engine for port center positions.
    // Returns positions in viewport coordinates (NOT relative to center).
    final Map<int, Offset> portCenters = HostDeviceView.getPortPositions(
      numPorts,
      _cachedViewportSize,
      centerYFactor: centerYFactor,
    );

    const double portWidth = 30.0;
    const double portHeight = 30.0;

    final List<Port> ports = [];

    // The statusMap entries are keyed by portId strings.
    // The current code iterates statusMap.entries.reversed, so:
    //   port 1 = last entry, port 2 = second-to-last, etc.
    final reversedEntries = statusMap.entries.toList().reversed.toList();

    for (int i = 0; i < reversedEntries.length; i++) {
      final entry = reversedEntries[i];
      final int portNumber = i + 1; // 1-based
      final Offset? portCenter = portCenters[portNumber];
      if (portCenter == null) continue;

      final Offset adjustedPosition = Offset(
        portCenter.dx - portWidth / 2,
        portCenter.dy - portHeight / 2,
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
    List<Port> ports, {
    Size? actualViewport,
  }) {
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
    // Use visual radius so the full ring stays inside the viewport
    final double visualPadding = (deviceSize + 30) / 2;

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

  /// Clamp a position to stay within the viewport with a margin.
  Offset _clampToViewport(Offset position, Size viewport, double margin) {
    return Offset(
      position.dx.clamp(margin, viewport.width - margin),
      position.dy.clamp(margin, viewport.height - margin - labelBottomPadding),
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
