import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OpenStreetMapGeocodingService {
  // Base URLs for OpenStreetMap Nominatim API
  static const String _reverseGeocodingUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const String _searchUrl = 'https://nominatim.openstreetmap.org/search';

  // User agent required by OpenStreetMap usage policy
  final String _userAgent =
      'AccessAbility/1.0 (your@email.com)'; // REPLACE WITH YOUR INFO

  // Method to get address from latlng (reverse geocoding)
  Future<String> getAddressFromLatLng(LatLng latLng) async {
    final url =
        '$_reverseGeocodingUrl?format=jsonv2&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _extractFormattedAddress(data);
      } else {
        throw Exception('Failed to load address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch address: $e');
    }
  }

  // Method to search for locations based on a query (forward geocoding)
  Future<List<GeocodingResult>> searchLocation(String query) async {
    final url = '$_searchUrl?format=jsonv2&q=$query&addressdetails=1&limit=5';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => GeocodingResult.fromOpenStreetMap(item))
            .toList();
      } else if (response.statusCode == 404) {
        throw Exception(
            'No results found for "$query". Please try a different search.');
      } else {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch location: $e');
    }
  }

  // Note: OpenStreetMap doesn't have a direct autocomplete equivalent
  // You would need to implement this using search with debouncing
  Future<List<String>> getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final results = await searchLocation(query);
      return results.map((result) => result.formattedAddress).toList();
    } catch (e) {
      throw Exception('Failed to fetch suggestions: $e');
    }
  }

  // Helper method to extract formatted address from OSM response
  String _extractFormattedAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return 'Address not found';

    // Build address from available components
    final components = [
      address['house_number'],
      address['road'],
      address['neighbourhood'],
      address['suburb'],
      address['city'] ?? address['town'] ?? address['village'],
      address['state'],
      address['postcode'],
      address['country'],
    ].where((component) => component != null).toList();

    return components.join(', ');
  }
}

// Updated GeocodingResult class to handle OpenStreetMap data structure
class GeocodingResult {
  final String formattedAddress;
  final Geometry geometry;

  GeocodingResult({required this.formattedAddress, required this.geometry});

  factory GeocodingResult.fromOpenStreetMap(Map<String, dynamic> json) {
    return GeocodingResult(
      formattedAddress: _formatOsmAddress(json),
      geometry: Geometry(
        location: Location(
          lat: double.parse(json['lat']),
          lng: double.parse(json['lon']),
        ),
      ),
    );
  }

  static String _formatOsmAddress(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String?;
    if (displayName != null) return displayName;

    final address = json['address'] as Map<String, dynamic>?;
    if (address == null) return 'Unnamed location';

    return [
      address['road'],
      address['city'] ?? address['town'] ?? address['village'],
      address['country'],
    ].where((part) => part != null).join(', ');
  }
}

// Geometry and Location classes remain the same
class Geometry {
  final Location location;

  Geometry({required this.location});
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});
}
