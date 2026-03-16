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
  // calculateDevicePositions  -- radial surround layout
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

    if (isConfig) {
      filteredDevices = filteredDevices
          .where((d) => d.connectionStatus >= 0)
          .toList();
    }

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
        filteredDevices = [];
      }
    }

    if (filteredDevices.isEmpty) {
      return DevicePositions(
        baselineDevices: const [],
        exploreDevices: const [],
      );
    }

    // --- Ellipse center (viewport center, not switch center) ---
    // The switch is positioned above viewport center, so centering the
    // ellipse on the viewport gives equal room for top and bottom devices.
    final double ellipseCX = contentWidth / 2;
    final double ellipseCY = contentHeight / 2;

    // --- Device size by density tier ---
    final int deviceCount = filteredDevices.length;
    final double minDimension = math.min(contentWidth, contentHeight);

    double sizeFactor;
    double minSize, maxSize;
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
    final double baseDeviceSize =
        (minDimension * sizeFactor).clamp(minSize, maxSize);

    // --- Compute ring gap and explore size upfront ---
    final double exploreDeviceSize = baseDeviceSize * 0.7;
    final double ringGap =
        (baseDeviceSize + 30) / 2 + (exploreDeviceSize + 30) / 2 + 12;

    // --- Two-ring radius calculation (sized from outside in) ---
    final double exploreMargin = (exploreDeviceSize + 30) / 2 + 10;
    final double baselineMargin = (baseDeviceSize + 30) / 2 + 10;

    // Available space from ellipse center to viewport edge
    final double availableUp = ellipseCY - exploreMargin;
    final double availableDown = contentHeight - ellipseCY - exploreMargin;
    final double availableLeft = ellipseCX - exploreMargin;
    final double availableRight = contentWidth - ellipseCX - exploreMargin;

    // Outer ring: fills to viewport edge
    final double outerRadiusY = math.min(availableUp, availableDown);
    final double outerRadiusX = math.min(availableLeft, availableRight);

    // Inner ring: outer ring minus gap
    final double radiusY = outerRadiusY - ringGap;
    final double radiusX = outerRadiusX - ringGap;

    // --- Port X normalization range ---
    // Find min/max port X positions among ports that have connected devices
    final Set<int> connectedPortNums =
        filteredDevices.map((d) => d.portNumber ?? 0).toSet();
    double minPortX = double.infinity;
    double maxPortX = double.negativeInfinity;
    for (final port in ports) {
      if (port.portNumber != null && connectedPortNums.contains(port.portNumber)) {
        final double px = port.position.dx + port.width / 2;
        if (px < minPortX) minPortX = px;
        if (px > maxPortX) maxPortX = px;
      }
    }
    // Fallback if range is zero or invalid
    if (minPortX >= maxPortX) {
      minPortX = center.position.dx;
      maxPortX = center.position.dx + center.size;
    }
    final double portXRange = maxPortX - minPortX;

    // --- Build port lookup for X positions ---
    final Map<int, double> portXByNum = {};
    for (final port in ports) {
      if (port.portNumber != null) {
        portXByNum[port.portNumber!] = port.position.dx + port.width / 2;
      }
    }

    // =====================================================================
    // Two-ring staggered layout:
    //   Inner ring = baseline devices (uniform spacing)
    //   Outer ring = explore devices (uniform spacing, half-step offset)
    // =====================================================================

    // --- Step 1: Compute natural angles for sort order only ---
    final List<_DeviceAngle> deviceAngles = [];
    for (int i = 0; i < filteredDevices.length; i++) {
      final device = filteredDevices[i];
      final int portNum = device.portNumber ?? 0;
      final bool isOddPort = portNum % 2 != 0;

      double naturalAngle;
      if (portNum == 0) {
        naturalAngle = i % 2 == 0 ? 90.0 : 270.0;
      } else {
        final double portX = portXByNum[portNum] ??
            (center.position.dx + center.size / 2);
        final double normalizedX =
            ((portX - minPortX) / portXRange).clamp(0.0, 1.0);

        if (isOddPort) {
          naturalAngle = 160.0 - normalizedX * 140.0;
        } else {
          naturalAngle = 200.0 + normalizedX * 140.0;
        }
      }

      deviceAngles.add(_DeviceAngle(
        device: device,
        angle: naturalAngle,
        index: i,
      ));
    }

    // Sort by natural angle to preserve spatial mapping
    deviceAngles.sort((a, b) => a.angle.compareTo(b.angle));

    // --- Step 2: Assign uniform angles on inner ring ---
    final int N = deviceAngles.length;
    final double angleStep = 360.0 / N;
    // Counterclockwise rotation offset so devices don't sit exactly at 0°/90°/180°/270°
    const double rotationOffset = 15.0;

    final List<PositionedDevice> positioned = [];
    // Map from portId+portNumber to uniform angle index for explore lookup
    final Map<String, double> baselineAngleMap = {};

    for (int i = 0; i < N; i++) {
      final da = deviceAngles[i];
      final double uniformAngle = i * angleStep + rotationOffset;

      final double rad = uniformAngle * math.pi / 180;
      double x = ellipseCX + radiusX * math.cos(rad);
      double y = ellipseCY - radiusY * math.sin(rad);

      x = x.clamp(baselineMargin, contentWidth - baselineMargin);
      y = y.clamp(baselineMargin, contentHeight - baselineMargin);

      double deviceSize = baseDeviceSize;
      if (da.device.deviceType != 'Switch') {
        deviceSize *= 0.8;
      }

      positioned.add(PositionedDevice(
        position: Offset(x, y),
        size: deviceSize,
        device: da.device,
      ));

      // Store uniform angle for explore device matching
      final String key =
          '${da.device.portId}_${da.device.portNumber}';
      baselineAngleMap[key] = uniformAngle;
    }

    // --- Step 3: Place explore devices on outer ring ---
    final List<PortDevice> exploreDevices = filteredDevices
        .where((d) =>
            ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
                (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
            !(d.deviceName == d.exploreDevName &&
                d.deviceIp == d.exploreDevIp))
        .toList();
    final List<PositionedDevice> explorePositioned = [];
    for (final device in exploreDevices) {
      final String key = '${device.portId}_${device.portNumber}';
      final double? baseAngle = baselineAngleMap[key];
      if (baseAngle == null) continue;

      // Same angle as baseline — lines go in the same direction, no crossing
      final double exploreAngle = baseAngle;

      final double rad = exploreAngle * math.pi / 180;
      double x = ellipseCX + outerRadiusX * math.cos(rad);
      double y = ellipseCY - outerRadiusY * math.sin(rad);

      x = x.clamp(exploreMargin, contentWidth - exploreMargin);
      y = y.clamp(exploreMargin, contentHeight - exploreMargin);

      explorePositioned.add(PositionedDevice(
        position: Offset(x, y),
        size: exploreDeviceSize,
        device: device,
      ));
    }

    return DevicePositions(
      baselineDevices: positioned,
      exploreDevices: explorePositioned,
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

    // Baseline devices
    for (final pd in positions.baselineDevices) {
      result.add(_buildDevFloat(pd, pd.device.deviceName));
    }

    // Explore devices
    for (final pd in positions.exploreDevices) {
      final String label = (pd.device.exploreDevName != null &&
              pd.device.exploreDevName!.isNotEmpty)
          ? pd.device.exploreDevName!
          : (pd.device.exploreDevIp ?? pd.device.deviceName);
      result.add(_buildDevFloat(pd, label));
    }

    return result;
  }

  /// Build a DevFloat widget from a PositionedDevice and a label.
  DevFloat _buildDevFloat(PositionedDevice pd, String label) {
    final dev = pd.device;
    final int portNum = dev.portNumber ?? 0;

    switch (dev.deviceType) {
      case 'Switch':
        return SwitchDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
        );
      case 'MMI':
      case 'Host':
        return HostDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
        );
      case 'DPU':
        return DpuDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          totalPfs: 0,
          usedPfs: 0,
          deviceStatus: isConfig ? true : dev.deviceStatus,
        );
      default:
        String processedLabel = label;
        if (label.contains('+') && label.split('+').length >= 2) {
          final List<String> parts = label.split('+');
          if (parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
            processedLabel = 'Unknown Device';
          }
        }
        return UnknownDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: processedLabel,
          size: pd.size,
          connectedPortNum: portNum,
          deviceStatus: isConfig ? true : dev.deviceStatus,
        );
    }
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
  // generateExploreConnections
  // ---------------------------------------------------------------------------

  @override
  List<ConnectionLine> generateExploreConnections(
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
        continue;
      }

      final Offset portPoint = Offset(
        matchedPort.position.dx + matchedPort.width / 2,
        matchedPort.position.dy + matchedPort.height / 2,
      );

      final Offset deviceCenter =
          Offset(device.position.dx, device.position.dy);

      connections.add(ConnectionLine(
        sourceOffset: portPoint,
        targetOffset: deviceCenter,
        status: -1, // explore connections are always red
        portNumber: matchedPort.portNumber,
        isConfig: isConfig,
      ));
    }

    return connections;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Check if current device set represents a stacked switch (48 ports).
  bool _isStacked(List<PortDevice> devices) {
    // A stacked switch has devices with port numbers > 28
    // (28-port switches have ports 1-28 and are NOT stacked)
    return devices.any(
        (d) => d.portNumber != null && d.portNumber! > 28);
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

/// Helper to pair a device with its computed angle for radial placement.
class _DeviceAngle {
  final PortDevice device;
  final double angle;
  final int index;

  const _DeviceAngle({
    required this.device,
    required this.angle,
    required this.index,
  });
}
