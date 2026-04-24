/// Chooses how floating devices are laid out around a switch center.
///
/// Applies only when `deviceType == DeviceType.switch_`. Host and agent
/// device types ignore this.
enum SwitchLayoutMode {
  /// Two concentric rings: inner = real/explored devices, outer = baseline/config.
  /// This is the original and default layout.
  circle,

  /// Columns above and below the chassis. Each column has two slots:
  /// the slot adjacent to the chassis holds the real/explored device,
  /// the outer slot (at the screen edge) holds the baseline/config device.
  rectangle,
}
