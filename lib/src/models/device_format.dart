import 'dart:ui';

abstract class DeviceFormat {
  const DeviceFormat({
    required this.imgPath,
    this.hSizeFactor = 0.15,
    this.wSizeFactor = 1.0,
  });

  final String imgPath;
  final double hSizeFactor;
  final double wSizeFactor;
}

class SimpleDeviceFormat extends DeviceFormat {
  const SimpleDeviceFormat({
    required super.imgPath,
    super.hSizeFactor,
    super.wSizeFactor,
  });
}

class SwitchDeviceFormat extends DeviceFormat {
  const SwitchDeviceFormat({
    required super.imgPath,
    required this.evenPortOffsetR,
    required this.oddPortOffsetR,
    required this.totalPortsNum,
    this.validPortsNum,
    this.isStacked = false,
    this.minWidth = 1500.0,
    this.minHeight = 800.0,
    super.hSizeFactor,
    super.wSizeFactor,
  });

  final List<Offset> evenPortOffsetR;
  final List<Offset> oddPortOffsetR;
  final int totalPortsNum;
  final int? validPortsNum;
  final bool isStacked;
  final double minWidth;
  final double minHeight;
}
