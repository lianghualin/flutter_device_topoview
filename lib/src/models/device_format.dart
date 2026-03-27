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
