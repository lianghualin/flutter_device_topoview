import 'package:flutter/material.dart';
import 'package:topology_view_icons/topology_view_icons.dart';

import '../models/port.dart';

class PortWidget extends StatefulWidget {
  final Port port;
  final Function(int portNum)? onHover;
  final Function()? onHoverExit;
  final Function(int portNum)? onTap;
  final bool isConfig;

  const PortWidget({
    super.key,
    required this.port,
    this.onHover,
    this.onHoverExit,
    this.onTap,
    this.isConfig = false,
  });

  @override
  State<PortWidget> createState() => _PortWidgetState();
}

class _PortWidgetState extends State<PortWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Determine hover-float direction based on port number parity
    final bool isEven =
        widget.port.portNumber != null && widget.port.portNumber! % 2 == 0;
    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: isEven ? const Offset(0, 0.1) : const Offset(0, -0.1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.port.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.port.isSelected != oldWidget.port.isSelected) {
      if (widget.port.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEven =
        widget.port.portNumber != null && widget.port.portNumber! % 2 == 0;

    // Determine painter parameters based on config / invalid / status
    final bool isDisabled =
        widget.port.isInvalid || (!widget.isConfig && widget.port.isUp == null);
    final bool isUp = !widget.port.isInvalid &&
        !widget.isConfig &&
        widget.port.isUp == true;
    final PortDirection direction =
        isEven ? PortDirection.down : PortDirection.up;

    Widget svgWidget = CustomPaint(
      painter: TopoPortPainter(
        isUp: isUp,
        isDisabled: isDisabled,
        style: TopoIconStyle.flat,
        direction: direction,
      ),
    );

    // Wrap in rotation transform when rotation != 0
    if (widget.port.rotation != 0) {
      svgWidget = Transform.rotate(
        angle: widget.port.rotation,
        child: svgWidget,
      );
    }

    return Positioned(
      left: widget.port.position.dx,
      top: widget.port.position.dy,
      child: Opacity(
        opacity: widget.port.opacity,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            _controller.forward();
            if (widget.onHover != null && widget.port.portNumber != null) {
              widget.onHover!(widget.port.portNumber!);
            }
          },
          onExit: (_) {
            if (!widget.port.isSelected) {
              _controller.reverse();
            }
            if (widget.onHoverExit != null) {
              widget.onHoverExit!();
            }
          },
          child: SlideTransition(
            position: _positionAnimation,
            child: GestureDetector(
              onTap: () {
                if (widget.onTap != null && widget.port.portNumber != null) {
                  widget.onTap!(widget.port.portNumber!);
                }
              },
              child: SizedBox(
                width: widget.port.width,
                height: widget.port.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: widget.port.width,
                      height: widget.port.height,
                      child: svgWidget,
                    ),
                    // Show label only when port is valid and showLabel is true
                    if (!widget.port.isInvalid && widget.port.showLabel)
                      Text(
                        widget.port.label ??
                            (widget.port.portNumber != null
                                ? '${widget.port.portNumber}'
                                : ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
