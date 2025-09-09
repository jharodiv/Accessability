// lib/accessability/presentation/screens/gpsscreen/marker_handler.dart
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:accessability/accessability/utils/badge_icon.dart';

class MarkerHandler {
  // Cache so we don't recreate the same BitmapDescriptor repeatedly.
  static BitmapDescriptor? _cachedAssetIcon;
  static BitmapDescriptor? _cachedFallbackIcon;

  /// Main entry: now requires BuildContext so we can generate asset or canvas icons.
  Future<Set<Marker>> createMarkers(
    BuildContext ctx,
    List<Map<String, dynamic>> locations,
    LatLng? userLocation,
  ) async {
    final customIcon = await _loadPwdIcon(ctx);

    return locations.map((location) {
      final double latitude = _parseDouble(location["latitude"]);
      final double longitude = _parseDouble(location["longitude"]);

      // distance snippet
      String distanceText = '';
      if (userLocation != null) {
        final distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          latitude,
          longitude,
        );
        distanceText = '${distance.toStringAsFixed(1)} km';
      }

      // safe marker id
      final rawName = (location['name']?.toString() ?? 'unknown');
      final safeName = rawName.replaceAll(RegExp(r'\s+'), '_');

      return Marker(
        markerId: MarkerId('pwd_$safeName'),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: location['name']?.toString() ?? 'Unnamed',
          snippet: distanceText.isNotEmpty
              ? distanceText
              : (location['details']?.toString() ?? ''),
        ),
        icon: customIcon,
        // Anchor the icon center (0.5, 0.5). If you want the "tip" to point at the location, change y to 1.0.
        anchor: const Offset(0.5, 0.5),
        zIndex: 100,
      );
    }).toSet();
  }

  // --- Icon loader: prefer asset, composite white circle behind it, fallback to BadgeIcon ---
  Future<BitmapDescriptor> _loadPwdIcon(BuildContext ctx) async {
    if (_cachedAssetIcon != null) return _cachedAssetIcon!;

    try {
      final double devicePixelRatio = MediaQuery.of(ctx).devicePixelRatio;

      // Slightly bigger than before
      const double logicalSize = 46.0;
      final int pxSize = (logicalSize * devicePixelRatio).round();

      // Load asset (expected to have transparent background)
      final ByteData data =
          await rootBundle.load('assets/images/others/accessabilitylogo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image assetImage = frameInfo.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint()..isAntiAlias = true;

      // Lift the head a bit to leave room for the pointer
      final Offset center = Offset(pxSize / 2.0, pxSize * 0.30);

      // Outer white circle (background) — slightly bigger
      final double headRadius = pxSize * 0.31;
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white;
      canvas.drawCircle(center, headRadius, paint);

      // subtle stroke for the white circle
      final Paint strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, devicePixelRatio * 0.8)
        ..color = Colors.black.withOpacity(0.06)
        ..isAntiAlias = true;
      canvas.drawCircle(
          center, headRadius - devicePixelRatio * 0.5, strokePaint);

      // Pointer (tail) tuning — slightly larger to match bigger head
      final double pointerLengthFactor = 0.17; // a bit longer
      final double pointerWidthFactor = 0.48; // a bit wider
      final double pointerOverlap = 0.03; // slight overlap into head

      final double pointerTopY =
          center.dy + headRadius - (headRadius * pointerOverlap);
      final double pointerBottomY =
          pointerTopY + headRadius * pointerLengthFactor;
      final double pointerHalfWidth = headRadius * pointerWidthFactor;
      final double cx = center.dx;

      final Path pointer = Path();
      pointer.moveTo(cx + pointerHalfWidth, pointerTopY);
      pointer.lineTo(cx, pointerBottomY);
      pointer.lineTo(cx - pointerHalfWidth, pointerTopY);
      pointer.close();

      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white;
      canvas.drawPath(pointer, paint);

      // pointer edge for subtle contrast
      final Paint pointerEdge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, devicePixelRatio * 0.45)
        ..color = Colors.black.withOpacity(0.06)
        ..isAntiAlias = true;
      canvas.drawPath(pointer, pointerEdge);

      // Draw the asset on top, centered within the white circle (preserves PNG transparency)
      final double innerPadding =
          headRadius * 0.16; // padding inside white circle
      final Rect dstRect = Rect.fromLTWH(
        center.dx - headRadius + innerPadding,
        center.dy - headRadius + innerPadding,
        (headRadius * 2) - innerPadding * 2,
        (headRadius * 2) - innerPadding * 2,
      );
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        assetImage.width.toDouble(),
        assetImage.height.toDouble(),
      );
      final Paint imgPaint = Paint()..isAntiAlias = true;
      canvas.drawImageRect(assetImage, srcRect, dstRect, imgPaint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(pxSize, pxSize);
      final ByteData? pngBytes =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngUint8 = pngBytes!.buffer.asUint8List();

      _cachedAssetIcon = BitmapDescriptor.fromBytes(pngUint8);
      return _cachedAssetIcon!;
    } catch (e) {
      debugPrint(
          '[MarkerHandler] composite asset failed: $e — falling back to BadgeIcon');
      if (_cachedFallbackIcon != null) return _cachedFallbackIcon!;

      final fallback = await BadgeIcon.createBadgeWithIcon(
        ctx: ctx,
        size: 48, // larger fallback to match
        outerRingColor: Colors.white,
        innerBgColor: Colors.transparent,
        iconBgColor: const Color(0xFF7C4DFF),
        icon: Icons.accessible,
        outerRingWidthRatio: 0.05,
        innerRatio: 0.70,
        iconBgRatio: 0.36,
        iconRatio: 0.48,
      );

      _cachedFallbackIcon = fallback;
      return _cachedFallbackIcon!;
    }
  }

  // Add this helper method to safely parse doubles
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Set<Polygon> createPolygons(List<Map<String, dynamic>> pwdFriendlyLocations) {
    final Set<Polygon> polygons = {};
    for (var location in pwdFriendlyLocations) {
      // Convert string values to double
      final double latitude = _parseDouble(location["latitude"]);
      final double longitude = _parseDouble(location["longitude"]);

      final LatLng center = LatLng(latitude, longitude);
      final List<LatLng> points = [];
      for (double angle = 0; angle <= 360; angle += 10) {
        final double radians = angle * (3.141592653589793 / 180);
        final double latOffset = 0.0005 * cos(radians);
        final double lngOffset = 0.0005 * sin(radians);
        points.add(
            LatLng(center.latitude + latOffset, center.longitude + lngOffset));
      }
      polygons.add(
        Polygon(
          polygonId: PolygonId(location["name"]?.toString() ?? 'pwd_poly'),
          points: points,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.2),
          strokeWidth: 2,
        ),
      );
    }
    return polygons;
  }
}
