import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<List<Map<String, dynamic>>> getPwdFriendlyLocations() async {
  try {
    final querySnapshot = await _firestore.collection('pwd_locations').get();
    return querySnapshot.docs.map((doc) {
      return {
        "id": doc.id,
        "name": doc['name'],
        "latitude": doc['latitude'],
        "longitude": doc['longitude'],
        "details": doc['details'],
        "averageRating": doc['averageRating'] ?? 0,
        "totalRatings": doc['totalRatings'] ?? 0,
      };
    }).toList();
  } catch (e) {
    print('Error fetching PWD locations: $e');
    return [];
  }
}
