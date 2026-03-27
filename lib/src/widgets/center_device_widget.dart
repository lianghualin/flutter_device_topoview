import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart';
import 'package:topology_view_icons/topology_view_icons.dart';

import '../models/device_format.dart';
import '../models/device_type.dart';

// ---------------------------------------------------------------------------
// Layout descriptor for center device positioning
// ---------------------------------------------------------------------------

class CenterDeviceLayout {
  final Offset position;
  final double size;
  const CenterDeviceLayout({required this.position, required this.size});
}

// ---------------------------------------------------------------------------
// CenterDeviceWidget  -- unified widget for host / agent / switch center device
// ---------------------------------------------------------------------------

class CenterDeviceWidget extends StatefulWidget {
  final CenterDeviceLayout layout;
  final Object format;
  final String label;
  final DeviceType deviceType;

  /// For stacked switches: 0=none, 1=upper, 2=lower
  final int stackedSwitchPart;
  final Function(int)? onStackedPartChanged;
  final VoidCallback? onSwitchHover;
  final VoidCallback? onSwitchHoverExit;

  const CenterDeviceWidget({
    super.key,
    required this.layout,
    required this.format,
    required this.label,
    required this.deviceType,
    this.stackedSwitchPart = 0,
    this.onStackedPartChanged,
    this.onSwitchHover,
    this.onSwitchHoverExit,
  });

  @override
  State<CenterDeviceWidget> createState() => _CenterDeviceWidgetState();
}

