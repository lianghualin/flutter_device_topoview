import 'package:flutter/material.dart';
import '../models/port_device.dart';
import '../models/port.dart';
import '../models/connection_line.dart';
import '../widgets/floating_devices/dev_float.dart';
import '../widgets/floating_devices/switch_dev_float.dart';
import 'device_layout_strategy.dart';

/// Shared base for Host and DPU layout strategies.
///
/// Both host and DPU topologies connect only to switch-type floating devices,
/// and share nearly identical logic for building floating widgets and
/// generating connection lines. The differences (center layout, port
/// positions, device positions) are left abstract for subclasses.
abstract class SlotBasedLayoutStrategy extends DeviceLayoutStrategy {
  // ---------------------------------------------------------------------------
  // buildFloatingDevices  -- shared between host & dpu
  // ---------------------------------------------------------------------------

  @override
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  ) {
    final List<DevFloat> result = [];

    // Baseline devices
    for (final pd in positions.baselineDevices) {
      final dev = pd.device;
      // Use deviceName / deviceIp for label (baseline)
      final String label = dev.deviceName.isNotEmpty
          ? dev.deviceName
          : (dev.deviceIp ?? '');

      result.add(SwitchDevFloat(
        position: pd.position,
        label: label,
        portstatus: dev.connectionStatus,
        size: pd.size,
        connectedPortNum: dev.portNumber ?? 0,
        deviceStatus: dev.deviceStatus,
        deviceIp: dev.deviceIp,
        portId: dev.portId,
      ));
    }

    // Explore devices
    for (final pd in positions.exploreDevices) {
      final dev = pd.device;
      // Use exploreDevName / exploreDevIp for label (explore tier)
      final String label = (dev.exploreDevName != null &&
              dev.exploreDevName!.isNotEmpty)
          ? dev.exploreDevName!
          : (dev.exploreDevIp ?? '');

      result.add(SwitchDevFloat(
        position: pd.position,
        label: label,
        portstatus: dev.connectionStatus,
        size: pd.size,
        connectedPortNum: dev.portNumber ?? 0,
        deviceStatus: dev.deviceStatus,
        deviceIp: dev.exploreDevIp,
        portId: dev.portId,
        inboundUtilization: dev.exploreInboundUtilization,
        outboundUtilization: dev.exploreOutboundUtilization,
        isRealDevice: true,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // generateConnections  -- baseline connection lines (host & dpu shared)
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    final List<ConnectionLine> connections = [];

    // Map ports by label
    final Map<String, Port> portMap = {};
    for (final port in ports) {
      portMap[port.label ?? ''] = port;
    }

    // Map baseline devices by label
    final Map<String, DevFloat> deviceMap = {};
    for (final device in devices) {
      // Only take baseline devices (not explore). In the combined list,
      // baseline devices come first and use deviceName/deviceIp as label.
      // We also index by portId to support DPU slot-based matching.
      if (device.portId.isNotEmpty) {
        deviceMap[device.portId] = device;
      }
      deviceMap[device.label] = device;
    }

    for (final relationship in portDevices) {
      // Skip devices with empty baseline info
      if (relationship.deviceName.isEmpty &&
          (relationship.deviceIp == null || relationship.deviceIp!.isEmpty)) {
        continue;
      }

      final String deviceLabel = relationship.deviceName.isNotEmpty
          ? relationship.deviceName
          : (relationship.deviceIp ?? '');

      final Port? port = portMap[relationship.portId];
      // Try matching by portId first (DPU), then by label (host)
      final DevFloat? device =
          deviceMap[relationship.portId] ?? deviceMap[deviceLabel];

      if (port != null && device != null) {
        // Port center
        final Offset sourceOffset = Offset(
          port.position.dx + port.width / 2,
          port.position.dy + port.height / 2,
        );

        // Device connection point
        final Offset targetOffset = Offset(
          device.position.dx,
          device.position.dy,
        );

        // Determine status based on baseline/explore comparison
        final bool hasExplore = (relationship.exploreDevName != null &&
                relationship.exploreDevName!.isNotEmpty) ||
            (relationship.exploreDevIp != null &&
                relationship.exploreDevIp!.isNotEmpty);

        final bool isSame =
            relationship.deviceName == relationship.exploreDevName &&
                relationship.deviceIp == relationship.exploreDevIp;

        int status;
        if (!hasExplore) {
          // Has baseline but no explore -> dashed
          status = 0;
        } else if (isSame) {
          // Baseline and explore match -> green solid
          status = 1;
        } else {
          // Baseline and explore differ -> dashed
          status = 0;
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
  // generateExploreConnections  -- explore-tier connection lines
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    final List<ConnectionLine> connections = [];

    // Map ports by label
    final Map<String, Port> portMap = {};
    for (final port in ports) {
      portMap[port.label ?? ''] = port;
    }

    // Map explore devices by label or portId
    final Map<String, DevFloat> deviceMap = {};
    for (final device in devices) {
      if (device.portId.isNotEmpty) {
        deviceMap[device.portId] = device;
      }
      deviceMap[device.label] = device;
    }

    for (final relationship in portDevices) {
      // Only process relationships with explore data
      if ((relationship.exploreDevName == null ||
              relationship.exploreDevName!.isEmpty) &&
          (relationship.exploreDevIp == null ||
              relationship.exploreDevIp!.isEmpty)) {
        continue;
      }

      // Skip if baseline == explore (these are filtered out of explore tier)
      if (relationship.deviceName == relationship.exploreDevName &&
          relationship.deviceIp == relationship.exploreDevIp) {
        continue;
      }

      final String deviceLabel = (relationship.exploreDevName != null &&
              relationship.exploreDevName!.isNotEmpty)
          ? relationship.exploreDevName!
          : (relationship.exploreDevIp ?? '');

      final Port? port = portMap[relationship.portId];
      final DevFloat? device =
          deviceMap[relationship.portId] ?? deviceMap[deviceLabel];

      if (port != null && device != null) {
        // Port center
        final Offset sourceOffset = Offset(
          port.position.dx + port.width / 2,
          port.position.dy + port.height / 2,
        );

        // Device connection point
        final Offset targetOffset = Offset(
          device.position.dx,
          device.position.dy,
        );

        // Explore connections are always red (status = -1)
        // because duplicates (same as baseline) are filtered out
        connections.add(ConnectionLine(
          sourceOffset: sourceOffset,
          targetOffset: targetOffset,
          status: -1,
          slotId: relationship.portId,
        ));
      }
    }

    return connections;
  }
}
