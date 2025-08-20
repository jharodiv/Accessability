import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHandler {
  Future<Set<Marker>> createMarkers(
    List<Map<String, dynamic>> locations,
    LatLng? userLocation,
  ) async {
    final customIcon = await getCustomIcon();
    return locations.map((location) {
      // Convert string values to double
      final double latitude = _parseDouble(location["latitude"]);
      final double longitude = _parseDouble(location["longitude"]);

      // Calculate distance if user location is available
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

      return Marker(
        markerId: MarkerId("pwd_${location["name"]}"),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: location["name"],
          snippet: distanceText.isNotEmpty ? distanceText : location["details"],
        ),
        icon: customIcon,
      );
    }).toSet();
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

  Future<BitmapDescriptor> getCustomIcon() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(24, 24)),
      'assets/images/others/accessabilitylogo.png',
    );
  }

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
          polygonId: PolygonId(location["name"]),
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
