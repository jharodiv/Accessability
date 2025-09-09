// lib/firebaseServices/space/space_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SpaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collection = 'Spaces';

  Future<void> transferOwnership({
    required String spaceId,
    required String newOwnerId,
    required String performedBy,
  }) async {
    if (spaceId.isEmpty || newOwnerId.isEmpty || performedBy.isEmpty) {
      throw ArgumentError('spaceId/newOwnerId/performedBy must not be empty');
    }

    final docRef = _firestore.collection(collection).doc(spaceId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Space not found');

      final data = snap.data()!;
      final creator = (data['creator'] ?? '') as String;
      final members = List<String>.from(data['members'] ?? <String>[]);
      final admins = List<String>.from(data['admins'] ?? <String>[]);

      // Only current creator can transfer ownership
      if (performedBy != creator) {
        throw Exception('Only the current creator can transfer ownership.');
      }

      // new owner must be a member
      if (!members.contains(newOwnerId)) {
        throw Exception('New owner must be a member of the space.');
      }

      // update creator field and ensure newOwnerId is an admin
      final Map<String, dynamic> updates = {
        'creator': newOwnerId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.update(docRef, updates);

      if (!admins.contains(newOwnerId)) {
        tx.update(docRef, {
          'admins': FieldValue.arrayUnion([newOwnerId])
        });
      }
    });
  }

  /// Create a new space document. Returns the new doc id.
  Future<String> createSpace({
    required String name,
    required String creatorId,
    List<String>? members,
    String? verificationCode,
  }) async {
    final now = Timestamp.now();
    final docRef = await _firestore.collection(collection).add({
      'name': name,
      'creator': creatorId,
      'members': (members == null || members.isEmpty) ? [creatorId] : members,
      'verificationCode': verificationCode ?? '',
      'createdAt': now,
      'codeTimestamp': now,
    });

    return docRef.id;
  }

  /// Update the space name (rename)
  Future<void> renameSpace(String spaceId, String newName) async {
    if (spaceId.isEmpty) throw ArgumentError('spaceId is empty');
    await _firestore.collection(collection).doc(spaceId).update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a space document
  Future<void> deleteSpace(String spaceId) async {
    if (spaceId.isEmpty) throw ArgumentError('spaceId is empty');
    await _firestore.collection(collection).doc(spaceId).delete();
    // Note: consider calling cleanup for related collections (messages, locations, invites)
  }

  /// Add a member to a space
  Future<void> addMember(String spaceId, String userId) async {
    if (spaceId.isEmpty || userId.isEmpty) return;
    await _firestore.collection(collection).doc(spaceId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove a member from a space
  /// Remove a member from a space. Only an admin or the creator (owner) can remove a member.
  /// This will also remove the user from the admins array if they were an admin.
  Future<void> removeMember({
    required String spaceId,
    required String userId,
    required String performedBy,
  }) async {
    if (spaceId.isEmpty || userId.isEmpty || performedBy.isEmpty) return;

    final docRef = _firestore.collection(collection).doc(spaceId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Space not found');

      final data = snap.data()!;
      final creator = (data['creator'] ?? '') as String;
      final admins = List<String>.from(data['admins'] ?? <String>[]);
      final members = List<String>.from(data['members'] ?? <String>[]);

      // Permission check: only creator or admins can remove members
      if (performedBy != creator && !admins.contains(performedBy)) {
        throw Exception('Only admins or the owner can remove members.');
      }

      // Never allow removing the creator/owner
      if (userId == creator) {
        throw Exception('Cannot remove the creator/owner.');
      }

      // Ensure the user is actually a member
      if (!members.contains(userId)) {
        throw Exception('User is not a member of this space.');
      }

      // Remove from members
      tx.update(docRef, {
        'members': FieldValue.arrayRemove([userId]),
      });

      // If the removed user was an admin, also remove from admins
      if (admins.contains(userId)) {
        tx.update(docRef, {
          'admins': FieldValue.arrayRemove([userId]),
        });
      }
    });
  }

  /// Get a stream of spaces the given user belongs to
  Stream<QuerySnapshot> getSpacesForUser(String userId) {
    return _firestore
        .collection(collection)
        .where('members', arrayContains: userId)
        .snapshots();
  }

  /// Fetch a single space doc (one-time read)
  Future<DocumentSnapshot> getSpace(String spaceId) {
    return _firestore.collection(collection).doc(spaceId).get();
  }

  /// Best-effort cleanup for space-related collections (optional)
  /// This method only deletes the space doc's related collections (not a full implementation).
  Future<void> cleanupSpaceData(String spaceId) async {
    // Implement whatever cleanup you need: chats, locations, invitations etc.
    // IMPORTANT: Deleting many docs should be batched/paged in production to avoid timeouts.
    try {
      // Example: delete SpaceLocations with spaceId
      final locs = await _firestore
          .collection('SpaceLocations')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final batch = _firestore.batch();
      for (final doc in locs.docs) batch.delete(doc.reference);

      // (More deletes here for other collections as needed...)

      await batch.commit();
    } catch (e) {
      // swallow or rethrow based on your needs
      rethrow;
    }
  }

  /// Promote a member to admin. `performedBy` is the uid of the user performing this action
  Future<void> promoteToAdmin({
    required String spaceId,
    required String userId,
    required String performedBy,
  }) async {
    if (spaceId.isEmpty || userId.isEmpty || performedBy.isEmpty) return;
    final docRef = _firestore.collection(collection).doc(spaceId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Space not found');

      final data = snap.data()!;
      final admins = List<String>.from(data['admins'] ?? <String>[]);
      final members = List<String>.from(data['members'] ?? <String>[]);
      final creator = data['creator'] as String?;

      // Only creator or existing admin can promote
      if (performedBy != creator && !admins.contains(performedBy)) {
        throw Exception('Only creator or admins can promote members.');
      }

      // user must be a member before being admin (you can change this if you allow direct admin add)
      if (!members.contains(userId)) {
        throw Exception('User is not a member of this space.');
      }

      if (!admins.contains(userId)) {
        tx.update(docRef, {
          'admins': FieldValue.arrayUnion([userId]),
        });
      }
    });
  }

  /// Demote an admin to regular member. Cannot demote the creator/owner.
  Future<void> demoteAdmin({
    required String spaceId,
    required String userId,
    required String performedBy,
  }) async {
    if (spaceId.isEmpty || userId.isEmpty || performedBy.isEmpty) return;
    final docRef = _firestore.collection(collection).doc(spaceId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Space not found');

      final data = snap.data()!;
      final admins = List<String>.from(data['admins'] ?? <String>[]);
      final creator = data['creator'] as String?;

      // Only creator or existing admin can demote (you can enforce stricter rules if you want)
      if (performedBy != creator && !admins.contains(performedBy)) {
        throw Exception('Only creator or admins can demote admins.');
      }

      // never demote the creator
      if (creator == userId) {
        throw Exception('Cannot demote the creator/owner.');
      }

      if (admins.contains(userId)) {
        tx.update(docRef, {
          'admins': FieldValue.arrayRemove([userId]),
        });
      }
    });
  }

  /// Check if a user is admin (one-time check)
  Future<bool> isAdmin(String spaceId, String userId) async {
    if (spaceId.isEmpty || userId.isEmpty) return false;
    final snap = await _firestore.collection(collection).doc(spaceId).get();
    if (!snap.exists) return false;
    final data = snap.data()!;
    final creator = data['creator'] as String?;
    final admins = List<String>.from(data['admins'] ?? <String>[]);

    return (creator == userId) || admins.contains(userId);
  }
}
