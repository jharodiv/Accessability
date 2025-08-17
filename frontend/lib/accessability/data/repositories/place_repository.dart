import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/place_service.dart';

class PlaceRepository {
  final PlaceService placeService;

  PlaceRepository({required this.placeService});

  Future<void> addPlace(String name, double latitude, double longitude,
      {String? category}) async {
    try {
      await placeService.addPlace(name, latitude, longitude,
          category: category);
    } catch (e) {
      throw Exception('Failed to add place: ${e.toString()}');
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
}
