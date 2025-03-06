import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NearbyPlacesHandler {
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? '';

  /// Creates a circular marker icon with a background color and a centered icon.
  Future<BitmapDescriptor> _getMarkerIconWithIcon(
    Color backgroundColor,
    IconData iconData, {
    int size = 80,
  }) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2;

    // Draw the background circle.
    final Paint circlePaint = Paint()..color = backgroundColor;
    canvas.drawCircle(Offset(radius, radius), radius, circlePaint);

    // Draw the icon in the center.
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5, // Adjust size as needed.
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final Offset iconOffset = Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<Map<String, dynamic>> fetchNearbyPlaces(
      String placeType, LatLng currentLocation) async {
    // Use the specified color for all markers and circles.
    const Color customColor = Color(0xFF6750A4);
    String type;
    IconData iconData;

    // Choose the Google Places type and corresponding icon.
    switch (placeType) {
      case 'Hotel':
        type = 'lodging';
        iconData = Icons.hotel;
        break;
      case 'Restaurant':
        type = 'restaurant';
        iconData = Icons.restaurant;
        break;
      case 'Bus':
        type = 'bus_station';
        iconData = Icons.directions_bus;
        break;
      case 'Shopping':
        type = 'shopping_mall';
        iconData = Icons.shopping_bag;
        break;
      case 'Groceries':
        type = 'grocery_or_supermarket';
        iconData = Icons.local_grocery_store;
        break;
      default:
        print("⚠️ Selected category is not recognized.");
        return {};
    }

    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
        "location=${currentLocation.latitude},${currentLocation.longitude}"
        "&radius=1500&type=$type&key=$_apiKey";

    print("🔵 Fetching nearby $placeType: $url");

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("🟢 API Response: ${data.toString()}");

      final List<dynamic> places = data["results"];
      final Set<Marker> nearbyMarkers = {};
      final Set<Circle> nearbyCircles = {};

      // Generate a custom marker icon using the built-in icon.
      final BitmapDescriptor customIcon =
          await _getMarkerIconWithIcon(customColor, iconData, size: 80);

      for (var place in places) {
        final lat = place["geometry"]["location"]["lat"];
        final lng = place["geometry"]["location"]["lng"];
        final String placeId = place["place_id"]; // Use the unique place_id
        final name = place["name"];
        final position = LatLng(lat, lng);

        // Add a Marker with the custom circular icon.
        nearbyMarkers.add(
          Marker(
            markerId: MarkerId(placeId), // Use place_id for uniqueness
            position: position,
            infoWindow: InfoWindow(title: name),
            icon: customIcon,
          ),
        );

        // Add a Circle overlay with the same color.
        nearbyCircles.add(
          Circle(
            circleId: CircleId(placeId),
            center: position,
            radius: 30, // Adjust radius as needed.
            strokeWidth: 2,
            strokeColor: customColor,
            fillColor: customColor.withOpacity(0.5),
          ),
        );

        print("📍 Added Marker & Circle for: $name at ($lat, $lng)");
      }

      return {
        "markers": nearbyMarkers,
        "circles": nearbyCircles,
      };
    } else {
      print("❌ HTTP Request Failed: ${response.statusCode}");
      return {};
    }
  }
}
