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
/// Floating switch devices are positioned using recursive binary
/// space partitioning in two tiers (baseline at y=20%, explore at y=10%).
class HostLayoutStrategy extends SlotBasedLayoutStrategy {
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
    final double centerSize = minDimension * 0.4;

    // Position at horizontal center, 70% down
    final double centerX = width / 2;
    final double centerY = height * 0.7;

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
      radiusFactor: 0.8,
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
  // calculateDevicePositions  -- recursive binary space partitioning
  // ---------------------------------------------------------------------------

  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports,
  ) {
    final double contentWidth = viewportSize.width;
    final double contentHeight = viewportSize.height;
    final double minDimension = min(contentWidth, contentHeight);
    final double deviceSize = minDimension * 0.15;
    final double margin = contentWidth * 0.05;

    // ---- Baseline devices ----
    // Filter out devices with empty baseline info
    final List<PortDevice> validDevices = devices
        .where((d) =>
            d.deviceName.isNotEmpty ||
            (d.deviceIp != null && d.deviceIp!.isNotEmpty))
        .toList();

    final double baselineY = contentHeight * 0.2;
    final List<PositionedDevice> baselinePositioned = [];
    _positionDevicesRecursively(
      validDevices,
      margin,
      contentWidth - margin,
      baselineY,
      deviceSize,
      0, // no x offset for baseline
      baselinePositioned,
    );

    // ---- Explore devices ----
    // Only devices with explore data that differ from baseline
    final List<PortDevice> exploreDevices = devices
        .where((d) =>
            ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
                (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
            !(d.deviceName == d.exploreDevName && d.deviceIp == d.exploreDevIp))
        .toList();

    final double exploreY = contentHeight * 0.1;
    final double xOffset = deviceSize * 0.7;
    final List<PositionedDevice> explorePositioned = [];
    _positionDevicesRecursively(
      exploreDevices,
      margin,
      contentWidth - margin,
      exploreY,
      deviceSize,
      xOffset,
      explorePositioned,
    );

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
    double ellipseRatio = 1.5,
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

    // Multiple ports distributed along semi-ellipse
    final double startAngle = isUpward ? 0 : pi;
    final double endAngle = isUpward ? pi : 2 * pi;
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

  /// Recursive binary space partitioning for device positioning.
  void _positionDevicesRecursively(
    List<PortDevice> devicesToPosition,
    double startX,
    double endX,
    double yPosition,
    double deviceSize,
    double xOffset,
    List<PositionedDevice> result,
  ) {
    final int count = devicesToPosition.length;

    if (count == 0) {
      return;
    } else if (count == 1) {
      // Base case: single device at center of range
      final double centerX = (startX + endX) / 2 + xOffset;
      result.add(PositionedDevice(
        position: Offset(centerX, yPosition),
        size: deviceSize,
        device: devicesToPosition[0],
      ));
    } else if (count % 2 == 0) {
      // Even: split in half
      final int midIndex = count ~/ 2;
      final double midPoint = (startX + endX) / 2;

      _positionDevicesRecursively(
        devicesToPosition.sublist(0, midIndex),
        startX,
        midPoint,
        yPosition,
        deviceSize,
        xOffset,
        result,
      );
      _positionDevicesRecursively(
        devicesToPosition.sublist(midIndex),
        midPoint,
        endX,
        yPosition,
        deviceSize,
        xOffset,
        result,
      );
    } else {
      // Odd: center device + split remainder
      final int midIndex = count ~/ 2;
      final double midPoint = (startX + endX) / 2;

      result.add(PositionedDevice(
        position: Offset(midPoint + xOffset, yPosition),
        size: deviceSize,
        device: devicesToPosition[midIndex],
      ));

      if (midIndex > 0) {
        _positionDevicesRecursively(
          devicesToPosition.sublist(0, midIndex),
          startX,
          midPoint - deviceSize,
          yPosition,
          deviceSize,
          xOffset,
          result,
        );
      }
      if (midIndex < count - 1) {
        _positionDevicesRecursively(
          devicesToPosition.sublist(midIndex + 1),
          midPoint + deviceSize,
          endX,
          yPosition,
          deviceSize,
          xOffset,
          result,
        );
      }
    }
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
