import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<List<Map<String, dynamic>>> getPwdFriendlyLocations() async {
  try {
    final querySnapshot = await _firestore.collection('pwd_locations').get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();

      // Debug: Print all fields and their types
      data.forEach((key, value) {});

      // Handle notificationRadius type conversion
      dynamic notificationRadius = data['notificationRadius'];
      double parsedRadius = 100.0; // default

      if (notificationRadius is double) {
        parsedRadius = notificationRadius;
      } else if (notificationRadius is int) {
        parsedRadius = notificationRadius.toDouble();
      } else if (notificationRadius is String) {
        parsedRadius = double.tryParse(notificationRadius) ?? 100.0;
      }

      return {
        "id": doc.id,
        "name": data['name'],
        "latitude": data['latitude'],
        "longitude": data['longitude'],
        "details": data['details'],
        "averageRating": data['averageRating'] ?? 0,
        "totalRatings": data['totalRatings'] ?? 0,
        "notificationRadius": parsedRadius, // Use parsed value
      };
    }).toList();
  } catch (e, stackTrace) {
    print('Error fetching PWD locations: $e');
    print('Stack trace: $stackTrace');
    return [];
  }
}
