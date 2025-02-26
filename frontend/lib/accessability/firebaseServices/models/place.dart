import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String userId;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  Place({
    required this.id,
    required this.userId,
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
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }
}