class _CenterDeviceWidgetState extends State<CenterDeviceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.deviceType) {
      case DeviceType.host:
        return _buildHostCenter();
      case DeviceType.agent:
        return _buildAgentCenter();
      case DeviceType.switch_:
        final fmt = widget.format;
        if (fmt is SwitchFormat && fmt.isStacked) {
          return _buildSwitchStackedCenter(fmt);
        }
        return _buildSwitchCenter();
    }
  }

  // -------------------------------------------------------------------------
  // Host center
  // -------------------------------------------------------------------------

  Widget _buildHostCenter() {
    final size = widget.layout.size;
    final pos = widget.layout.position;
    final fmt = widget.format as DeviceFormat;
    double widthAdjustment = (size * 1.8 - size) / 2;

    return Positioned(
      left: pos.dx + size * (1 - fmt.wSizeFactor) / 2 - widthAdjustment,
      top: pos.dy + size * fmt.hSizeFactor - size * 0.1,
      child: SizedBox(
        width: size * 1.8,
        height: null,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              alignment: Alignment.center,
              child: CustomPaint(
                size: Size(size, size),
                painter: TopoIconPainter(
                  deviceType: TopoDeviceType.host,
                  style: TopoIconStyle.lnm,
                ),
              ),
            ),
            Positioned(
              top: size * 0.95,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: size * 1.7,
                ),
                child: Tooltip(
                  message: widget.label,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: max(16, min(18, size / 12)),
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        letterSpacing: 0.15,
                        height: 0.95,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Agent center
  // -------------------------------------------------------------------------

  Widget _buildAgentCenter() {
    final size = widget.layout.size;
    final pos = widget.layout.position;
    final fmt = widget.format as DeviceFormat;

    return Positioned(
      left: pos.dx + size * (1 - fmt.wSizeFactor),
      top: pos.dy + size * fmt.hSizeFactor,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: TopoIconPainter(
                deviceType: TopoDeviceType.agent,
                style: TopoIconStyle.lnm,
              ),
            ),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 22, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Switch center (regular / non-stacked)
  // -------------------------------------------------------------------------

  Widget _buildSwitchCenter() {
    final size = widget.layout.size;
    final pos = widget.layout.position;
    final fmt = widget.format as SwitchFormat;

    return Positioned(
      left: pos.dx + size * (1 - fmt.wSizeFactor),
      top: pos.dy + size * fmt.hSizeFactor,
      child: MouseRegion(
        onEnter: (_) => widget.onSwitchHover?.call(),
        onExit: (_) => widget.onSwitchHoverExit?.call(),
        child: SizedBox(
          width: size * fmt.wSizeFactor,
          height: size * fmt.hSizeFactor,
          child: CustomPaint(
            size: Size(size * fmt.wSizeFactor, size * fmt.hSizeFactor),
            painter: TopoIconPainter(
              deviceType: TopoDeviceType.switch_,
              style: TopoIconStyle.lnm,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Switch center (stacked -- two units vertically)
  // -------------------------------------------------------------------------

  Widget _buildSwitchStackedCenter(SwitchFormat fmt) {
    final size = widget.layout.size;
    final pos = widget.layout.position;
    double switchWidth = size * fmt.wSizeFactor;
    double switchHeight = size * 0.15;
    double gap = size * 0.05;

    double upperOpacity;
    double lowerOpacity;

    if (widget.stackedSwitchPart == 0) {
      upperOpacity = 0.3;
      lowerOpacity = 0.3;
    } else if (widget.stackedSwitchPart == 1) {
      upperOpacity = 1.0;
      lowerOpacity = 0.3;
    } else {
      upperOpacity = 0.3;
      lowerOpacity = 1.0;
    }

    return MouseRegion(
      onEnter: (_) => widget.onSwitchHover?.call(),
      onExit: (_) => widget.onSwitchHoverExit?.call(),
      hitTestBehavior: HitTestBehavior.translucent,
      child: Stack(
      children: [
        // Upper switch (ports 1-24)
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: () {
              if (widget.onStackedPartChanged != null) {
                widget.onStackedPartChanged!(
                    widget.stackedSwitchPart == 1 ? 0 : 1);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Opacity(
                opacity: upperOpacity,
                child: SizedBox(
                  width: switchWidth,
                  height: switchHeight,
                  child: CustomPaint(
                    size: Size(switchWidth, switchHeight),
                    painter: TopoIconPainter(
                      deviceType: TopoDeviceType.switch_,
                      style: TopoIconStyle.lnm,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Lower switch (ports 25-48)
        Positioned(
          left: pos.dx,
          top: pos.dy + switchHeight + gap,
          child: GestureDetector(
            onTap: () {
              if (widget.onStackedPartChanged != null) {
                widget.onStackedPartChanged!(
                    widget.stackedSwitchPart == 2 ? 0 : 2);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Opacity(
                opacity: lowerOpacity,
                child: SizedBox(
                  width: switchWidth,
                  height: switchHeight,
                  child: CustomPaint(
                    size: Size(switchWidth, switchHeight),
                    painter: TopoIconPainter(
                      deviceType: TopoDeviceType.switch_,
                      style: TopoIconStyle.lnm,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// CenterDeviceLayer -- wraps CenterDeviceWidget in a Stack
// ---------------------------------------------------------------------------

class CenterDeviceLayer extends StatelessWidget {
  final CenterDeviceLayout layout;
  final Object format;
  final String label;
  final DeviceType deviceType;
  final int stackedSwitchPart;
  final Function(int)? onStackedPartChanged;
  final VoidCallback? onSwitchHover;
  final VoidCallback? onSwitchHoverExit;

  const CenterDeviceLayer({
    super.key,
    required this.layout,
    required this.format,
    required this.label,
    required this.deviceType,
    this.stackedSwitchPart = 0,
    this.onStackedPartChanged,
    this.onSwitchHover,
    this.onSwitchHoverExit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CenterDeviceWidget(
          layout: layout,
          format: format,
          label: label,
          deviceType: deviceType,
          stackedSwitchPart: stackedSwitchPart,
          onStackedPartChanged: onStackedPartChanged,
          onSwitchHover: onSwitchHover,
          onSwitchHoverExit: onSwitchHoverExit,
        ),
      ],
    );
  }
}
