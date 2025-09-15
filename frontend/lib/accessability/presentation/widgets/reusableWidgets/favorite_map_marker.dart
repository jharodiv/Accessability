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
    double size = 72, // logical dp outer badge
    Color outerColor = const Color(0xFF7C4DFF), // purple outer ring
    Color outerStrokeColor = const Color(0xFF7C4DFF),
    double outerOpacity = 1.0,
    Color innerBgColor = Colors.white, // inner background and pointer
    Color iconColor = const Color(0xFF7C4DFF),
    IconData icon = Icons.place,
    double iconSize = 52.0, // logical icon size
    double innerCircleRatio = 0.56,
    double innerPaddingFactor = 0.02, // <--- this was missing earlier
    double iconInnerPaddingFactor = 0.12,
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

  // The updated marker bitmap generator. Pointer is filled by innerBgColor (white)
  // and a subtle purple stroke around the pointer is drawn for crispness.
  static Future<BitmapDescriptor> _createMarkerBitmap({
    required BuildContext ctx,
    int size = 96,
    double pixelRatio = 3.0,
    Color outerColor = const Color(0xFF7C4DFF),
    Color outerStrokeColor = const Color(0xFF7C4DFF),
    double outerOpacity = 1.0,
    Color innerBgColor = Colors.white,
    Color iconColor = const Color(0xFF7C4DFF),
    IconData icon = Icons.place,
    double logicalIconSize = 52.0,
    double innerCircleRatio = 0.56,
    double innerPaddingFactor = 0.02,
    double iconInnerPaddingFactor = 0.12,
  }) async {
    final int canvasSize = (size * pixelRatio).toInt().clamp(1, 4096);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    final double centerX = canvasSize / 2.0;
    // lift center so pointer and shadow fit nicely
    final double centerY = canvasSize * 0.34;
    final Offset center = Offset(centerX, centerY);

    final double headRadius = canvasSize * 0.30;

    // ---------- floating shadow ----------
    final double ellipseWidth = headRadius * 1.7;
    final double ellipseHeight = headRadius * 0.42;
    final Offset ellipseCenter =
        Offset(centerX, centerY + headRadius * 0.95); // under badge
    final Rect ovalRect = Rect.fromCenter(
        center: ellipseCenter, width: ellipseWidth, height: ellipseHeight);
    final Paint ovalPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pixelRatio * 2.2);
    canvas.drawOval(ovalRect, ovalPaint);

    // subtle circular shadow towards marker
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pixelRatio * 1.0);
    canvas.drawCircle(
      Offset(centerX + pixelRatio * 0.6, centerY + pixelRatio * 0.6),
      headRadius * 0.92,
      shadowPaint,
    );

    // ---------- outer purple circle ----------
    paint
      ..style = PaintingStyle.fill
      ..color = outerColor.withOpacity(outerOpacity);
    canvas.drawCircle(center, headRadius, paint);

    // subtle outer stroke to make edge crisp
    final double outerStrokeW = math.max(0.12, pixelRatio * 0.06);
    final Paint outerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeW
      ..color = outerStrokeColor.withOpacity(0.28)
      ..isAntiAlias = true;
    canvas.drawCircle(
      center,
      headRadius - (outerStroke.strokeWidth / 2.0),
      outerStroke,
    );

    // ---------- inner white circle ----------
    final double coloredRadius = headRadius * innerCircleRatio;
    final double innerPadding = headRadius * innerPaddingFactor;
    final double innerRadius =
        (coloredRadius - innerPadding).clamp(0.0, headRadius);
    // slight lift so pointer connects naturally
    final Offset innerCenter = Offset(center.dx, center.dy - headRadius * 0.02);

    final Paint innerBgPaint = Paint()..color = innerBgColor;
    canvas.drawCircle(innerCenter, innerRadius, innerBgPaint);

    // small inner stroke for separation
    final double innerStrokeW = math.max(0.12, pixelRatio * 0.05);
    final Paint innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStrokeW
      ..color = Colors.black.withOpacity(0.06)
      ..isAntiAlias = true;
    canvas.drawCircle(
        innerCenter, innerRadius - (innerStrokeW / 2.0), innerStroke);

    // glossy highlight
    final Paint gloss = Paint()
      ..shader = ui.Gradient.radial(
        innerCenter.translate(-innerRadius * 0.22, -innerRadius * 0.22),
        innerRadius * 0.9,
        [Colors.white.withOpacity(0.18), Colors.transparent],
      )
      ..isAntiAlias = true;
    canvas.drawCircle(innerCenter, innerRadius, gloss);

    // ---------- pointer (triangle) filled with innerBgColor (white) ----------
    final double pointerLengthFactor = 0.18;
    final double pointerWidthFactor = 0.45;
    final double pointerOverlap = 0.02; // slight overlap so it reads connected
    final double pointerTopY =
        innerCenter.dy + innerRadius - (innerRadius * pointerOverlap);
    final double pointerBottomY =
        pointerTopY + headRadius * pointerLengthFactor;
    final double pointerHalfWidth = headRadius * pointerWidthFactor;

    final Path pointer = Path();
    final double cx = center.dx;
    pointer.moveTo(cx + pointerHalfWidth, pointerTopY);
    pointer.lineTo(cx, pointerBottomY);
    pointer.lineTo(cx - pointerHalfWidth, pointerTopY);
    pointer.close();

    // fill pointer with inner background color (white)
    final Paint pointerPaint = Paint()..color = innerBgColor;
    canvas.drawPath(pointer, pointerPaint);

    // subtle purple edge around pointer for crispness
    final Paint pointerEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, pixelRatio * 0.32)
      ..color = outerColor.withOpacity(0.22)
      ..isAntiAlias = true;
    canvas.drawPath(pointer, pointerEdge);

    // tiny soft shadow under pointer tip for depth
    final Path pointerShadow = Path.from(pointer);
    final Paint pointerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pixelRatio * 0.8)
      ..style = PaintingStyle.fill;
    final Matrix4 m = Matrix4.identity()..translate(0.0, pixelRatio * 0.6);
    pointerShadow.transform(m.storage);
    canvas.drawPath(pointerShadow, pointerShadowPaint);

    // ---------- glyph (icon) centered in inner white circle ----------
    final double requestedGlyphSize = logicalIconSize * pixelRatio;
    final double maxGlyph = innerRadius * (1.0 - iconInnerPaddingFactor);
    final double overflowFactor = 1.06;
    final double glyphSizeUnclamped =
        math.min(requestedGlyphSize, maxGlyph * overflowFactor);
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

    final double glyphYOffset = glyphSize * 0.02;
    tp.paint(
        canvas,
        innerCenter -
            Offset(tp.width / 2, tp.height / 2) -
            Offset(0, glyphYOffset));

    // finalize and return BitmapDescriptor
    final ui.Image img =
        await recorder.endRecording().toImage(canvasSize, canvasSize);
    final ByteData? bytes =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('Failed to create marker bytes');
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }
}
