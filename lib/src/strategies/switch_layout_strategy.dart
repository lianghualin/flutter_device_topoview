import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/port_device.dart';
import '../models/device_format.dart';
import '../models/port_status.dart';
import '../models/port.dart';
import '../models/connection_line.dart';
import '../widgets/floating_devices/dev_float.dart';
import '../widgets/floating_devices/switch_dev_float.dart';
import '../widgets/floating_devices/host_dev_float.dart';
import '../widgets/floating_devices/dpu_dev_float.dart';
import '../widgets/floating_devices/unknown_dev_float.dart';
import '../widgets/center_device_widget.dart';
import 'device_layout_strategy.dart';

/// Layout strategy for switch topology views.
///
/// This is the most complex strategy. It manages:
/// - Port positioning from SwitchDeviceFormat templates
/// - Device positioning (odd ports -> top, even ports -> bottom)
/// - Stacked switch state (part selection, port filtering, opacity)
/// - isConfig mode (filters out probed devices)
/// - 4 floating device types (Switch, Host/MMI, DPU, Unknown)
class SwitchLayoutStrategy extends DeviceLayoutStrategy {
  final bool isConfig;
  final int stackedSwitchSelectedPart;

  static const double _minWidth = 1500.0;
  static const double _minHeight = 800.0;

  SwitchLayoutStrategy({
    this.isConfig = false,
    this.stackedSwitchSelectedPart = 0,
  });

  // ---------------------------------------------------------------------------
  // calculateCenterLayout
  // ---------------------------------------------------------------------------

