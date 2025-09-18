// lib/services/nearby_manager.dart
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/circle_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Wraps CircleManager usage and caches PWD locations / specs so gps_screen.dart
/// can remain a thin UI layer. Preserves the compute parameters you used previously.
class NearbyManager {
  NearbyManager();

  List<NearbyCircleSpec> _specs = [];
  List<dynamic> _cachedPwdLocations = [];

  /// Convert raw circles into specs (preserve the inflateFactor and fallback used previously).
  List<NearbyCircleSpec> specsFromRawCircles(Set<Circle> raw,
      {double inflateFactor = 1.0, double baseFallback = 30.0}) {
    _specs = CircleManager.specsFromRawCircles(raw,
        inflateFactor: inflateFactor, baseFallback: baseFallback);
    return _specs;
  }

  /// Compute rescaled circles from specs using the same tuning from your earlier file.
  Set<Circle> computeNearbyCirclesFromExternalSpecs({
    required List<NearbyCircleSpec> specs,
    required double currentZoom,
    double pwdBaseRadiusMeters = 30.0,
    double pwdRadiusMultiplier = 1.0,
    Color pwdCircleColor = const Color(0xFF7C4DFF),
    void Function(LatLng center, double suggestedZoom)? onTap,
    double minPixelRadius = 24.0,
    double shrinkFactor = 0.92,
    double extraVisualBoost = 1.15,
  }) {
    return CircleManager.computeNearbyCirclesFromSpecs(
      specs: specs,
      currentZoom: currentZoom,
      pwdBaseRadiusMeters: pwdBaseRadiusMeters,
      pwdRadiusMultiplier: pwdRadiusMultiplier,
      pwdCircleColor: pwdCircleColor,
      onTap: onTap ?? (center, zoom) {},
      minPixelRadius: minPixelRadius,
      shrinkFactor: shrinkFactor,
      extraVisualBoost: extraVisualBoost,
    );
  }

  /// Build PWD route circles for an array of location maps (expects the same structure as your original).
  Set<Circle> createPwdfriendlyRouteCircles(
    List<dynamic> pwdLocations, {
    required double currentZoom,
    double pwdBaseRadiusMeters = 30.0,
    double pwdRadiusMultiplier = 1.0,
    Color pwdCircleColor = const Color(0xFF7C4DFF),
    void Function(LatLng center, double suggestedZoom)? onTap,
  }) {
    // Cache the locations for later use (matching original behavior)
    _cachedPwdLocations = pwdLocations;

    return CircleManager.createPwdfriendlyRouteCircles(
      pwdLocations: pwdLocations,
      currentZoom: currentZoom,
      pwdBaseRadiusMeters: pwdBaseRadiusMeters,
      pwdRadiusMultiplier: pwdRadiusMultiplier,
      pwdCircleColor: pwdCircleColor,
      onTap: onTap ?? (center, zoom) {},
    );
  }

  void cachePwdLocations(List<dynamic> locations) {
    _cachedPwdLocations = locations;
  }

  List<dynamic> get cachedPwdLocations => _cachedPwdLocations;

  void clearSpecs() {
    _specs = [];
  }
}
