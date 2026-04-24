import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_switch_device/flutter_switch_device.dart';
import 'package:device_topology_view/src/strategies/switch_rectangle_layout_strategy.dart';

void main() {
  group('SwitchRectangleLayoutStrategy.calculateCenterLayout', () {
    test('centers chassis vertically in the viewport', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      final viewportSize = const Size(1500, 1000);

      final layout = strategy.calculateCenterLayout(viewportSize, format);

      // centerSize in circle strategy = 500 * scaleFactor where
      // scaleFactor = (viewportSize.width / viewportSize.height).clamp(0.5, 1.0)
      // For 1500/1000 = 1.5 → clamped to 1.0 → centerSize = 500.
      expect(layout.size, closeTo(500, 0.01));

      // Rectangle strategy centers posY vertically: (H - centerSize) / 2.
      final expectedPosY = (1000 - layout.size) / 2;
      expect(layout.position.dy, closeTo(expectedPosY, 0.01));

      // posX is unchanged from the circle strategy: (W - centerSize) / 2.
      final expectedPosX = (1500 - layout.size) / 2;
      expect(layout.position.dx, closeTo(expectedPosX, 0.01));
    });

    test('inflates contentWidth/Height to minimums when viewport is small', () {
      final strategy = SwitchRectangleLayoutStrategy();
      final format = Switch28P();
      // Well below the 1500x800 minimums used by SwitchLayoutStrategy.
      final viewportSize = const Size(600, 400);

      final layout = strategy.calculateCenterLayout(viewportSize, format);

      // contentHeight is inflated to 800, so centered posY = (800 - size) / 2.
      final expectedPosY = (800 - layout.size) / 2;
      expect(layout.position.dy, closeTo(expectedPosY, 0.01));
    });
  });
}
