import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place.dart'; // Ensure the correct import path for the Place model

class PlaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addPlace(
    String name,
    double latitude,
    double longitude, {
    String? category,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Use the provided category if available, otherwise default to "none".
      Place place = Place(
        id: '', // Firestore will generate an ID
        userId: user.uid,
        name: name,
        category: category ?? 'none',
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('Places').add(place.toMap());
    } catch (e) {
      print('Error adding place: $e');
      throw Exception('Failed to add place: $e');
    }
  }

  // Existing method: fetch places by category.
  Stream<List<Place>> getPlacesByCategory(String category) {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    return _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Place.fromMap(doc.id, doc.data()))
            .toList());
  }

  // New method: fetch all places (ignoring category).
  Future<List<Place>> getAllPlaces() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    QuerySnapshot snapshot = await _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Place.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePlace(String placeId) async {
    try {
      await _firestore.collection('Places').doc(placeId).delete();
    } catch (e) {
      print('Error deleting place: $e');
      throw Exception('Failed to delete place: $e');
    }
  }

  // New method: update the category of a place.
  Future<void> updatePlaceCategory(String placeId, String newCategory) async {
    try {
      await _firestore.collection('Places').doc(placeId).update({
        'category': newCategory,
      });
    } catch (e) {
      print('Error updating place category: $e');
      throw Exception('Failed to update place category: $e');
    }
  }

  // New method: remove the place from its category (i.e. set its category to "none").
  Future<void> removePlaceFromCategory(String placeId) async {
    try {
      await updatePlaceCategory(placeId, 'none');
    } catch (e) {
      print('Error removing place from category: $e');
      throw Exception('Failed to remove place from category: $e');
    }
  }
}
