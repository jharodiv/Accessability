import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/place_service.dart';

class PlaceRepository {
  final PlaceService placeService;

  PlaceRepository({required this.placeService});

  Future<void> addPlace(String name, double latitude, double longitude) async {
    try {
      await placeService.addPlace(name, latitude, longitude);
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
}
