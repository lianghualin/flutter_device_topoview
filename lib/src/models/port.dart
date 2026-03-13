import 'package:flutter/material.dart';

class Port {
  final Offset position;
  final double width;
  final double height;
  final String? label;
  final int? portNumber;
  final bool? isUp;
  final bool isSelected;
  final bool isHovered;
  final double opacity;
  final bool isInvalid;
  final double rotation;
  final bool showLabel;

  const Port({
    required this.position,
    this.width = 30.0,
    this.height = 30.0,
    this.label,
    this.portNumber,
    this.isUp,
    this.isSelected = false,
    this.isHovered = false,
    this.opacity = 1.0,
    this.isInvalid = false,
    this.rotation = 0.0,
    this.showLabel = true,
  });

  Port copyWith({
    Offset? position,
    double? width,
    double? height,
    String? label,
    int? portNumber,
    bool? isUp,
    bool? isSelected,
    bool? isHovered,
    double? opacity,
    bool? isInvalid,
    double? rotation,
    bool? showLabel,
  }) {
    return Port(
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      label: label ?? this.label,
      portNumber: portNumber ?? this.portNumber,
      isUp: isUp ?? this.isUp,
      isSelected: isSelected ?? this.isSelected,
      isHovered: isHovered ?? this.isHovered,
      opacity: opacity ?? this.opacity,
      isInvalid: isInvalid ?? this.isInvalid,
      rotation: rotation ?? this.rotation,
      showLabel: showLabel ?? this.showLabel,
    );
  }
}
