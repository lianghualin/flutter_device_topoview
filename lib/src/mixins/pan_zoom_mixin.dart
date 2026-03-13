import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

mixin PanZoomMixin<T extends StatefulWidget> on State<T> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset? _dragStartPosition;

  static const double _minScale = 1.0;
  static const double _maxScale = 2.0;
  static const double _scaleStep = 0.05;

  double get scale => _scale;
  Offset get offset => _offset;

  Offset _limitOffset(
      Offset offset, double contentWidth, double contentHeight) {
    double scaledWidth = contentWidth * _scale;
    double scaledHeight = contentHeight * _scale;
    double maxOffsetX = (scaledWidth - contentWidth) / 2;
    double maxOffsetY = (scaledHeight - contentHeight) / 2;
    return Offset(
      offset.dx.clamp(-maxOffsetX, maxOffsetX),
      offset.dy.clamp(-maxOffsetY, maxOffsetY),
    );
  }

  void handlePointerSignal(
      PointerSignalEvent event, double contentWidth, double contentHeight) {
    if (event is PointerScrollEvent) {
      setState(() {
        final delta = event.scrollDelta.dy > 0 ? -_scaleStep : _scaleStep;
        double newScale = (_scale + delta).clamp(_minScale, _maxScale);
        if (_scale > 1.0 && newScale == 1.0) {
          _offset = Offset.zero;
        } else {
          _offset = _limitOffset(_offset, contentWidth, contentHeight);
        }
        _scale = newScale;
      });
    }
  }

  void handlePanStart(DragStartDetails details) {
    if (_scale > 1.0) {
      _dragStartPosition = details.globalPosition;
    }
  }

  void handlePanUpdate(
      DragUpdateDetails details, double contentWidth, double contentHeight) {
    if (_scale > 1.0 && _dragStartPosition != null) {
      setState(() {
        Offset newOffset = _offset + (details.globalPosition - _dragStartPosition!);
        _offset = _limitOffset(newOffset, contentWidth, contentHeight);
        _dragStartPosition = details.globalPosition;
      });
    }
  }

  void handlePanEnd(DragEndDetails details) {
    _dragStartPosition = null;
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    // ignore: deprecated_member_use
    ..translate(_offset.dx, _offset.dy)
    // ignore: deprecated_member_use
    ..scale(_scale, _scale, 1.0);
}
