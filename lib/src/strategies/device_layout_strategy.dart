import 'package:flutter/material.dart';
import '../models/port_device.dart';
import '../models/device_format.dart';
import '../models/port_status.dart';
import '../models/port.dart';
import '../models/connection_line.dart';
import '../widgets/floating_devices/dev_float.dart';
import '../widgets/center_device_widget.dart';

/// Holds the computed positions for baseline and explore floating devices.
class DevicePositions {
  final List<PositionedDevice> baselineDevices;
  final List<PositionedDevice> exploreDevices;
  const DevicePositions({
    required this.baselineDevices,
    required this.exploreDevices,
  });
}

/// A device paired with its computed position and size.
class PositionedDevice {
  final Offset position;
  final double size;
  final PortDevice device;
  const PositionedDevice({
    required this.position,
    required this.size,
    required this.device,
  });
}

/// Abstract base for all device layout strategies.
///
/// Each concrete strategy (host, dpu, switch) implements these methods
/// to compute positions, build widgets, and generate connection lines.
abstract class DeviceLayoutStrategy {
  /// Compute center device layout (position + size) from viewport.
  CenterDeviceLayout calculateCenterLayout(
      Size viewportSize, DeviceFormat format);

  /// Compute port positions around the center device.
  List<Port> calculatePortPositions(
    CenterDeviceLayout center,
    DeviceFormat format,
    Map<String, PortStatus> statusMap,
  );

  /// Compute floating device positions (both baseline and explore tiers).
  DevicePositions calculateDevicePositions(
    Size viewportSize,
    CenterDeviceLayout center,
    List<PortDevice> devices,
    List<Port> ports,
  );

  /// Build DevFloat widget instances from positioned devices.
  List<DevFloat> buildFloatingDevices(
    DevicePositions positions,
    List<PortDevice> devices,
  );

  /// Generate connection lines from ports to baseline devices.
  List<ConnectionLine> generateConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  );

  /// Generate connection lines from ports to explore-tier devices.
  List<ConnectionLine> generateExploreConnections(
    List<Port> ports,
    List<DevFloat> devices,
    List<PortDevice> portDevices,
  );
}
