import 'package:accessability/accessability/data/model/emergency_contact.dart';
import 'package:accessability/accessability/firebaseServices/emergency/emergency_service.dart';

class EmergencyRepository {
  final EmergencyService emergencyService;

  EmergencyRepository({required this.emergencyService});

  Future<void> addEmergencyContact(String uid, EmergencyContact contact) async {
    try {
      await emergencyService.addEmergencyContact(uid, contact);
    } catch (e) {
      throw Exception('Failed to add emergency contact: ${e.toString()}');
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts(String uid) async {
    try {
      return await emergencyService.getEmergencyContacts(uid);
    } catch (e) {
      throw Exception('Failed to fetch emergency contacts: ${e.toString()}');
    }
  }

  Future<void> updateEmergencyContact(
      String uid, String contactId, EmergencyContact contact) async {
    try {
      await emergencyService.updateEmergencyContact(uid, contactId, contact);
    } catch (e) {
      throw Exception('Failed to update emergency contact: ${e.toString()}');
    }
  }

  Future<void> deleteEmergencyContact(String uid, String contactId) async {
    try {
      await emergencyService.deleteEmergencyContact(uid, contactId);
    } catch (e) {
      throw Exception('Failed to delete emergency contact: ${e.toString()}');
    }
  }

  // // Optional helper: fetch contacts filtered by relationship.
  // // Requires EmergencyService.getEmergencyContactsByRelationship to be implemented.
  // Future<List<EmergencyContact>> getEmergencyContactsByRelationship(
  //     String uid, String relationship) async {
  //   try {
  //     return await emergencyService.getEmergencyContactsByRelationship(
  //         uid, relationship);
  //   } catch (e) {
  //     throw Exception(
  //         'Failed to fetch emergency contacts by relationship: ${e.toString()}');
  //   }
  // }
}
