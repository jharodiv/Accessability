// lib/presentation/widgets/reusableWidgets/favorite_map_marker.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FavoriteMapMarker {
  static final Map<String, BitmapDescriptor> _cache = {};
  static void clearCache() => _cache.clear();

  static Future<BitmapDescriptor> toBitmapDescriptor(
    BuildContext ctx, {
    required String cacheKey,
    double pixelRatio = 0, // 0 -> device DPR
    double size = 72, // restored logical dp outer badge
    Color outerColor = const Color(0xFF6750A4),
    Color outerStrokeColor = const Color(0xFF5A3BD6),
    double outerOpacity = 0.55,
    Color innerBgColor = Colors.white,
    Color iconColor = const Color(0xFF6750A4),
    IconData icon = Icons.place,
    double iconSize = 52.0, // reduced icon size
    double innerCircleRatio = 0.46, // make white background smaller
    double innerPaddingFactor = 0.01, // keep tight inner padding
    double iconInnerPaddingFactor =
        0.08, // modest breathing space so icon is smaller
  }) async {
    final devicePR = MediaQuery.of(ctx).devicePixelRatio;
    final effectivePR = (pixelRatio <= 0) ? devicePR : pixelRatio;

    final realKey =
        '${cacheKey}_s${size}_o${outerColor.value}_os${outerStrokeColor.value}_op${(outerOpacity * 100).toInt()}_in${innerBgColor.value}_ic${iconColor.value}_i${icon.codePoint}_isz${iconSize}_pr${effectivePR.toStringAsFixed(2)}_r${innerCircleRatio}_pad${innerPaddingFactor}_ipad${iconInnerPaddingFactor}';

    if (_cache.containsKey(realKey)) return _cache[realKey]!;

    try {
      final desc = await _createMarkerBitmap(
        ctx: ctx,
        size: size.toInt(),
        pixelRatio: effectivePR,
        outerColor: outerColor,
        outerStrokeColor: outerStrokeColor,
        outerOpacity: outerOpacity,
        innerBgColor: innerBgColor,
        iconColor: iconColor,
        icon: icon,
        logicalIconSize: iconSize,
        innerCircleRatio: innerCircleRatio,
        innerPaddingFactor: innerPaddingFactor,
        iconInnerPaddingFactor: iconInnerPaddingFactor,
      );
      _cache[realKey] = desc;
      return desc;
    } catch (e, st) {
      debugPrint('FavoriteMapMarker.toBitmapDescriptor error: $e\n$st');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  static Future<BitmapDescriptor> _createMarkerBitmap({
    required BuildContext ctx,
    int size = 96,
    double pixelRatio = 3.0,
    Color outerColor = const Color(0xFF6750A4),
    Color outerStrokeColor = const Color(0xFF5A3BD6),
    double outerOpacity = 0.55,
    Color innerBgColor = Colors.white,
    Color iconColor = const Color(0xFF6750A4),
    IconData icon = Icons.place,
    double logicalIconSize = 52.0,
    double innerCircleRatio = 0.46,
    double innerPaddingFactor = 0.01,
    double iconInnerPaddingFactor = 0.08,
  }) async {
    final int canvasSize = (size * pixelRatio).toInt().clamp(1, 4096);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    final double centerX = canvasSize / 2.0;
    // restored headRadius multiplier to previous comfortable size
    final double headRadius = canvasSize * 0.36;
    final double centerY = canvasSize / 2.0;
    final Offset center = Offset(centerX, centerY);

    // shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pixelRatio * 1.2);
    final double shadowOffset = pixelRatio * 0.8;
    canvas.drawCircle(
      Offset(centerX + shadowOffset, centerY + shadowOffset),
      headRadius * 0.95,
      shadowPaint,
    );

    // outer fill
    paint
      ..style = PaintingStyle.fill
      ..color = outerColor.withOpacity(outerOpacity);
    canvas.drawCircle(center, headRadius, paint);

    // outer stroke
    final double strokeFactor = 0.07;
    final double strokeFloor = 0.12;
    final double outerStrokeW =
        math.max(strokeFloor, pixelRatio * strokeFactor);
    final Paint outerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeW
      ..color = outerStrokeColor.withOpacity(0.42)
      ..isAntiAlias = true;
    canvas.drawCircle(
      center,
      headRadius - (outerStroke.strokeWidth / 2.0),
      outerStroke,
    );

    // inner circle (white background) — smaller and tighter to icon
    final double innerRadiusRaw = headRadius * innerCircleRatio;
    final double innerPadding = headRadius * innerPaddingFactor;
    final double innerRadius =
        (innerRadiusRaw - innerPadding).clamp(0.0, headRadius);

    final double innerYOffset = -headRadius * 0.04;
    final Offset innerCenter = Offset(center.dx, center.dy + innerYOffset);

    final Paint innerBgPaint = Paint()..color = innerBgColor;
    canvas.drawCircle(innerCenter, innerRadius, innerBgPaint);

    // inner stroke
    final double innerStrokeW = math.max(0.18, pixelRatio * 0.06);
    final Paint innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStrokeW
      ..color = Colors.black.withOpacity(0.055);
    canvas.drawCircle(innerCenter,
        innerRadius - (innerStroke.strokeWidth / 2.0), innerStroke);

    // glossy highlight
    final Paint gloss = Paint()
      ..shader = ui.Gradient.radial(
        innerCenter.translate(-innerRadius * 0.22, -innerRadius * 0.22),
        innerRadius * 0.9,
        [Colors.white.withOpacity(0.18), Colors.transparent],
      )
      ..isAntiAlias = true;
    canvas.drawCircle(innerCenter, innerRadius, gloss);

    // glyph sizing
    final double requestedGlyphSize = logicalIconSize * pixelRatio;
    final double maxGlyph = innerRadius * (1.0 - iconInnerPaddingFactor);

    // more conservative overflow so icon stays smaller
    final double overflowFactor = 1.10;
    final double glyphSizeUnclamped =
        math.min(requestedGlyphSize, maxGlyph * overflowFactor);

    // safety: don't let glyph exceed the canvas by too much
    final double maxCanvasGlyph = canvasSize * 0.95;
    final double glyphSize = math.min(glyphSizeUnclamped, maxCanvasGlyph);

    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        package: icon.fontPackage,
        fontSize: glyphSize,
        color: iconColor,
        height: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
    tp.layout();

    final double glyphOffsetY = glyphSize * 0.02;
    tp.paint(
      canvas,
      innerCenter -
          Offset(tp.width / 2, tp.height / 2) -
          Offset(0, glyphOffsetY),
    );

    final ui.Image img =
        await recorder.endRecording().toImage(canvasSize, canvasSize);
    final ByteData? bytes =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('Failed to create marker bytes');
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }
}
