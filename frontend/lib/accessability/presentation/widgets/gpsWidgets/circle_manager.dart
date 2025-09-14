// lib/presentation/screens/gpsscreen/circle_manager.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lightweight spec for nearby/provider circles (so we can rescale them later)
class NearbyCircleSpec {
  final String id;
  final LatLng center;
  final double baseRadius; // meters
  final int zIndex;
  final bool visible;

  NearbyCircleSpec({
    required this.id,
    required this.center,
    required this.baseRadius,
    this.zIndex = 30,
    this.visible = true,
  });

  NearbyCircleSpec copyWith({double? baseRadius}) {
    return NearbyCircleSpec(
      id: id,
      center: center,
      baseRadius: baseRadius ?? this.baseRadius,
      zIndex: zIndex,
      visible: visible,
    );
  }
}

typedef CircleTapCallback = void Function(LatLng center, double suggestedZoom);

class CircleManager {
  /// Create PWD circles (same logic you had). Provide onTap callback so
  /// caller can animate the camera using its own map controller.
  // inside CircleManager (replace the existing function)
  static Set<Circle> createPwdfriendlyRouteCircles({
    required List<dynamic> pwdLocations,
    required double currentZoom,
    required double pwdBaseRadiusMeters,
    required double pwdRadiusMultiplier,
    required Color pwdCircleColor,
    required CircleTapCallback onTap,
  }) {
    final Set<Circle> circles = {};

    int _strokeWidthForZoom(double zoom) {
      final int w = ((zoom - 12) * 0.6).round();
      return w.clamp(1, 8);
    }

    const double minPixelRadius = 16.0;
    const double preferredPixelRadius = 28.0;
    const double absoluteMinMeters = 4.0;

    for (final loc in pwdLocations) {
      final double lat = _parseDouble(loc['latitude']);
      final double lng = _parseDouble(loc['longitude']);
      final double baseRadius = pwdBaseRadiusMeters;

      final double latRad = lat * (pi / 180.0);
      final double metersPerPixel =
          156543.03392 * cos(latRad) / pow(2.0, currentZoom);

      final double zoomAdaptiveMeters =
          _radiusForZoom(currentZoom, baseRadius) * pwdRadiusMultiplier;

      final double preferredMeters = preferredPixelRadius * metersPerPixel;
      final double minMetersFloor = minPixelRadius * metersPerPixel;

      double finalRadiusMeters = max(zoomAdaptiveMeters, preferredMeters);
      finalRadiusMeters =
          max(finalRadiusMeters, max(minMetersFloor, absoluteMinMeters));

      final int strokeWidth = _strokeWidthForZoom(currentZoom);

      const double fillOpacity = 0.45;
      const double strokeOpacity = 0.0;

      // Prefer place id if present (stable id used by your places path)
      String circleIdValue;
      if (loc != null && loc['id'] != null && loc['id'].toString().isNotEmpty) {
        circleIdValue = 'place_circle_${loc['id']}';
      } else if (loc != null &&
          loc['uid'] != null &&
          loc['uid'].toString().isNotEmpty) {
        circleIdValue = 'pwd_circle_${loc['uid']}';
      } else {
        circleIdValue =
            'pwd_circle_${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}';
      }

      circles.add(Circle(
        circleId: CircleId(circleIdValue),
        center: LatLng(lat, lng),
        radius: finalRadiusMeters,
        fillColor: pwdCircleColor.withOpacity(fillOpacity),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        zIndex: 200,
        visible: true,
        consumeTapEvents: true,
        onTap: () {
          onTap(LatLng(lat, lng), max(15.0, min(18.0, currentZoom + 1.6)));
        },
      ));
    }

    return circles;
  }

  /// Convert provider/raw incoming circles (Set<Circle>) to NearbyCircleSpec
  /// so caller can store lightweight specs for rescaling on zoom.
  static List<NearbyCircleSpec> specsFromRawCircles(
    Set<Circle> raw, {
    double inflateFactor = 1.0,
    double baseFallback = 30.0,
  }) {
    return raw.map((c) {
      final incomingBase =
          (c.radius != null && c.radius > 0) ? c.radius : baseFallback;
      final double inflatedBase =
          (incomingBase * inflateFactor).clamp(8.0, 3000.0);
      return NearbyCircleSpec(
        id: c.circleId.value,
        center: c.center,
        baseRadius: inflatedBase,
        zIndex: c.zIndex ?? 30,
        visible: c.visible,
      );
    }).toList();
  }

  /// Rescale nearby/provider specs for a given zoom and return Set<Circle>.
  static Set<Circle> computeNearbyCirclesFromSpecs({
    required List<NearbyCircleSpec> specs,
    required double currentZoom,
    required double pwdBaseRadiusMeters,
    required double pwdRadiusMultiplier,
    required Color pwdCircleColor,
    required CircleTapCallback onTap,
    double minPixelRadius = 12.0,
    double shrinkFactor = 1.0, // set to 1.0 to avoid shrinking
    double extraVisualBoost = 1.25, // boost to make circles more visible
  }) {
    final Set<Circle> circles = {};
    if (specs.isEmpty) return circles;

    for (final spec in specs) {
      final LatLng center = spec.center;
      final double baseRadius = spec.baseRadius;
      final int zIndex = spec.zIndex;
      final bool visible = spec.visible;
      final String id = spec.id;

      final double latRad = center.latitude * (pi / 180.0);
      final double metersPerPixel =
          156543.03392 * cos(latRad) / pow(2.0, currentZoom);

      // radius based on zoom + spec base
      final double zoomAdaptiveMeters =
          _radiusForZoom(currentZoom, baseRadius) * pwdRadiusMultiplier;

      // minimum allowed meters based on pixel floor
      final double minMetersFloor = minPixelRadius * metersPerPixel;

      // Combine them and prevent shrinking: choose the max baseline, then apply boosts.
      double candidateRadius = max(zoomAdaptiveMeters, minMetersFloor) *
          extraVisualBoost *
          shrinkFactor;

      // make sure radius never drops below zoomAdaptiveMeters (prevents shrink)
      final double finalRadius = max(candidateRadius, zoomAdaptiveMeters);

      circles.add(Circle(
        circleId: CircleId(id),
        center: center,
        radius: finalRadius,
        fillColor: pwdCircleColor.withOpacity(0.4), // 50% opacity
        // Remove outer ring:
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        zIndex: zIndex,
        visible: visible,
        consumeTapEvents: true,
        onTap: () {
          onTap(center, max(15.0, min(18.0, currentZoom + 1.6)));
        },
      ));
    }

    return circles;
  }

  // ---------- small helpers copied from original file ----------
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double _radiusForZoom(double zoom, double baseMeters) {
    // Compute original factor (2^(13 - zoom))
    final num factor = pow(2, 13.0 - zoom);

    // If zoom is high (>= 15) don't let factor shrink below 1.0,
    // so radius will not get smaller than baseMeters at those zooms.
    final num clampedFactor = (zoom >= 15.0) ? 1.0 : factor.clamp(0.25, 12.0);

    return max(8.0, baseMeters * clampedFactor);
  }
}
