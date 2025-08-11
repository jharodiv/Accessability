import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHandler {
  Future<Set<Marker>> createMarkers(
    List<Map<String, dynamic>> locations,
    LatLng? userLocation, // Make parameter nullable
  ) async {
    final customIcon = await getCustomIcon();
    return locations.map((location) {
      // Calculate distance if user location is available
      String distanceText = '';
      if (userLocation != null) {
        final distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          location["latitude"],
          location["longitude"],
        );
        distanceText = '${distance.toStringAsFixed(1)} km';
      }

      return Marker(
        markerId: MarkerId("pwd_${location["name"]}"),
        position: LatLng(location["latitude"], location["longitude"]),
        infoWindow: InfoWindow(
          title: location["name"],
          snippet: distanceText.isNotEmpty ? distanceText : location["details"],
        ),
        icon: customIcon,
      );
    }).toSet();
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
      final LatLng center = LatLng(location["latitude"], location["longitude"]);
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
