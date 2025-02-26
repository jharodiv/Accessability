import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? ''; // Instance member
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  // Method to get address from latlng (non-static)
  Future<String> getAddressFromLatLng(LatLng latLng) async {
    final url = '$_geocodingBaseUrl?latlng=${latLng.latitude},${latLng.longitude}&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Extract the formatted address from the response
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            return results[0]['formatted_address'];
          }
        } else {
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to load address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch address: $e');
    }

    return 'Address not found';
  }
}