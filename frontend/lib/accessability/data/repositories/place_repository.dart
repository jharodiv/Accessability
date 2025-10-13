import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/firebaseServices/place/place_service.dart';

class PlaceRepository {
  final PlaceService placeService;

  PlaceRepository({required this.placeService});

  Future<void> addPlace(String name, double latitude, double longitude,
      {String? category, double notificationRadius = 100.0}) async {
    // NEW
    try {
      await placeService.addPlace(name, latitude, longitude,
          category: category, notificationRadius: notificationRadius); // NEW
    } catch (e) {
      throw Exception('Failed to add place: ${e.toString()}');
    }
  }

  Future<void> toggleFavorite(Place place) async {
    try {
      await placeService.toggleFavorite(place);
    } catch (e) {
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  Future<void> updateNotificationRadius(String placeId, double radius) async {
    try {
      await placeService.updateNotificationRadius(placeId, radius);
    } catch (e) {
      throw Exception('Failed to update notification radius: ${e.toString()}');
    }
  }

  Future<List<Place>> getAllPlaces() async {
    try {
      return await placeService.getAllPlaces();
    } catch (e) {
      throw Exception('Failed to fetch all places: ${e.toString()}');
    }
  }

  Stream<List<Place>> getPlacesByCategory(String category) {
    try {
      return placeService.getPlacesByCategory(category);
    } catch (e) {
      throw Exception('Failed to fetch places by category: ${e.toString()}');
    }
  }

  Future<void> deletePlace(String placeId) async {
    try {
      await placeService.deletePlace(placeId);
    } catch (e) {
      throw Exception('Failed to delete place: ${e.toString()}');
    }
  }

  // New method: update the category of a place.
  Future<void> updatePlaceCategory(String placeId, String newCategory) async {
    try {
      await placeService.updatePlaceCategory(placeId, newCategory);
    } catch (e) {
      throw Exception('Failed to update place category: ${e.toString()}');
    }
  }

  // New method: remove a place from its category (set its category to "none").
  Future<void> removePlaceFromCategory(String placeId) async {
    try {
      await placeService.removePlaceFromCategory(placeId);
    } catch (e) {
      throw Exception('Failed to remove place from category: ${e.toString()}');
    }
  }

  // NEW: Delete place completely
  Future<void> deletePlaceCompletely(String placeId) async {
    try {
      await placeService.deletePlaceCompletely(placeId);
    } catch (e) {
      throw Exception('Failed to delete place: ${e.toString()}');
    }
  }

  // NEW: Toggle favorite with deletion
  Future<void> toggleFavoriteWithDeletion(Place place) async {
    try {
      await placeService.toggleFavoriteWithDeletion(place);
    } catch (e) {
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  Future<bool> isPlaceFavorite(Place place) async {
    try {
      return await placeService.isPlaceFavorite(place);
    } catch (e) {
      throw Exception('Failed to check favorite status: ${e.toString()}');
    }
  }

  // NEW: Get favorite places stream
  Stream<List<Place>> getFavoritePlaces() {
    try {
      return placeService.getFavoritePlaces();
    } catch (e) {
      throw Exception('Failed to get favorite places: ${e.toString()}');
    }
  }

  // NEW: Add place to favorites
  Future<void> addToFavorites(Place place) async {
    try {
      await placeService.addToFavorites(place);
    } catch (e) {
      throw Exception('Failed to add to favorites: ${e.toString()}');
    }
  }

  Future<bool> shouldDeletePlace(Place place) async {
    try {
      return await placeService.shouldDeletePlace(place);
    } catch (e) {
      throw Exception('Failed to check deletion status: ${e.toString()}');
    }
  }
}