  @override
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, DeviceFormat format) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // Scale factor based on aspect ratio
    double scaleFactor = contentWidth / contentHeight;
    scaleFactor = scaleFactor.clamp(0.5, 1.0);

    // Center size
    final double centerSize = 500.0 * scaleFactor;

    // Position centered with vertical offset
    final double posX = (contentWidth - centerSize) / 2;
    final double posY =
        (contentHeight - centerSize + centerSize * 0.35) / 2 +
            centerSize * 0.1 -
            10;

    return CenterDeviceLayout(
      position: Offset(posX, posY),
      size: centerSize,
    );
  }

  // ---------------------------------------------------------------------------
  // calculatePortPositions
  // ---------------------------------------------------------------------------

  @override
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    DeviceFormat format,
    Map<String, PortStatus> statusMap,
  ) {
    if (format is! SwitchDeviceFormat) {
      return [];
    }

    final SwitchDeviceFormat switchFormat = format;
    final int totalPorts = switchFormat.totalPortsNum;
    final int? validPortsNum = switchFormat.validPortsNum;
    final bool isStacked =
        switchFormat.totalPortsNum == 48 && validPortsNum != null;

    // Calculate port width
    double xSize;
    double portWidth;
    const double portHeight = 20;

    if (isStacked) {
      const int portsPerLayer = 12;
      xSize = center.size *
          (switchFormat.evenPortOffsetR[portsPerLayer - 1].dx -
              switchFormat.evenPortOffsetR[0].dx);
      portWidth = xSize / portsPerLayer * 1.2;
    } else {
      xSize = center.size *
          (switchFormat.evenPortOffsetR[totalPorts ~/ 2 - 1].dx -
              switchFormat.evenPortOffsetR[0].dx);
      portWidth = xSize / (totalPorts ~/ 2) * 1.2;
    }

    final List<Port> ports = [];

    for (int i = 1; i <= totalPorts; i++) {
      final bool isEven = i % 2 == 0;
      final bool isInvalid = validPortsNum != null && i > validPortsNum;

      // Convert port number to status map key
      final String statusKey = i.toString();
      final PortStatus? portStatus = statusMap[statusKey];
      final bool? isUp = portStatus != null
          ? _portStatusToBool(portStatus)
          : null;

      // Calculate position from format offsets
      final int offsetIndex = (i - 1) ~/ 2;
      final Offset portOffset = isEven
          ? switchFormat.evenPortOffsetR[offsetIndex]
          : switchFormat.oddPortOffsetR[offsetIndex];

      final double portX = center.position.dx + center.size * portOffset.dx;
      final double portY = center.position.dy + center.size * portOffset.dy;

      // Determine opacity for stacked switch
      double opacity = 1.0;
      if (isStacked) {
        if (stackedSwitchSelectedPart == 1) {
          opacity = (i >= 1 && i <= 24) ? 1.0 : 0.3;
        } else if (stackedSwitchSelectedPart == 2) {
          opacity = (i >= 25 && i <= 48) ? 1.0 : 0.3;
        } else {
          // No part selected: all dimmed
          opacity = 0.3;
        }
      }

      ports.add(Port(
        position: Offset(portX - portWidth / 2, portY - portHeight / 2),
        portNumber: i,
        width: portWidth,
        height: portHeight,
        isUp: isUp,
        isInvalid: isInvalid,
        opacity: opacity,
      ));
    }

    return ports;
  }

  // ---------------------------------------------------------------------------
  // calculateDevicePositions
  // ---------------------------------------------------------------------------

  @override
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports,
  ) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // Filter devices based on config mode and stacked switch state
    List<PortDevice> filteredDevices = List.from(devices);

    // Config mode: only show baseline devices (status >= 0)
    if (isConfig) {
      filteredDevices = filteredDevices
          .where((d) => d.connectionStatus >= 0)
          .toList();
    }

    // Stacked switch filtering
    if (_isStacked(devices)) {
      if (stackedSwitchSelectedPart == 1) {
        filteredDevices = filteredDevices
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 1 &&
                d.portNumber! <= 24)
            .toList();
      } else if (stackedSwitchSelectedPart == 2) {
        filteredDevices = filteredDevices
            .where((d) =>
                d.portNumber != null &&
                d.portNumber! >= 25 &&
                d.portNumber! <= 48)
            .toList();
      } else {
        // No part selected: no devices shown
        filteredDevices = [];
      }
    }

    // Get total ports from the ports list
    final int totalPorts = ports.length;

    final List<PositionedDevice> positioned = [];

    for (final device in filteredDevices) {
      final int portNum = device.portNumber ?? 0;
      final Offset pos = _calculateDevicePosition(
        portNum,
        totalPorts,
        device.connectionStatus,
        contentWidth,
        contentHeight,
      );

      // Calculate device size
      double scaleFactor = contentWidth / contentHeight;
      scaleFactor = scaleFactor.clamp(0.5, 1.0);
      double deviceSize = 75.0 * scaleFactor;

      // Adjust size for non-switch device types
      if (device.deviceType != 'Switch') {
        deviceSize *= 0.8;
      }

      positioned.add(PositionedDevice(
        position: pos,
        size: deviceSize,
        device: device,
      ));
    }

    return DevicePositions(
      baselineDevices: positioned,
      exploreDevices: const [], // Switch doesn't use explore tier
    );
  }

  // ---------------------------------------------------------------------------
  // buildFloatingDevices  -- dispatch to 4 device types
  // ---------------------------------------------------------------------------

  @override
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  ) {
    final List<DevFloat> result = [];

    for (final pd in positions.baselineDevices) {
      final dev = pd.device;
      final int portNum = dev.portNumber ?? 0;

      switch (dev.deviceType) {
        case 'Switch':
          result.add(SwitchDevFloat(
            portstatus: dev.connectionStatus,
            position: pd.position,
            label: dev.deviceName,
            size: pd.size,
            connectedPortNum: portNum,
            deviceStatus: isConfig ? true : dev.deviceStatus,
          ));
          break;
        case 'MMI':
        case 'Host':
          result.add(HostDevFloat(
            portstatus: dev.connectionStatus,
            position: pd.position,
            label: dev.deviceName,
            size: pd.size,
            connectedPortNum: portNum,
            deviceStatus: isConfig ? true : dev.deviceStatus,
          ));
          break;
        case 'DPU':
          result.add(DpuDevFloat(
            portstatus: dev.connectionStatus,
            position: pd.position,
            label: dev.deviceName,
            size: pd.size,
            connectedPortNum: portNum,
            totalPfs: 0,
            usedPfs: 0,
            deviceStatus: isConfig ? true : dev.deviceStatus,
          ));
          break;
        default:
          // Process unknown device label
          String processedLabel = dev.deviceName;
          if (dev.deviceName.contains('+') &&
              dev.deviceName.split('+').length >= 2) {
            final List<String> parts = dev.deviceName.split('+');
            if (parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
              processedLabel = 'Unknown Device';
            }
          }

          result.add(UnknownDevFloat(
            portstatus: dev.connectionStatus,
            position: pd.position,
            label: processedLabel,
            size: pd.size,
            connectedPortNum: portNum,
            deviceStatus: isConfig ? true : dev.deviceStatus,
          ));
          break;
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // generateConnections
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    final List<ConnectionLine> connections = [];

    for (int i = 0; i < devices.length; i++) {
      final DevFloat device = devices[i];

      // Find matching port by portNumber
      Port? matchedPort;
      try {
        matchedPort = ports.firstWhere(
            (port) => port.portNumber == device.connectedPortNum);
      } catch (_) {
        continue; // No matching port found
      }

      // Calculate connection points
      final Offset deviceCenter =
          Offset(device.position.dx, device.position.dy);
      final Offset portPoint = Offset(
        matchedPort.position.dx + matchedPort.width / 2,
        matchedPort.position.dy + matchedPort.height / 2,
      );

      // Inset the endpoint slightly into the device for visual overlap
      final double inset = device.size * 0.08;
      final double dx = deviceCenter.dx - portPoint.dx;
      final double dy = deviceCenter.dy - portPoint.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final Offset devicePoint = dist > 0
          ? Offset(
              deviceCenter.dx - inset * (dx / dist),
              deviceCenter.dy - inset * (dy / dist),
            )
          : deviceCenter;

      connections.add(ConnectionLine(
        sourceOffset: portPoint,
        targetOffset: devicePoint,
        status: device.portstatus,
        portNumber: matchedPort.portNumber,
        isConfig: isConfig,
      ));
    }

    return connections;
  }

  // ---------------------------------------------------------------------------
  // generateExploreConnections  -- switch doesn't use explore tier
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  ) {
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Check if current device set represents a stacked switch (48 ports).
  bool _isStacked(List<PortDevice> devices) {
    // A stacked switch is indicated by having devices with port numbers > 24
    return devices.any(
        (d) => d.portNumber != null && d.portNumber! > 24);
  }

  /// Calculate the position for a single device based on its port number.
  Offset _calculateDevicePosition(
    int portNum,
    int totalPorts,
    int portStatus,
    double contentWidth,
    double contentHeight,
  ) {
    final bool isEvenPort = portNum % 2 == 0;
    double scaleFactor = contentWidth / contentHeight;
    scaleFactor = scaleFactor.clamp(0.5, 1.0);

    final double imgSize = 75.0;
    final double deviceSize = imgSize * scaleFactor;

    // Margins and spacing
    final double margin = 100.0 * scaleFactor;
    final double usableWidth = contentWidth - (2 * margin);

    // For 48-port switches, use 24-port spacing per layer
    final int effectivePortsForSpacing = totalPorts == 48 ? 24 : totalPorts;
    final double spacing = effectivePortsForSpacing / 2 > 1
        ? (usableWidth - deviceSize) / (effectivePortsForSpacing / 2 - 1)
        : 0;

    // Calculate column index
    int columnIndex = ((portNum + 1) / 2).toInt();

    // For 48-port: remap ports 25-48 to columns 1-12
    if (totalPorts == 48 && portNum >= 25) {
      final int remappedPortNum = portNum - 24;
      columnIndex = ((remappedPortNum + 1) / 2).toInt();
    }

    final double xPosition =
        margin + deviceSize / 2 + (columnIndex - 1) * spacing;

    // Vertical position
    const double upperBorder = 30.0;
    double baseYPosition;

    if (isEvenPort) {
      baseYPosition = contentHeight - imgSize - upperBorder;
    } else {
      baseYPosition = imgSize + upperBorder;
    }

    // Y offset based on connection status and config mode
    double yOffset = 0;

    if (isConfig) {
      if (portStatus != -1) {
        if (isEvenPort) {
          yOffset = contentHeight * 0.01;
        } else {
          yOffset = -contentHeight * 0.01 - 30;
        }
      }
    } else {
      if (portStatus == -1) {
        // Probed device (red line)
        if (isEvenPort) {
          yOffset = contentHeight * 0.01 - contentHeight * 0.1;
        } else {
          yOffset = -contentHeight * 0.01 - contentHeight * 0.05;
        }
      } else {
        // Baseline or matched device
        if (isEvenPort) {
          yOffset = contentHeight * 0.01 - contentHeight * 0.2;
        } else {
          yOffset = -contentHeight * 0.01 + contentHeight * 0.1;
        }
      }
    }

    // Additional Y scatter for 48-port lower layer (ports 25-48)
    if (totalPorts == 48 && portNum >= 25) {
      if (isEvenPort) {
        yOffset += contentHeight * 0.05;
      } else {
        yOffset -= contentHeight * 0.05;
      }
    }

    // Additional upward shift for 48-port upper layer odd ports (1-24)
    if (totalPorts == 48 && portNum <= 24 && !isEvenPort) {
      yOffset -= contentHeight * 0.05;
    }

    final double yPosition = baseYPosition + yOffset;

    return Offset(xPosition, yPosition);
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
