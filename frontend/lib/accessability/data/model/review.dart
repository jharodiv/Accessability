// models/review.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final double rating;
  final String comment;
  final DateTime timestamp;

  Review({
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfilePicture': userProfilePicture,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    try {
      return Review(
        userId: map['userId']?.toString() ?? 'unknown',
        userName: map['userName']?.toString() ?? 'Anonymous User',
        userProfilePicture: map['userProfilePicture']?.toString(),
        rating: _parseDouble(map['rating']),
        comment: map['comment']?.toString() ?? '',
        timestamp: _parseTimestamp(map['timestamp']),
      );
    } catch (e) {
      print('Error creating Review from map: $e');
      return Review(
        userId: 'error',
        userName: 'Error loading review',
        rating: 0,
        comment: 'Could not load this review',
        timestamp: DateTime.now(),
      );
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String)
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now();
  }
}
