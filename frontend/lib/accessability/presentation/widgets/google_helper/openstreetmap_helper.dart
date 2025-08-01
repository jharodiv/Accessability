import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class OpenStreetMapHelper {
  static DateTime? _lastRequestTime;
  static final Map<String, Place> _placeCache = {};
  static final Map<String, String?> _photoCache = {};

  Future<Place> fetchPlaceDetails(
      double lat, double lng, String fallbackName) async {
    final cacheKey = '${lat}_${lng}';

    if (_placeCache.containsKey(cacheKey)) {
      return _placeCache[cacheKey]!;
    }

    await _enforceRateLimit();

    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1'),
        headers: {'User-Agent': 'YourAppName/1.0 (your@email.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final photoUrl = await _getMapillaryPhoto(lat, lng);

        final place = Place(
          id: '',
          userId: '',
          osmId: data['osm_id']?.toString() ?? '',
          name: data['name'] ??
              data['address']?['building'] ??
              data['address']?['amenity'] ??
              fallbackName,
          rating: null,
          reviewsCount: null,
          address: _getFormattedAddress(data), // Updated address formatting
          imageUrl: photoUrl,
          category: data['type'] ?? '',
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
        );

        _placeCache[cacheKey] = place;
        return place;
      } else {
        throw Exception(
            'Failed to fetch place details: ${response.statusCode}');
      }
    } catch (e) {
      return Place(
        id: '',
        userId: '',
        osmId: '',
        name: fallbackName,
        rating: null,
        reviewsCount: null,
        address: _getFallbackAddress(lat, lng),
        imageUrl: null,
        category: '',
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Improved address formatting that works with OSM's jsonv2 format
  String _getFormattedAddress(Map<String, dynamic> data) {
    // First try display_name if available
    if (data['display_name'] != null) {
      return data['display_name'];
    }

    // Fall back to building address components
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return 'Address not available';

    // Build address from most specific to least specific components
    final components = [
      address['house_number'],
      address['road'],
      address['neighbourhood'],
      address['suburb'],
      address['city'] ?? address['town'] ?? address['village'],
      address['state'],
      address['postcode'],
      address['country']
    ].where((component) => component != null).toList();

    return components.isNotEmpty
        ? components.join(', ')
        : 'Near ${data['lat']?.toStringAsFixed(4)}, ${data['lon']?.toStringAsFixed(4)}';
  }

  /// Creates a more readable fallback address
  String _getFallbackAddress(double lat, double lng) {
    return 'Near ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < Duration(seconds: 1)) {
        final delay = Duration(seconds: 1) - timeSinceLastRequest;
        await Future.delayed(delay);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<String?> _getMapillaryPhoto(double lat, double lng) async {
    final cacheKey = 'photo_${lat}_${lng}';

    if (_photoCache.containsKey(cacheKey)) {
      return _photoCache[cacheKey];
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://graph.mapillary.com/images?fields=thumb_1024_url&lat=$lat&lng=$lng&radius=50'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final photoUrl = data['data'][0]['thumb_1024_url'];
          _photoCache[cacheKey] = photoUrl;
          return photoUrl;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
