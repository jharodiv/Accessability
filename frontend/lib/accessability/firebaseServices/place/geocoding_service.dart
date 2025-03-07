import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? ''; // Instance member
  static const String _geocodingBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  static const String _placesAutocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  // Method to get address from latlng (non-static)
  Future<String> getAddressFromLatLng(LatLng latLng) async {
    final url =
        '$_geocodingBaseUrl?latlng=${latLng.latitude},${latLng.longitude}&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Extract the formatted address from the response
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final address = results[0]['formatted_address'];

            // Remove the Plus Code from the address (if present)
            return _removePlusCode(address);
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

   Future<List<String>> getAutocompleteSuggestions(String query) async {
    final url = '$_placesAutocompleteUrl?input=$query&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((prediction) => prediction['description'] as String)
              .toList();
        } else {
          throw Exception('Places API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to load suggestions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch suggestions: $e');
    }
  }

  // Method to search for locations based on a query
  Future<List<GeocodingResult>> searchLocation(String query) async {
    final url = '$_geocodingBaseUrl?address=$query&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((result) => GeocodingResult.fromJson(result))
              .toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          throw Exception('No results found for "$query". Please try a different search.');
        } else {
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to load location: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch location: $e');
    }
  }

  // Method to remove Plus Code from the address
  String _removePlusCode(String address) {
    // Split the address by commas
    final parts = address.split(',');

    // Remove any part that contains a Plus Code (e.g., "255H+R5")
    final filteredParts =
        parts.where((part) => !_isPlusCode(part.trim())).toList();

    // Join the remaining parts to form the cleaned address
    return filteredParts.join(',').trim();
  }

  // Method to check if a string is a Plus Code
  bool _isPlusCode(String part) {
    // A Plus Code typically contains a "+" and is 6-10 characters long
    return part.contains('+') && part.length <= 10;
  }
}

// Class to represent a Geocoding result
class GeocodingResult {
  final String formattedAddress;
  final Geometry geometry;

  GeocodingResult({required this.formattedAddress, required this.geometry});

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      formattedAddress: json['formatted_address'],
      geometry: Geometry.fromJson(json['geometry']),
    );
  }
}

// Class to represent the geometry of a location
class Geometry {
  final Location location;

  Geometry({required this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) {
    return Geometry(
      location: Location.fromJson(json['location']),
    );
  }
}

// Class to represent the location (latitude and longitude)
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: json['lat'],
      lng: json['lng'],
    );
  }
}