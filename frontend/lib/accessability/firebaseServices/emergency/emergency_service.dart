import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:accessability/accessability/data/model/emergency_contact.dart';

class EmergencyService {
  final FirebaseFirestore _firestore;

  EmergencyService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Add an emergency contact for a user.
  Future<DocumentReference> addEmergencyContact(
      String uid, EmergencyContact contact) async {
    try {
      return await _firestore
          .collection('Users')
          .doc(uid)
          .collection('EmergencyContacts')
          .add(contact.toMap());
    } catch (e) {
      throw Exception('Error adding emergency contact: $e');
    }
  }

  /// Update an existing emergency contact.
  Future<void> updateEmergencyContact(
      String uid, String contactId, EmergencyContact contact) async {
    try {
      await _firestore
          .collection('Users')
          .doc(uid)
          .collection('EmergencyContacts')
          .doc(contactId)
          .update(contact.toMap());
    } catch (e) {
      throw Exception('Error updating emergency contact: $e');
    }
  }

  /// Delete an emergency contact.
  Future<void> deleteEmergencyContact(String uid, String contactId) async {
    try {
      await _firestore
          .collection('Users')
          .doc(uid)
          .collection('EmergencyContacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting emergency contact: $e');
    }
  }

  /// Fetch all emergency contacts for a user.
  Future<List<EmergencyContact>> getEmergencyContacts(String uid) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('Users')
          .doc(uid)
          .collection('EmergencyContacts')
          .get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return EmergencyContact.fromMap(data, id: doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Error fetching emergency contacts: $e');
    }
  }
}
