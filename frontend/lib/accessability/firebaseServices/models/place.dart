import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String userId;
  final String? placeId; // Google place ID
  final double? rating;
  final int? reviewsCount;
  final String? address;
  final String? imageUrl;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  Place({
    required this.id,
    required this.userId,
    this.placeId,
    this.rating,
    this.reviewsCount,
    this.address,
    this.imageUrl,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory Place.fromMap(String id, Map<String, dynamic> data) {
    return Place(
      id: id,
      userId: data['userId'] ?? '',
      placeId: data['placeId'],
      rating:
          data['rating'] != null ? (data['rating'] as num).toDouble() : null,
      reviewsCount:
          data['reviewsCount'] != null ? data['reviewsCount'] as int : null,
      address: data['address'],
      imageUrl: data['imageUrl'],
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'placeId': placeId,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'address': address,
      'imageUrl': imageUrl,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }
}
