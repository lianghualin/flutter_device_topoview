import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart' hide PortStatus;
import '../models/port_device.dart';
import '../models/port_status.dart';
import '../models/port.dart';
import '../models/connection_line.dart';
import '../widgets/floating_devices/dev_float.dart';
import '../widgets/floating_devices/switch_dev_float.dart';
import '../widgets/floating_devices/host_dev_float.dart';
import '../widgets/floating_devices/agent_dev_float.dart';
import '../widgets/floating_devices/unknown_dev_float.dart';
import '../widgets/center_device_widget.dart';
import 'device_layout_strategy.dart';

/// Layout strategy for switch topology views.
///
/// This is the most complex strategy. It manages:
/// - Port positioning from SwitchFormat templates
/// - Device positioning (odd ports -> top, even ports -> bottom)
/// - Stacked switch state (part selection, port filtering, opacity)
/// - isConfig mode (filters out probed devices)
/// - 4 floating device types (Switch, Host/MMI, Agent, Unknown)
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
      Size viewportSize, Object format) {
    final double contentWidth =
        viewportSize.width < _minWidth ? _minWidth : viewportSize.width;
    final double contentHeight =
        viewportSize.height < _minHeight ? _minHeight : viewportSize.height;

    // Cache viewport size for use by calculatePortPositions
    _cachedViewportSize = Size(contentWidth, contentHeight);

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
  // calculatePortPositions — delegates to SwitchDeviceView.getPortPositions()
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
    if (format is! SwitchFormat) {
      return [];
    }

    final SwitchFormat switchFormat = format;
    final int? validPortsNum = switchFormat.validPortsNum;

    // Use the package's layout engine for port center positions.
    // The viewport size was cached during calculateCenterLayout().
    final Map<int, Offset> portCenters = SwitchDeviceView.getPortPositions(
      switchFormat,
      _cachedViewportSize,
    );

    // Derive port dimensions from the package's layout engine.
    final double cs = _packageCenterSize(switchFormat, _cachedViewportSize);
    final double portWidth = _packagePortWidth(switchFormat, cs);
    final double portHeight = portWidth * 0.75;

    final List<Port> ports = [];

    for (final entry in portCenters.entries) {
      final int i = entry.key;
      final Offset portCenter = entry.value;
      final bool isInvalid = validPortsNum != null && i > validPortsNum;

      // Convert port number to status map key
      final String statusKey = i.toString();
      final PortStatus? portStatus = statusMap[statusKey];
      final bool? isUp =
          portStatus != null ? _portStatusToBool(portStatus) : null;

      // Determine opacity for stacked switch
      double opacity = 1.0;
      if (switchFormat.isStacked) {
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
        position:
            Offset(portCenter.dx - portWidth / 2, portCenter.dy - portHeight / 2),
        portNumber: i,
        width: portWidth,
        height: portHeight,
        isUp: isUp,
        isInvalid: isInvalid,
        opacity: opacity,
      ));
    }

    // Sort by port number for deterministic ordering
    ports.sort((a, b) => (a.portNumber ?? 0).compareTo(b.portNumber ?? 0));

    return ports;
  }

  /// Mirrors the package's _centerSize calculation.
  static double _packageCenterSize(SwitchFormat format, Size viewportSize) {
    final scaleX = viewportSize.width / format.minWidth;
    final scaleY = viewportSize.height / format.minHeight;
    return 500.0 * math.min(scaleX, scaleY);
  }

  /// Mirrors the package's _computePortWidth calculation.
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

  // ---------------------------------------------------------------------------
  // calculateDevicePositions  -- radial surround layout
  // ---------------------------------------------------------------------------

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

    // For icon sizing: use the actual visible viewport so icons look
    // proportional to what the user sees, not the inflated canvas.
    final double visibleWidth = actualViewport?.width ?? contentWidth;
    final double visibleHeight = actualViewport?.height ?? contentHeight;

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

    // --- Ellipse center = center of all ports ---
    // Ports sit on the switch widget. Center the rings on the port area
    // so lines radiate evenly outward.
    double portsCX = center.position.dx + center.size / 2;
    double portsCY = center.position.dy + center.size / 2;
    if (ports.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final port in ports) {
        sumX += port.position.dx + port.width / 2;
        sumY += port.position.dy + port.height / 2;
      }
      portsCX = sumX / ports.length;
      portsCY = sumY / ports.length;
    }
    final double ellipseCX = portsCX;
    final double ellipseCY = portsCY;

    // --- Device size by density tier ---
    final int deviceCount = filteredDevices.length;
    final double canvasMinDim = math.min(contentWidth, contentHeight);

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
    double baseDeviceSize =
        (canvasMinDim * sizeFactor).clamp(minSize, maxSize);

    // When the viewport is smaller than the canvas, boost icon size so
    // devices stay prominent in the visible area. The canvas is rendered
    // at 1:1 scale and clipped — icons that were "fine" on 800px look
    // sparse when only 300px is visible.
    final double viewportMinDim = math.min(visibleWidth, visibleHeight);
    if (viewportMinDim < canvasMinDim) {
      final double boost =
          math.sqrt(canvasMinDim / viewportMinDim).clamp(1.0, 1.4);
      baseDeviceSize = (baseDeviceSize * boost).clamp(minSize, maxSize * 1.3);
    }

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
    // Outer ring rotates clockwise by half-step so curved lines don't cross inner devices
    final double outerRingOffset = -(angleStep / 2);

    // Compute uniform angles and store per-device
    final Map<String, double> angleMap = {};
    for (int i = 0; i < N; i++) {
      final da = deviceAngles[i];
      final double uniformAngle = i * angleStep + rotationOffset;
      final String key = '${da.device.portId}_${da.device.portNumber}';
      angleMap[key] = uniformAngle;
    }

    // --- Split devices into real (inner ring) and config (outer ring) ---
    //
    // Inner ring (real connections):
    //   - Green matched (status 1): baseline == explore, verified real device
    //   - Explore devices: discovered real devices (from mismatch pairs)
    //
    // Outer ring (configured/expected):
    //   - Baseline with status 0: configured but unverified
    //   - Baseline with status -1: probed
    //   - Baseline from mismatch pairs (status 0 with explore): the "expected" side

    // Explore devices (from mismatch: baseline != explore)
    final List<PortDevice> exploreDevices = filteredDevices
        .where((d) =>
            ((d.exploreDevName != null && d.exploreDevName!.isNotEmpty) ||
                (d.exploreDevIp != null && d.exploreDevIp!.isNotEmpty)) &&
            !(d.deviceName == d.exploreDevName &&
                d.deviceIp == d.exploreDevIp))
        .toList();
    final Set<String> explorePortKeys =
        exploreDevices.map((d) => '${d.portId}_${d.portNumber}').toSet();

    final List<PositionedDevice> innerPositioned = []; // real devices
    final List<PositionedDevice> outerPositioned = []; // config devices

    for (final da in deviceAngles) {
      final dev = da.device;
      final String key = '${dev.portId}_${dev.portNumber}';
      final double angle = angleMap[key]!;
      final double rad = angle * math.pi / 180;

      double deviceSize = baseDeviceSize;
      if (dev.deviceType != 'Switch') {
        deviceSize *= 0.8;
      }

      final bool isReal = dev.connectionStatus == 1 || dev.connectionStatus == -1;
      final bool hasMismatchExplore = explorePortKeys.contains(key);

      if (isReal) {
        // Green matched or probed → inner ring (real/discovered device)
        double x = ellipseCX + radiusX * math.cos(rad);
        double y = ellipseCY - radiusY * math.sin(rad);
        x = x.clamp(baselineMargin, contentWidth - baselineMargin);
        y = y.clamp(baselineMargin, contentHeight - baselineMargin);
        innerPositioned.add(PositionedDevice(
          position: Offset(x, y), size: deviceSize, device: dev));
      } else if (hasMismatchExplore) {
        // Mismatch baseline (status 0) → outer ring (config), rotated
        final double outerRad = (angle + outerRingOffset) * math.pi / 180;
        double x = ellipseCX + outerRadiusX * math.cos(outerRad);
        double y = ellipseCY - outerRadiusY * math.sin(outerRad);
        x = x.clamp(exploreMargin, contentWidth - exploreMargin);
        y = y.clamp(exploreMargin, contentHeight - exploreMargin);
        outerPositioned.add(PositionedDevice(
          position: Offset(x, y), size: exploreDeviceSize, device: dev));
      } else {
        // Status 0 (unverified), no explore → outer ring (config), rotated
        final double outerRad = (angle + outerRingOffset) * math.pi / 180;
        double x = ellipseCX + outerRadiusX * math.cos(outerRad);
        double y = ellipseCY - outerRadiusY * math.sin(outerRad);
        x = x.clamp(exploreMargin, contentWidth - exploreMargin);
        y = y.clamp(exploreMargin, contentHeight - exploreMargin);
        outerPositioned.add(PositionedDevice(
          position: Offset(x, y), size: exploreDeviceSize, device: dev));
      }
    }

    // Place explore devices on inner ring (real discovered devices)
    for (final device in exploreDevices) {
      final String key = '${device.portId}_${device.portNumber}';
      final double? angle = angleMap[key];
      if (angle == null) continue;

      final double rad = angle * math.pi / 180;
      double x = ellipseCX + radiusX * math.cos(rad);
      double y = ellipseCY - radiusY * math.sin(rad);
      x = x.clamp(baselineMargin, contentWidth - baselineMargin);
      y = y.clamp(baselineMargin, contentHeight - baselineMargin);

      double deviceSize = baseDeviceSize;
      if (device.deviceType != 'Switch') {
        deviceSize *= 0.8;
      }

      innerPositioned.add(PositionedDevice(
        position: Offset(x, y), size: deviceSize, device: device));
    }

    return DevicePositions(
      baselineDevices: outerPositioned, // config on outer
      exploreDevices: innerPositioned,  // real on inner
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

    // Outer ring devices (config/baseline) — baselineDevices in DevicePositions
    for (final pd in positions.baselineDevices) {
      result.add(_buildDevFloat(pd, pd.device.deviceName,
          isReal: false));
    }

    // Inner ring devices (real connections) — exploreDevices in DevicePositions
    for (final pd in positions.exploreDevices) {
      final dev = pd.device;

      String label;
      if (dev.connectionStatus == 1 || dev.connectionStatus == -1) {
        // Green matched or probed: use baseline name (it IS the real device)
        label = dev.deviceName;
      } else {
        // Explore device from mismatch: use explore name
        label = (dev.exploreDevName != null && dev.exploreDevName!.isNotEmpty)
            ? dev.exploreDevName!
            : (dev.exploreDevIp ?? dev.deviceName);
      }

      result.add(_buildDevFloat(pd, label,
          isReal: true,
          inboundUtilization: dev.exploreInboundUtilization,
          outboundUtilization: dev.exploreOutboundUtilization));
    }

    return result;
  }

  /// Build a DevFloat widget from a PositionedDevice and a label.
  DevFloat _buildDevFloat(PositionedDevice pd, String label, {
    bool isReal = false,
    double? inboundUtilization,
    double? outboundUtilization,
  }) {
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
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
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
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
        );
      case 'Agent':
        return AgentDevFloat(
          portstatus: dev.connectionStatus,
          position: pd.position,
          label: label,
          size: pd.size,
          connectedPortNum: portNum,
          totalPfs: 0,
          usedPfs: 0,
          deviceStatus: isConfig ? true : dev.deviceStatus,
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
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
          inboundUtilization: inboundUtilization,
          outboundUtilization: outboundUtilization,
          isRealDevice: isReal,
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
        forceCurve: !isConfig, // straight lines in config mode
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

      // Inner ring: use actual device status for line color
      // Green matched (status 1) → green solid line
      // Explore mismatch → red line (status from device, typically -1 or 0)
      final int lineStatus = device.portstatus == 1 ? 1 : -1;
      connections.add(ConnectionLine(
        sourceOffset: portPoint,
        targetOffset: deviceCenter,
        status: lineStatus,
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
