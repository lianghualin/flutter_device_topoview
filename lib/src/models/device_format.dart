import 'dart:ui';

abstract class DeviceFormat {
  const DeviceFormat({
    required this.imgPath,
    this.hSizeFactor = 0.15,
    this.wSizeFactor = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
  });

  final String imgPath;
  final double hSizeFactor;
  final double wSizeFactor;

  /// Pixel offset to adjust the center device image position.
  final double imageOffsetX;
  final double imageOffsetY;
}

class SimpleDeviceFormat extends DeviceFormat {
  const SimpleDeviceFormat({
    required super.imgPath,
    super.hSizeFactor,
    super.wSizeFactor,
    super.imageOffsetX,
    super.imageOffsetY,
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
    super.imageOffsetX,
    super.imageOffsetY,
  });

  final List<Offset> evenPortOffsetR;
  final List<Offset> oddPortOffsetR;
  final int totalPortsNum;
  final int? validPortsNum;
  final bool isStacked;
  final double minWidth;
  final double minHeight;
}
