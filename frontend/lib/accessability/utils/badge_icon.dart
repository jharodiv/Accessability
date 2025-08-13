// lib/utils/badge_icon.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BadgeIcon {
  // simple cache to avoid re-creating identical icons
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Public factory: returns a cached BitmapDescriptor if available.
  static Future<BitmapDescriptor> createBadgeWithIcon({
    required BuildContext ctx,
    int size = 50,
    Color outerRingColor = Colors.white,
    Color innerBgColor = Colors.transparent,
    Color iconBgColor = const Color(0xFFEA4335),
    required IconData icon,
    double outerRingWidthRatio = 0.06,
    double innerRatio = 0.74,
    double iconBgRatio = 0.40,
    double iconRatio = 0.52,
  }) async {
    final cacheKey =
        '${size}_${icon.codePoint}_${icon.fontFamily}_${iconBgColor.value}_$innerRatio\_$iconRatio';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final bytes = await _createBadgeBytes(
      ctx: ctx,
      size: size,
      outerRingColor: outerRingColor,
      innerBgColor: innerBgColor,
      iconBgColor: iconBgColor,
      icon: icon,
      outerRingWidthRatio: outerRingWidthRatio,
      innerRatio: innerRatio,
      iconBgRatio: iconBgRatio,
      iconRatio: iconRatio,
    );

    final bmp = BitmapDescriptor.fromBytes(bytes);
    _cache[cacheKey] = bmp;
    return bmp;
  }

  /// Core drawing function (kept public so it can be used directly if needed).
  static Future<Uint8List> _createBadgeBytes({
    required BuildContext ctx,
    int size = 92,
    required Color outerRingColor,
    required Color innerBgColor,
    required Color iconBgColor,
    required IconData icon,
    double outerRingWidthRatio = 0.06,
    double innerRatio = 0.74,
    double iconBgRatio = 0.40,
    double iconRatio = 0.52,
  }) async {
    final double pixelRatio = MediaQuery.of(ctx).devicePixelRatio;
    final int imgSize = (size * pixelRatio).round();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    // center of head (lifted to leave room for pointer)
    final Offset center = Offset(imgSize / 2.0, imgSize * 0.32);

    // sizes
    final double headRadius = imgSize * 0.30;

    // use passed ratios (you can tweak these in the call site)
    final double coloredRatio = innerRatio.clamp(0.0, 1.0);
    final double coloredRadius = headRadius * coloredRatio;

    // pointer tuning (example values)
    final double pointerLengthFactor = 0.18;
    final double pointerWidthFactor = 0.45;
    final double pointerOverlap = 0.04;

    final double pointerTopY =
        center.dy + headRadius - (headRadius * pointerOverlap);
    final double pointerBottomY =
        pointerTopY + headRadius * pointerLengthFactor;
    final double pointerHalfWidth = headRadius * pointerWidthFactor;

    // white head (outer circle)
    paint
      ..style = PaintingStyle.fill
      ..color = outerRingColor;
    canvas.drawCircle(center, headRadius, paint);

    // colored inner dot
    paint.color = iconBgColor;
    canvas.drawCircle(center, coloredRadius, paint);

    // subtle gloss
    final Paint gloss = Paint()
      ..shader = ui.Gradient.radial(
        center.translate(-coloredRadius * 0.24, -coloredRadius * 0.24),
        coloredRadius * 0.9,
        [Colors.white.withOpacity(0.22), Colors.transparent],
      )
      ..isAntiAlias = true;
    canvas.drawCircle(center, coloredRadius, gloss);

    // pointer
    final Path pointer = Path();
    final double cx = center.dx;
    pointer.moveTo(cx + pointerHalfWidth, pointerTopY);
    pointer.lineTo(cx, pointerBottomY);
    pointer.lineTo(cx - pointerHalfWidth, pointerTopY);
    pointer.close();

    paint
      ..style = PaintingStyle.fill
      ..color = outerRingColor;
    canvas.drawPath(pointer, paint);

    // pointer edge (crisp)
    final Paint pointerEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, pixelRatio * 0.45)
      ..color = Colors.black.withOpacity(0.06)
      ..isAntiAlias = true;
    canvas.drawPath(pointer, pointerEdge);

    // glyph scale: use iconRatio to control size
    final double effectiveIconRatio = iconRatio.clamp(0.25, 1.0);
    final double glyphSize = coloredRadius * effectiveIconRatio;

    final TextPainter tp = TextPainter(textDirection: ui.TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        package: icon.fontPackage,
        fontSize: glyphSize,
        color: Colors.white,
        height: 1.0,
        fontWeight: FontWeight.w500,
      ),
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    // finalize to PNG bytes
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(imgSize, imgSize);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
