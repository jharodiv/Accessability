// lib/firebaseServices/space/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Robust lookup: try doc id first, then query uid field. Return
  /// first+last name or fallback to displayName/username.
  Future<String> getFullName(String userId) async {
    if (userId.isEmpty) return '';

    try {
      final docRef = _firestore.collection('Users').doc(userId);
      final doc = await docRef.get();

      Map<String, dynamic>? data;
      if (doc.exists) {
        data = doc.data() as Map<String, dynamic>?;
      } else {
        final q = await _firestore
            .collection('Users')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty)
          data = q.docs.first.data() as Map<String, dynamic>?;
      }

      if (data == null) return '';

      final firstName =
          (data['firstName'] ?? data['first_name'] ?? '').toString();
      final lastName = (data['lastName'] ?? data['last_name'] ?? '').toString();
      final combined = "${firstName.trim()} ${lastName.trim()}".trim();
      if (combined.isNotEmpty) return combined;

      final fallback = (data['displayName'] ??
              data['display_name'] ??
              data['username'] ??
              data['name'] ??
              '')
          .toString();
      return fallback.trim();
    } catch (e) {
      // debug: print error to console for diagnosis
      debugPrint('UserService.getFullName error: $e');
      return '';
    }
  }
}
