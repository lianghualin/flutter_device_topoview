import 'dart:math';

import 'package:flutter/material.dart';
import '../models/port_device.dart';
import '../models/device_format.dart';
import '../models/port_status.dart';
import '../models/port.dart';
import '../models/connection_line.dart';
import '../widgets/center_device_widget.dart';
import '../widgets/floating_devices/dev_float.dart';
import 'device_layout_strategy.dart';
import 'slot_based_layout_strategy.dart';

/// Layout strategy for DPU topology views.
///
/// Ports are arranged in two horizontal rows (slotA / slotB) below the
/// center device. Floating switch devices (max 2) are positioned by slot
/// group -- slotA on the left, slotB on the right.
class DpuLayoutStrategy extends SlotBasedLayoutStrategy {
  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, DeviceFormat format) {
    final double width = viewportSize.width;
    final double height = viewportSize.height;

    // Center size: 40% of min dimension, clamped [150, 350]
    final double minDimension = min(width, height);
    double centerSize = minDimension * 0.4;
    centerSize = centerSize.clamp(150.0, 350.0);

    // Horizontal center, slightly above vertical center
    final double centerX = width / 2;
    final double centerY = (height / 2) - (centerSize * 0.4);

    // Top-left offset
    final double positionDx = centerX - centerSize / 2;
    final double positionDy = centerY;

    return CenterDeviceLayout(
      position: Offset(positionDx, positionDy),
      size: centerSize,
    );
  }

  // ---------------------------------------------------------------------------
  // calculatePortPositions  -- two horizontal rows (slotA / slotB)
  // ---------------------------------------------------------------------------

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    DeviceFormat format,
    Map<String, PortStatus> statusMap,
  ) {
    // Group ports by slotA / slotB prefix
    final Map<String, Map<String, PortStatus>> slotGroups = {
      'slotA': {},
      'slotB': {},
    };

    for (final entry in statusMap.entries) {
      if (entry.key.startsWith('slotA')) {
        slotGroups['slotA']![entry.key] = entry.value;
      } else if (entry.key.startsWith('slotB')) {
        slotGroups['slotB']![entry.key] = entry.value;
      }
    }

    final List<Port> ports = [];

    // Scale port size based on center size
    final double portScale = center.size / 250.0;
    double portWidth = 13.0 * portScale;
    double portHeight = 13.0 * portScale;
    portWidth = portWidth.clamp(10.0, 20.0);
    portHeight = portHeight.clamp(10.0, 20.0);

    // Vertical positions relative to center
    final double position1Y = center.position.dy + center.size * 0.82;
    final double position2Y = center.position.dy + center.size * 0.92;

    // ---- slotA row ----
    if (slotGroups['slotA']!.isNotEmpty) {
      final entries = slotGroups['slotA']!.entries.toList();
      final int groupSize = entries.length;
      final double totalWidth = center.size * 1.2;
      final double startX =
          center.position.dx + (center.size / 2) - (totalWidth / 2);
      final double spacing =
          groupSize > 1 ? totalWidth / (groupSize - 1) : 0;

      for (int i = 0; i < groupSize; i++) {
        final entry = entries[i];
        final double x = groupSize > 1
            ? startX + (spacing * i)
            : center.position.dx + (center.size / 2);

        ports.add(Port(
          position:
              Offset(x - portWidth * 1.3, position1Y - portHeight / 2),
          isUp: _portStatusToBool(entry.value),
          width: portWidth,
          height: portHeight,
          label: entry.key,
          rotation: -pi / 2,
          showLabel: false,
        ));
      }
    }

    // ---- slotB row ----
    if (slotGroups['slotB']!.isNotEmpty) {
      final entries = slotGroups['slotB']!.entries.toList();
      final int groupSize = entries.length;
      final double totalWidth = center.size * 1.0;
      final double startX =
          center.position.dx + (center.size / 2) - (totalWidth / 2);
      final double spacing =
          groupSize > 1 ? totalWidth / (groupSize - 1) : 0;

      for (int i = 0; i < groupSize; i++) {
        final entry = entries[i];
        final double x = groupSize > 1
            ? startX + (spacing * i)
            : center.position.dx + (center.size / 2);

        ports.add(Port(
          position:
              Offset(x - portWidth * 1.3, position2Y - portHeight / 2),
          isUp: _portStatusToBool(entry.value),
          width: portWidth,
          height: portHeight,
          label: entry.key,
          rotation: -pi / 2,
          showLabel: false,
        ));
      }
    }

    return ports;
  }

  // ---------------------------------------------------------------------------
  // calculateDevicePositions  -- slot-based left/right positioning
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
    final double centerX = contentWidth / 2;
    final double minDimension = min(contentWidth, contentHeight);

    // Device size: 15% of min dimension, clamped [60, 120]
    double deviceSize = minDimension * 0.15;
    deviceSize = deviceSize.clamp(60.0, 120.0);

    // Horizontal spacing
    final double horizontalSpacing = contentWidth * 0.25;

    // ---- Baseline devices ----
    final List<PortDevice> validDevices = devices
        .where((d) =>
            d.deviceName.isNotEmpty ||
            (d.deviceIp != null && d.deviceIp!.isNotEmpty))
        .toList();

    final double baselineY = contentHeight * 0.2;
    final List<PositionedDevice> baselinePositioned =
        _positionBySlot(validDevices, centerX, horizontalSpacing,
            baselineY, deviceSize, false);

    // ---- Explore devices ----
    final List<PortDevice> exploreDevices = devices
        .where((d) =>
            ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
                (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
            !(d.deviceName == d.exploreDevName &&
                d.deviceIp == d.exploreDevIp))
        .toList();

    final double exploreY = contentHeight * 0.1;
    final List<PositionedDevice> explorePositioned =
        _positionBySlot(exploreDevices, centerX, horizontalSpacing,
            exploreY, deviceSize, true);

    return DevicePositions(
      baselineDevices: baselinePositioned,
      exploreDevices: explorePositioned,
    );
  }

  // ---------------------------------------------------------------------------
  // generateConnections  -- DPU slot-based matching
  // ---------------------------------------------------------------------------
  //
  // DPU has a different connection model from host:
  //   - Host: 1 device per port, portId directly matches port label
  //   - DPU:  1 device per slot, multiple ports per slot
  //           device portId is 'slotA'/'slotB', port labels are 'slotA_port1', etc.
  //
  // We group ports by slot prefix and connect each device to the center
  // of its slot's port group.

  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    // Group ports by slot prefix
    final Map<String, List<Port>> slotPorts = {};
    for (final port in ports) {
      final label = port.label ?? '';
      if (label.startsWith('slotA')) {
        slotPorts.putIfAbsent('slotA', () => []).add(port);
      } else if (label.startsWith('slotB')) {
        slotPorts.putIfAbsent('slotB', () => []).add(port);
      }
    }

    // Map devices by portId and label
    final Map<String, DevFloat> deviceMap = {};
    for (final device in devices) {
      if (device.portId.isNotEmpty) {
        deviceMap[device.portId] = device;
      }
      deviceMap[device.label] = device;
    }

    final List<ConnectionLine> connections = [];

    for (final relationship in portDevices) {
      if (relationship.deviceName.isEmpty &&
          (relationship.deviceIp == null || relationship.deviceIp!.isEmpty)) {
        continue;
      }

      // Find the port group for this device's slot
      final List<Port>? portGroup = slotPorts[relationship.portId];
      if (portGroup == null || portGroup.isEmpty) continue;

      // Use the center of the port group as the source point
      double avgX = 0, avgY = 0;
      for (final port in portGroup) {
        avgX += port.position.dx + port.width / 2;
        avgY += port.position.dy + port.height / 2;
      }
      avgX /= portGroup.length;
      avgY /= portGroup.length;
      final Offset sourceOffset = Offset(avgX, avgY);

      // Find the device
      final String deviceLabel = relationship.deviceName.isNotEmpty
          ? relationship.deviceName
          : (relationship.deviceIp ?? '');
      final DevFloat? device =
          deviceMap[relationship.portId] ?? deviceMap[deviceLabel];

      if (device != null) {
        final Offset targetOffset = Offset(
          device.position.dx,
          device.position.dy,
        );

        // Determine connection status
        final bool hasExplore = (relationship.exploreDevName != null &&
                relationship.exploreDevName!.isNotEmpty) ||
            (relationship.exploreDevIp != null &&
                relationship.exploreDevIp!.isNotEmpty);

        final bool isSame =
            relationship.deviceName == relationship.exploreDevName &&
                relationship.deviceIp == relationship.exploreDevIp;

        int status;
        if (!hasExplore) {
          status = 0; // baseline only -> dashed
        } else if (isSame) {
          status = 1; // matched -> green solid
        } else {
          status = 0; // differ -> dashed
        }

        connections.add(ConnectionLine(
          sourceOffset: sourceOffset,
          targetOffset: targetOffset,
          status: status,
          slotId: relationship.portId,
        ));
      }
    }

    return connections;
  }

  // ---------------------------------------------------------------------------
  // generateExploreConnections  -- DPU slot-based matching
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    // Group ports by slot prefix
    final Map<String, List<Port>> slotPorts = {};
    for (final port in ports) {
      final label = port.label ?? '';
      if (label.startsWith('slotA')) {
        slotPorts.putIfAbsent('slotA', () => []).add(port);
      } else if (label.startsWith('slotB')) {
        slotPorts.putIfAbsent('slotB', () => []).add(port);
      }
    }

    // Map explore devices by portId and label
    final Map<String, DevFloat> deviceMap = {};
    for (final device in devices) {
      if (device.portId.isNotEmpty) {
        deviceMap[device.portId] = device;
      }
      deviceMap[device.label] = device;
    }

    final List<ConnectionLine> connections = [];

    for (final relationship in portDevices) {
      // Only process relationships with explore data
      if ((relationship.exploreDevName == null ||
              relationship.exploreDevName!.isEmpty) &&
          (relationship.exploreDevIp == null ||
              relationship.exploreDevIp!.isEmpty)) {
        continue;
      }

      // Skip if baseline == explore
      if (relationship.deviceName == relationship.exploreDevName &&
          relationship.deviceIp == relationship.exploreDevIp) {
        continue;
      }

      // Find the port group for this device's slot
      final List<Port>? portGroup = slotPorts[relationship.portId];
      if (portGroup == null || portGroup.isEmpty) continue;

      // Use the center of the port group as the source point
      double avgX = 0, avgY = 0;
      for (final port in portGroup) {
        avgX += port.position.dx + port.width / 2;
        avgY += port.position.dy + port.height / 2;
      }
      avgX /= portGroup.length;
      avgY /= portGroup.length;
      final Offset sourceOffset = Offset(avgX, avgY);

      // Find the device
      final String deviceLabel = (relationship.exploreDevName != null &&
              relationship.exploreDevName!.isNotEmpty)
          ? relationship.exploreDevName!
          : (relationship.exploreDevIp ?? '');
      final DevFloat? device =
          deviceMap[relationship.portId] ?? deviceMap[deviceLabel];

      if (device != null) {
        final Offset targetOffset = Offset(
          device.position.dx,
          device.position.dy,
        );

        connections.add(ConnectionLine(
          sourceOffset: sourceOffset,
          targetOffset: targetOffset,
          status: -1, // explore connections are always red
          slotId: relationship.portId,
        ));
      }
    }

    return connections;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Position devices by slot group (slotA -> left, slotB -> right).
  List<PositionedDevice> _positionBySlot(
    List<PortDevice> devices,
    double centerX,
    double horizontalSpacing,
    double yPosition,
    double deviceSize,
    bool isExplore,
  ) {
    final List<PositionedDevice> result = [];

    // Group by slot
    final Map<String, List<PortDevice>> slotDevices = {
      'slotA': [],
      'slotB': [],
    };
    for (final device in devices) {
      if (device.portId.contains('slotA')) {
        slotDevices['slotA']!.add(device);
      } else if (device.portId.contains('slotB')) {
        slotDevices['slotB']!.add(device);
      }
    }

    // slotA -> left side
    if (slotDevices['slotA']!.isNotEmpty) {
      final slotADevices = slotDevices['slotA']!;
      if (slotADevices.length == 1) {
        final double xPos = centerX - horizontalSpacing;
        result.add(PositionedDevice(
          position: Offset(xPos, yPosition),
          size: deviceSize,
          device: slotADevices[0],
        ));
      } else {
        final double startX = centerX - horizontalSpacing * 1.5;
        final double endX = centerX - horizontalSpacing * 0.5;
        final double step = slotADevices.length > 1
            ? (endX - startX) / (slotADevices.length - 1)
            : 0;

        for (int i = 0; i < slotADevices.length; i++) {
          final double xPos = startX + i * step;
          result.add(PositionedDevice(
            position: Offset(xPos, yPosition),
            size: deviceSize,
            device: slotADevices[i],
          ));
        }
      }
    }

    // slotB -> right side
    if (slotDevices['slotB']!.isNotEmpty) {
      final slotBDevices = slotDevices['slotB']!;
      if (slotBDevices.length == 1) {
        final double xPos = centerX + horizontalSpacing;
        result.add(PositionedDevice(
          position: Offset(xPos, yPosition),
          size: deviceSize,
          device: slotBDevices[0],
        ));
      } else {
        final double startX = centerX + horizontalSpacing * 0.5;
        final double endX = centerX + horizontalSpacing * 1.5;
        final double step = slotBDevices.length > 1
            ? (endX - startX) / (slotBDevices.length - 1)
            : 0;

        for (int i = 0; i < slotBDevices.length; i++) {
          final double xPos = startX + i * step;
          result.add(PositionedDevice(
            position: Offset(xPos, yPosition),
            size: deviceSize,
            device: slotBDevices[i],
          ));
        }
      }
    }

    return result;
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
