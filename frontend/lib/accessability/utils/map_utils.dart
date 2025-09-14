// lib/utils/map_utils.dart
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class MapUtils {
  /// Returns distance in kilometers (same units as your original implementation).
  static double calculateDistanceKm(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final lat1 = start.latitude * (pi / 180);
    final lon1 = start.longitude * (pi / 180);
    final lat2 = end.latitude * (pi / 180);
    final lon2 = end.longitude * (pi / 180);
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1) * cos(lat2) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Bearing in degrees (0..360) from start to end (same formula as original).
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);
    final y = sin(endLng - startLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);
    final bearing = atan2(y, x);
    return (bearing * (180 / pi) + 360) % 360;
  }

  static bool latLngEqual(LatLng a, LatLng b, {double eps = 1e-6}) =>
      (a.latitude - b.latitude).abs() <= eps &&
      (a.longitude - b.longitude).abs() <= eps;

  static bool pointsEqual(List<LatLng> a, List<LatLng> b, {double eps = 1e-6}) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!latLngEqual(a[i], b[i], eps: eps)) return false;
    }
    return true;
  }

  static Color colorForPlaceType(String? type) {
    final t = (type ?? '').toLowerCase();

    if (t.contains('bus')) return Colors.blue;

    if (t.contains('restaurant') || t.contains('restawran')) {
      return Colors.red;
    }

    if (t.contains('grocery') || t.contains('grocer')) {
      return Colors.green;
    }

    if (t.contains('hotel')) return Colors.teal;

    // 🛍️ Shopping
    if (t.contains('shop') ||
        t.contains('store') ||
        t.contains('pamimili') ||
        t.contains('shopping')) {
      return Colors.orange; // pick your shade (example: amber/orange)
    }

    // 🏥 Hospital
    if (t.contains('hospital') ||
        t.contains('ospital') ||
        t.contains('ospit')) {
      return Colors.redAccent; // brighter red for hospitals
    }

    // Default fallback (your old purple)
    return const Color(0xFF7C4DFF);
  }

  static double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
