import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Place {
  final String id;
  final String userId;
  final String? googlePlaceId; // Google place ID
  final String? osmId; // OpenStreetMap ID
  final double? rating;
  final int? reviewsCount;
  final String? address;
  final String? imageUrl;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool? isFromOSM; // Flag to indicate OpenStreetMap source

  Place({
    required this.id,
    required this.userId,
    this.googlePlaceId,
    this.osmId,
    this.rating,
    this.reviewsCount,
    this.address,
    this.imageUrl,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isFromOSM = false,
  });

  factory Place.fromMap(String id, Map<String, dynamic> data) {
    return Place(
      id: id,
      userId: data['userId'] ?? '',
      googlePlaceId: data['googlePlaceId'],
      osmId: data['osmId'],
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
      isFromOSM: data['isFromOSM'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'googlePlaceId': googlePlaceId,
      'osmId': osmId,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'address': address,
      'imageUrl': imageUrl,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'isFromOSM': isFromOSM,
    };
  }

  /// Creates a Place from a nearby Marker
  factory Place.fromNearbyMarker(Marker marker, {bool isOSM = false}) {
    return Place(
      id: marker.markerId.value,
      userId: '',
      googlePlaceId: isOSM ? null : marker.markerId.value,
      osmId: isOSM ? marker.markerId.value : null,
      name: marker.infoWindow.title ?? 'Unknown Place',
      rating: 0.0,
      reviewsCount: 0,
      address: marker.infoWindow.snippet ?? 'No address available',
      imageUrl: '',
      category: '',
      latitude: marker.position.latitude,
      longitude: marker.position.longitude,
      timestamp: DateTime.now(),
      isFromOSM: isOSM,
    );
  }

  /// Creates a copy of the place with updated values
  Place copyWith({
    String? id,
    String? userId,
    String? googlePlaceId,
    String? osmId,
    double? rating,
    int? reviewsCount,
    String? address,
    String? imageUrl,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    bool? isFromOSM,
  }) {
    return Place(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      osmId: osmId ?? this.osmId,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isFromOSM: isFromOSM ?? this.isFromOSM,
    );
  }
}
