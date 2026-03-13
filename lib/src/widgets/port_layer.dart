import 'package:flutter/material.dart';
import '../models/port.dart';
import 'port_widget.dart';

class PortLayer extends StatelessWidget {
  final List<Port> ports;
  final void Function(int portNum)? onPortHover;
  final void Function()? onPortHoverExit;
  final void Function(int portNum)? onPortTap;
  final bool isConfig;

  const PortLayer({
    super.key,
    required this.ports,
    this.onPortHover,
    this.onPortHoverExit,
    this.onPortTap,
    this.isConfig = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: ports
          .map((port) => PortWidget(
                port: port,
                onHover: onPortHover,
                onHoverExit: onPortHoverExit,
                onTap: onPortTap,
                isConfig: isConfig,
              ))
          .toList(),
    );
  }
}
