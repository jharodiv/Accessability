import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NearbyPlacesHandler {
  // List of available free OSM servers
  final List<String> _overpassServers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter'
  ];

  /// Creates custom marker icons with proper error handling
  Future<BitmapDescriptor> _createMarkerIcon(
    Color backgroundColor,
    IconData iconData, {
    int size = 80,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final radius = size / 2;

      // Draw background
      canvas.drawCircle(
        Offset(radius, radius),
        radius,
        Paint()..color = backgroundColor,
      );

      // Draw icon
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: size * 0.5,
          fontFamily: iconData.fontFamily,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
      );

      final image = await recorder.endRecording().toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      if (bytes == null) throw Exception('Failed to convert image to bytes');

      return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    } catch (e) {
      print('Error creating marker icon: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  /// Main method to fetch nearby places
  Future<Map<String, dynamic>> fetchNearbyPlaces(
    String placeType,
    LatLng location,
  ) async {
    const Color markerColor = Color(0xFF6750A4);
    final (osmTag, iconData) = _getOsmConfig(placeType);

    if (osmTag == null) return {};

    try {
      final result = await _queryOverpass(osmTag, location);
      final icon = await _createMarkerIcon(markerColor, iconData);

      final markers = <Marker>[];
      final circles = <Circle>[];

      for (final element in result['elements'] ?? []) {
        final (lat, lng, name) = _extractElementData(element);
        if (lat == null || lng == null) continue;

        final markerId = '${element['type']}${element['id']}';
        markers.add(Marker(
          markerId: MarkerId(markerId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: name ?? placeType),
          icon: icon,
        ));

        circles.add(Circle(
          circleId: CircleId(markerId),
          center: LatLng(lat, lng),
          radius: 30,
          strokeColor: markerColor,
          fillColor: markerColor.withOpacity(0.3),
        ));
      }

      return {
        'markers': markers,
        'circles': circles,
        'source': 'overpass',
      };
    } catch (e) {
      print('Failed to fetch places: $e');
      return {};
    }
  }

  /// Query Overpass API with retry logic
  Future<Map<String, dynamic>> _queryOverpass(
      String osmTag, LatLng location) async {
    final query = '''
      [out:json][timeout:25];
      (
        node[$osmTag](around:1500,${location.latitude},${location.longitude});
        way[$osmTag](around:1500,${location.latitude},${location.longitude});
      );
      out center;
    ''';

    for (final server in _overpassServers) {
      try {
        final response = await http.post(
          Uri.parse(server),
          body: {'data': query},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
      } catch (e) {
        print('Failed to query $server: $e');
      }
    }
    throw Exception('All Overpass servers failed');
  }

  /// Extract data from OSM elements
  (double?, double?, String?) _extractElementData(dynamic element) {
    try {
      double? lat, lng;
      String? name;

      if (element['type'] == 'node') {
        lat = element['lat']?.toDouble();
        lng = element['lon']?.toDouble();
      } else if (element['center'] != null) {
        lat = element['center']['lat']?.toDouble();
        lng = element['center']['lon']?.toDouble();
      }

      name = element['tags']?['name'] ?? 'Unnamed Place';
      return (lat, lng, name);
    } catch (e) {
      print('Error parsing element: $e');
      return (null, null, null);
    }
  }

  /// Map place types to OSM tags
  (String?, IconData) _getOsmConfig(String placeType) {
    return switch (placeType) {
      'Hotel' => ('tourism=hotel', Icons.hotel),
      'Restaurant' => ('amenity=restaurant', Icons.restaurant),
      'Bus' => ('amenity=bus_station', Icons.directions_bus),
      'Shopping' => ('shop=mall', Icons.shopping_bag),
      'Groceries' => ('shop=supermarket', Icons.local_grocery_store),
      _ => (null, Icons.place),
    };
  }
}
