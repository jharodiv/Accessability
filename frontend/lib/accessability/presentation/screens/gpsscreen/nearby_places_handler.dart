import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NearbyPlacesHandler {
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? '';

  Future<Map<String, dynamic>> fetchNearbyPlaces(String placeType, LatLng currentLocation) async {
  if (currentLocation == null) return {};

  // Determine the type, color, and icon path based on the placeType
  String type;
  Color color;
  String iconPath;

  switch (placeType) {
    case 'Hotel':
      type = 'lodging';
      color = Colors.pink;
      iconPath = 'assets/images/others/hotel.png';
      break;
    case 'Restaurant':
      type = 'restaurant';
      color = Colors.blue;
      iconPath = 'assets/images/others/restaurant.png';
      break;
    case 'Bus':
      type = 'bus_station';
      color = Colors.blue;
      iconPath = 'assets/images/others/bus-school.png';
      break;
    case 'Shopping':
      type = 'shopping_mall';
      color = Colors.yellow;
      iconPath = 'assets/images/others/shopping-mall.png';
      break;
    case 'Groceries':
      type = 'grocery_or_supermarket';
      color = Colors.orange;
      iconPath = 'assets/images/others/grocery.png';
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

    for (var place in places) {
      final lat = place["geometry"]["location"]["lat"];
      final lng = place["geometry"]["location"]["lng"];
      final name = place["name"];
      final position = LatLng(lat, lng);

      // Load custom icon
      final BitmapDescriptor icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(24, 24)),
        iconPath,
      );

      // Add Marker with custom icon
      nearbyMarkers.add(
        Marker(
          markerId: MarkerId(name),
          position: position,
          infoWindow: InfoWindow(title: name),
          icon: icon,
        ),
      );

      // Add Circle with custom color
      nearbyCircles.add(
        Circle(
          circleId: CircleId(name),
          center: position,
          radius: 30, // Adjust size as needed
          strokeWidth: 2,
          strokeColor: color,
          fillColor: color.withOpacity(0.5),
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