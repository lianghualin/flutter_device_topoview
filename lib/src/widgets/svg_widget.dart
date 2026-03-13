import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

// ---------------------------------------------------------------------------
// SimpleShadow  (ported from host_topoview)
// ---------------------------------------------------------------------------

class SimpleShadow extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double sigma;
  final Color color;
  final Offset offset;

  const SimpleShadow({
    super.key,
    required this.child,
    this.opacity = 0.5,
    this.sigma = 2,
    this.color = Colors.black,
    this.offset = const Offset(2, 2),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if ((color.a * 255.0).round().clamp(0, 255) != 0)
          Transform.translate(
            offset: offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaY: sigma, sigmaX: sigma, tileMode: TileMode.decal),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.transparent,
                    width: 0,
                  ),
                ),
                child: Opacity(
                  opacity: opacity,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SvgClip  (ported from switch_topoview)
// ---------------------------------------------------------------------------

final _pathRegex = RegExp(r'<path\s+d="([^"]+)"');

///
/// This widget allows us to use an svg specified via [asset] as
/// a custom clipper for the [child]
///
/// Clip Behaviour:
///
/// Current clip behaviour is such that the clip/mask provided by [asset]
/// is expanded/shrunk to fit bounds of the [child] while respecting the mask's
/// aspect ratio.
/// Further more once the bounding is done, the mask is also centered if any of
/// the dimensions are smaller than the [child]

extension DimensionExtensions on Size {
  Size getBoxFitSize(
    Size sourceSize,
  ) {
    if (sourceSize.width == 0 || sourceSize.height == 0) {
      return this;
    }
    final double scaleWidth = width / sourceSize.width;
    final double scaleHeight = height / sourceSize.height;
    final double scale = min(scaleWidth, scaleHeight);

    final double maxWidth = sourceSize.width * scale;
    final double maxHeight = sourceSize.height * scale;
    return Size(maxWidth, maxHeight);
  }
}

abstract class ClipAsset {
  Future<String> load();

  ClipAsset._();

  factory ClipAsset.local({required String path}) => _BundledAsset(path);
}

class _BundledAsset extends ClipAsset {
  final String path;

  _BundledAsset(this.path) : super._();

  @override
  Future<String> load() {
    final String fullPath = 'packages/device_topology_view/$path';
    return rootBundle.loadString(fullPath);
  }
}

class SvgClip extends StatelessWidget {
  final String path;
  final ClipAsset asset;
  final Widget child;
  final double elevation;

  SvgClip({
    super.key,
    required this.path,
    this.elevation = 0,
  })  : asset = ClipAsset.local(path: path),
        child = SvgPicture.asset(
          path,
          width: 200,
          fit: BoxFit.contain,
          package: 'device_topology_view',
        );

  Path _getPath(String svg) {
    final pathData = _pathRegex.allMatches(svg);
    final List<Path> paths = [];
    for (final RegExpMatch match in pathData) {
      final String pathData = match.group(1)!;
      final path = parseSvgPathData(pathData);
      paths.add(path);
    }
    return paths.reduce((p, e) => Path.combine(PathOperation.union, p, e));
  }

  Future<String> _loadSvgString() async {
    final String fullPath = 'packages/device_topology_view/$path';
    return rootBundle.loadString(fullPath);
  }

  Future<Path> _loadPath() async =>
      _loadSvgString().then((value) => _getPath(value));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Path>(
      future: _loadPath(),
      builder: (BuildContext context, AsyncSnapshot<Path> snapshot) {
        if (snapshot.hasData) {
          return PhysicalShape(
            clipper: _SvgClipper(snapshot.data!),
            color: Colors.white,
            elevation: elevation,
            shadowColor: Colors.black,
            child: child,
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

class _SvgClipper extends CustomClipper<Path> {
  final Path path;

  const _SvgClipper(this.path);

  @override
  Path getClip(Size size) {
    final bounds = path.getBounds();
    final targetMaskSize =
        size.getBoxFitSize(Size(bounds.width, bounds.height));
    final scale = targetMaskSize.width / bounds.width;
    final moveX = max(0.0, (size.width - targetMaskSize.width) / 2);
    final moveY = max(0.0, (size.height - targetMaskSize.height) / 2);
    return path
        .transform(
          Float64List.fromList(
            [scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
          ),
        )
        .shift(Offset(moveX, moveY));
  }

  @override
  bool shouldReclip(_SvgClipper oldClipper) => oldClipper.path != path;
}
