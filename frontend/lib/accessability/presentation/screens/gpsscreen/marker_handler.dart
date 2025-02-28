import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHandler {
  Set<Marker> markers = {};

   Future<Set<Marker>> createMarkers(List<Map<String, dynamic>> pwdFriendlyLocations) async {
    final customIcon = await getCustomIcon();
    return pwdFriendlyLocations.map((location) {
      return Marker(
        markerId: MarkerId("pwd_${location["name"]}"),
        position: LatLng(location["latitude"], location["longitude"]),
        infoWindow: InfoWindow(
          title: location["name"],
          snippet: location["details"],
        ),
        icon: customIcon,
      );
    }).toSet();
  }

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
      points.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
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