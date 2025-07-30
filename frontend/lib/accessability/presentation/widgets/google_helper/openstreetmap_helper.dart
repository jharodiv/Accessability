import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenStreetMapHelper {
  /// Fetch place details from OpenStreetMap's Nominatim API
  Future<Place> fetchPlaceDetails(
      double lat, double lng, String fallbackName) async {
    final response = await http.get(
      Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Try to get a photo from Mapillary (optional)
      final photoUrl = await _getMapillaryPhoto(lat, lng);

      return Place(
        id: '',
        userId: '',
        osmId: data['osm_id']?.toString() ?? '',
        name: data['display_name']?.split(',').first ?? fallbackName,
        rating: null, // OSM doesn't provide ratings
        reviewsCount: null,
        address: data['display_name'] ?? 'Address not available',
        imageUrl: photoUrl,
        category: data['type'] ?? '',
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
      );
    } else {
      throw Exception('Failed to fetch place details: ${response.statusCode}');
    }
  }

  /// Get a street-level photo from Mapillary (free tier)
  Future<String?> _getMapillaryPhoto(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://graph.mapillary.com/images?fields=thumb_1024_url&lat=$lat&lng=$lng&radius=50'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0]['thumb_1024_url'];
        }
      }
      return null;
    } catch (e) {
      return null; // Silently fail if no photo available
    }
  }
}
