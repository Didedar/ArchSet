import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders the map pin bitmap at runtime.
///
/// Mapbox annotations need raw PNG bytes rather than a widget, and drawing
/// the pin here keeps it themeable without shipping a fixed-colour asset.
abstract final class ArtifactMarker {
  static const double _width = 30;
  static const double _height = 40;
  static const Offset _headCenter = Offset(_width / 2, _width / 2);
  static const double _headRadius = 12;

  /// Cache keyed by the inputs that change the bitmap, so panning the map or
  /// re-emitting the artifact list doesn't re-rasterise the same pin.
  static final Map<String, Uint8List> _cache = {};

  /// A teardrop pin whose tip sits on the artifact's coordinate.
  ///
  /// Pair with `IconAnchor.BOTTOM` so the tip, not the centre, marks the spot.
  static Future<Uint8List> build({
    required Color fill,
    required Color border,
    double devicePixelRatio = 3.0,
  }) async {
    final cacheKey =
        '${fill.toARGB32()}_${border.toARGB32()}_$devicePixelRatio';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final head = Path()
      ..addOval(Rect.fromCircle(center: _headCenter, radius: _headRadius));
    final tail = Path()
      ..moveTo(_headCenter.dx - 6.5, _headCenter.dy + 9)
      ..lineTo(_headCenter.dx, _height - 1.5)
      ..lineTo(_headCenter.dx + 6.5, _headCenter.dy + 9)
      ..close();
    final pin = Path.combine(PathOperation.union, head, tail);

    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(pin, Paint()..color = fill);
    canvas.drawPath(
      pin,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(_headCenter, 4.5, Paint()..color = border);

    final image = await recorder.endRecording().toImage(
      (_width * devicePixelRatio).ceil(),
      (_height * devicePixelRatio).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final bytes = byteData!.buffer.asUint8List();
    _cache[cacheKey] = bytes;
    return bytes;
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
