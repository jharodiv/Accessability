import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_maps_webservices/places.dart';

class GooglePlacesHelper {
  final GoogleMapsPlaces _places;

  GooglePlacesHelper()
      : _places = GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_API_KEY']!);

  /// Fetch detailed info (rating, reviews count, address, photo, etc.)
  /// for a given placeId.
  Future<Place> fetchPlaceDetails(String placeId, String fallbackName) async {
    final response = await _places.getDetailsByPlaceId(placeId);

    if (response.status == 'OK' && response.result != null) {
      final result = response.result!;

      // Construct the photo URL (if any photos exist)
      String? photoUrl;
      if (result.photos != null && result.photos.isNotEmpty) {
        final photoReference = result.photos.first.photoReference;
        photoUrl = _buildPhotoUrl(photoReference);
      }

      return Place(
        id: '', // Placeholder, since Google details don't provide an id
        userId: '', // Placeholder if not available from Google
        placeId: placeId,
        name: result.name ?? fallbackName,
        rating: result.rating?.toDouble(),
        reviewsCount: result.reviews?.length,
        address: result.formattedAddress,
        imageUrl: photoUrl,
        category: '', // You may choose to set a default or leave it empty
        latitude: result.geometry?.location.lat ?? 0.0,
        longitude: result.geometry?.location.lng ?? 0.0,
        timestamp: DateTime.now(), // Using current time as placeholder
      );
    } else {
      throw Exception(
          'Failed to fetch details for placeId=$placeId: ${response.errorMessage}');
    }
  }

  /// Build a Google photo URL for a given photoReference.
  String _buildPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=400'
        '&photoreference=$photoReference'
        '&key=${dotenv.env['GOOGLE_API_KEY']}';
  }
}
