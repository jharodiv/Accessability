import 'dart:math';

import 'package:accessability/accessability/data/model/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatService {
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get users with accepted chat requests (both sender and receiver)
  Stream<List<Map<String, dynamic>>> getUsersWithAcceptedChatRequests() {
    final String currentUserID = _auth.currentUser!.uid;

    return firebaseFirestore
        .collection('chat_requests')
        .where('status', isEqualTo: 'accepted')
        .where(
          Filter.or(
            Filter('receiverID', isEqualTo: currentUserID),
            Filter('senderID', isEqualTo: currentUserID),
          ),
        )
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderID = data['senderID'];
        final receiverID = data['receiverID'];

        // Fetch the other user's data (either sender or receiver)
        final otherUserID = senderID == currentUserID ? receiverID : senderID;

        final userSnapshot =
            await firebaseFirestore.collection('Users').doc(otherUserID).get();

        if (userSnapshot.exists) {
          users.add(userSnapshot.data() as Map<String, dynamic>);
        }
      }

      return users;
    });
  }

  Future<String?> getChatRequestStatus(String requestId) async {
    if (requestId.isEmpty) return null;
    final doc = await firebaseFirestore
        .collection('chat_requests')
        .doc(requestId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return (data['status'] as String?)?.toLowerCase();
  }

  // Get a stream of users in the same spaces
  Stream<List<Map<String, dynamic>>> getUsersInSameSpaces() {
    final String currentUserID = _auth.currentUser!.uid;

    return firebaseFirestore
        .collection('Spaces')
        .where('members', arrayContains: currentUserID)
        .snapshots()
        .asyncMap((spacesSnapshot) async {
      Set<String> userIds = {};

      for (var spaceDoc in spacesSnapshot.docs) {
        final spaceData = spaceDoc.data();
        final members = List<String>.from(spaceData['members'] ?? []);
        userIds.addAll(members);
      }

      if (userIds.isEmpty) {
        return [];
      }

      // Exclude the current user and space chat rooms
      userIds.remove(currentUserID);

      final usersSnapshot = await firebaseFirestore
          .collection('Users')
          .where('uid', whereIn: userIds.toList())
          .get();

      return usersSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // Send a message (handles both space and private chat rooms)
  Future<void> sendMessage(String chatId, String message,
      {bool isSpaceChat = false}) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: chatId,
      message: message,
      timestamp: timestamp,
    );

    if (isSpaceChat) {
      // Send message to the space chat room
      await firebaseFirestore
          .collection('space_chat_rooms')
          .doc(chatId) // Use the spaceId as the document ID
          .collection('messages')
          .add(newMessage.toMap());
    } else {
      // Send message to a private chat room
      List<String> ids = [currentUserID, chatId];
      ids.sort();
      String chatRoomID = ids.join('_');

      await firebaseFirestore
          .collection('chat_rooms')
          .doc(chatRoomID)
          .collection('messages')
          .add(newMessage.toMap());
    }
  }

  Stream<List<Map<String, dynamic>>> getChatRequestsByStatus(String status) {
    final String currentUserID = _auth.currentUser!.uid;
    return firebaseFirestore
        .collection('chat_requests')
        .where('receiverID', isEqualTo: currentUserID)
        .where('status', isEqualTo: status) // pending / accepted / rejected
        .snapshots()
        .asyncMap((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  // Send a chat request
  Future<void> sendChatRequest(String receiverID, String message) async {
    await firebaseFirestore.collection('chat_requests').add({
      'senderID': _auth.currentUser!.uid,
      'receiverID': receiverID,
      'message': message,
      'status': 'pending', // <-- here
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> sendChatRequestWithMetadata(
      String receiverID, String message, Map<String, dynamic> metadata) async {
    final String senderID = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    await firebaseFirestore.collection('chat_requests').add({
      'senderID': senderID,
      'receiverID': receiverID,
      'message': message,
      'status': 'pending',
      'timestamp': timestamp,
      'metadata': metadata, // Include metadata
    });
  }

  // Accept a chat request and create a chat room with the last message
  Future<void> acceptChatRequest(String requestID) async {
    if (requestID.isEmpty) throw Exception('Request ID cannot be empty');

    final requestRef =
        firebaseFirestore.collection('chat_requests').doc(requestID);
    final requestSnapshot = await requestRef.get();
    if (!requestSnapshot.exists) return;

    final requestData = requestSnapshot.data()!;
    final senderID = requestData['senderID'];
    final receiverID = requestData['receiverID'];
    final metadata = requestData['metadata'] as Map<String, dynamic>?;

    // If metadata contains spaceId, prefer to join user to that space
    final String? spaceId = metadata?['spaceId'] as String?;

    final batch = firebaseFirestore.batch();

    // 1) update request status
    batch.update(requestRef, {'status': 'accepted'});

    // 2) create chat_room if needed
    List<String> ids = [senderID, receiverID];
    ids.sort();
    final chatRoomID = ids.join('_');
    final chatRoomRef =
        firebaseFirestore.collection('chat_rooms').doc(chatRoomID);
    batch.set(
        chatRoomRef,
        {
          'participants': [senderID, receiverID],
          'createdAt': requestData['timestamp'] ?? FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    // 3) add a message record in that chat room (optional)
    final messageRef = chatRoomRef.collection('messages').doc();
    batch.set(messageRef, {
      'senderID': senderID,
      'receiverID': receiverID,
      'message': requestData['message'],
      'timestamp': requestData['timestamp'] ?? FieldValue.serverTimestamp(),
      'metadata': metadata,
    });

    // 4) if spaceId exists, add the receiver as a member of that Space and space_chat_rooms members
    if (spaceId != null && spaceId.isNotEmpty) {
      final spacesRef = firebaseFirestore.collection('Spaces').doc(spaceId);
      batch.update(spacesRef, {
        'members': FieldValue.arrayUnion([receiverID]),
      });

      final spaceChatRef =
          firebaseFirestore.collection('space_chat_rooms').doc(spaceId);
      batch.set(
          spaceChatRef,
          {
            'members': FieldValue.arrayUnion([receiverID]),
          },
          SetOptions(merge: true));
    }

    // commit all
    await batch.commit();
  }

  // Reject a chat request
  Future<void> rejectChatRequest(String requestID) async {
    await firebaseFirestore.collection('chat_requests').doc(requestID).update({
      'status': 'rejected',
    });
  }

  Stream<List<Map<String, dynamic>>> getVerificationCodeChatRequests() {
    final String receiverID = _auth.currentUser!.uid;

    return firebaseFirestore
        .collection('chat_requests')
        .where('receiverID', isEqualTo: receiverID)
        .where('status', isEqualTo: 'pending')
        .where('metadata.type', isEqualTo: 'verification_code')
        .orderBy('timestamp', descending: true) // 👈 HERE
        .snapshots()
        .asyncMap((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id, // Include the document ID
          ...doc.data(), // Include all document data
        };
      }).toList();
    });
  }

  // Check if a chat request exists between two users
  Future<bool> hasChatRequest(String senderID, String receiverID) async {
    final snapshot = await firebaseFirestore
        .collection('chat_requests')
        .where('senderID', isEqualTo: senderID)
        .where('receiverID', isEqualTo: receiverID)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Check if a chat room exists between two users
  Future<bool> hasChatRoom(String userID1, String userID2) async {
    List<String> ids = [userID1, userID2];
    ids.sort();
    String chatRoomID = ids.join('_');

    final snapshot =
        await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).get();

    return snapshot.exists;
  }

  // Create a chat room for a space
  Future<void> createSpaceChatRoom(String spaceId, String spaceName) async {
    final String creatorId = _auth.currentUser!.uid;

    await firebaseFirestore.collection('space_chat_rooms').doc(spaceId).set({
      'name': spaceName,
      'createdAt': Timestamp.now(),
      'members': [creatorId], // Add the creator as the first member
    });

    // Send a system welcome message to the space chat room
    await sendSystemMessage(spaceId, 'Welcome to the $spaceName space!');
  }

  // Add a member to the space chat room and create chat rooms with all members
  Future<void> addMemberToSpaceChatRoom(String spaceId, String userId) async {
    try {
      // Check if space chat room exists
      final spaceSnapshot = await firebaseFirestore
          .collection('space_chat_rooms')
          .doc(spaceId)
          .get();

      if (!spaceSnapshot.exists) {
        // Create space chat room if it doesn't exist
        final spaceDoc =
            await firebaseFirestore.collection('Spaces').doc(spaceId).get();

        if (spaceDoc.exists) {
          final spaceName = spaceDoc['name'] ?? 'Unnamed Space';
          await createSpaceChatRoom(spaceId, spaceName);
        }
        return;
      }

      // Add user to space chat room
      await firebaseFirestore
          .collection('space_chat_rooms')
          .doc(spaceId)
          .update({
        'members': FieldValue.arrayUnion([userId]),
      });

      // Send welcome message
      final userSnapshot =
          await firebaseFirestore.collection('Users').doc(userId).get();

      if (userSnapshot.exists) {
        final username = userSnapshot.data()?['username'] ?? 'Unknown User';
        await sendSystemMessage(spaceId, '$username has joined the space!');
      }

      // Create individual chat rooms
      await createChatRoomsForNewMember(
          spaceId, userId, spaceSnapshot['name'] ?? 'Unnamed Space');
    } catch (e) {
      print('Error adding member to space chat room: $e');
    }
  }

  Future<void> createChatRoomForMembers(
      String userID1, String userID2, String spaceName) async {
    List<String> ids = [userID1, userID2];
    ids.sort();
    String chatRoomID = ids.join('_');

    // Check if the chat room already exists
    final chatRoomSnapshot =
        await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).get();
    if (!chatRoomSnapshot.exists) {
      // Create the chat room
      await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).set({
        'participants': [userID1, userID2],
        'createdAt': Timestamp.now(),
      });

      // Send a welcome message to the new chat room
      await sendMessage(
        userID2, // Send the message to the other user
        "Hi! I'm with you in the $spaceName space.",
        isSpaceChat: false, // This is a private chat room
      );

      // Automatically accept any pending chat requests between these users
      await _acceptPendingChatRequests(userID1, userID2);
    }
  }

  // Create chat rooms for the new member with all existing members
  Future<void> createChatRoomsForNewMember(
      String spaceId, String newMemberId, String spaceName) async {
    // Fetch all members in the space
    final spaceSnapshot = await firebaseFirestore
        .collection('space_chat_rooms')
        .doc(spaceId)
        .get();
    if (!spaceSnapshot.exists) return;

    final members = List<String>.from(spaceSnapshot['members'] ?? []);

    // Create chat rooms between the new member and all existing members
    for (final memberId in members) {
      if (memberId != newMemberId) {
        await createChatRoomForMembers(newMemberId, memberId, spaceName);
      }
    }
  }

  // In ChatService, add this method:
  Future<void> checkAndExpireRequests() async {
    try {
      final String receiverID = _auth.currentUser!.uid;

      final snapshot = await firebaseFirestore
          .collection('chat_requests')
          .where('receiverID', isEqualTo: receiverID)
          .where('status', isEqualTo: 'pending')
          .where('metadata.type', isEqualTo: 'verification_code')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>?;
        final expiresAtString = metadata?['expiresAt'] as String?;

        if (expiresAtString != null) {
          final expiresAt = DateTime.parse(expiresAtString);
          if (DateTime.now().isAfter(expiresAt)) {
            print('Auto-declining expired verification request: ${doc.id}');
            await rejectChatRequest(doc.id);
          }
        }
      }
    } catch (e) {
      print('Error in expiration checker: $e');
    }
  }

  // Get messages for a chat room (handles both space and private chat rooms)
  Stream<QuerySnapshot> getMessages(String receiverID,
      {bool isSpaceChat = false}) {
    if (isSpaceChat) {
      // Fetch messages for a space chat room
      return firebaseFirestore
          .collection('space_chat_rooms')
          .doc(receiverID) // Use the spaceId as the document ID
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      // Fetch messages for a private chat room
      final String currentUserID = _auth.currentUser!.uid;
      List<String> ids = [currentUserID, receiverID];
      ids.sort();
      String chatRoomID = ids.join('_');

      return firebaseFirestore
          .collection('chat_rooms')
          .doc(chatRoomID)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  // Automatically accept pending chat requests between two users
  Future<void> _acceptPendingChatRequests(
      String userID1, String userID2) async {
    final requestsSnapshot = await firebaseFirestore
        .collection('chat_requests')
        .where('status', isEqualTo: 'pending')
        .where(
          Filter.or(
            Filter.and(
              Filter('senderID', isEqualTo: userID1),
              Filter('receiverID', isEqualTo: userID2),
            ),
            Filter.and(
              Filter('senderID', isEqualTo: userID2),
              Filter('receiverID', isEqualTo: userID1),
            ),
          ),
        )
        .get();

    for (final doc in requestsSnapshot.docs) {
      await acceptChatRequest(doc.id);
    }
  }

  // Helper method to generate a chat room ID
  String _getChatRoomID(String userID1, String userID2) {
    List<String> ids = [userID1, userID2];
    ids.sort();
    return ids.join('_');
  }

  // Get space chat rooms for the current user
  Stream<List<Map<String, dynamic>>> getSpaceChatRooms() {
    final String currentUserID = _auth.currentUser!.uid;

    return firebaseFirestore
        .collection('space_chat_rooms')
        .where('members', arrayContains: currentUserID)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> validSpaces = [];

      for (final doc in snapshot.docs) {
        final spaceId = doc.id;

        // Check if user is still a member of the actual space
        final spaceDoc =
            await firebaseFirestore.collection('Spaces').doc(spaceId).get();

        if (spaceDoc.exists) {
          final spaceData = spaceDoc.data() as Map<String, dynamic>;
          final members = List<String>.from(spaceData['members'] ?? []);

          // Only include if user is still a member of the space
          if (members.contains(currentUserID)) {
            validSpaces.add({
              'id': doc.id,
              'name': doc['name'],
              'createdAt': doc['createdAt'],
            });
          }
        }
      }

      return validSpaces;
    });
  }

  Future<void> sendSystemMessage(String spaceId, String message) async {
    final Timestamp timestamp = Timestamp.now();

    await firebaseFirestore
        .collection('space_chat_rooms')
        .doc(spaceId)
        .collection('messages')
        .add({
      'senderID': 'system', // Use 'system' as sender ID for system messages
      'senderEmail': 'system@system.com',
      'message': message,
      'timestamp': timestamp,
      'isSystemMessage': true, // Flag to identify system messages
    });
  }

  Future<void> notifyMemberRemoved(
      String spaceId, String username, String removerUsername) async {
    final message = '$username was removed from the space by $removerUsername';
    await sendSystemMessage(spaceId, message);
  }

// Notify when a member leaves voluntarily
  Future<void> notifyMemberLeft(String spaceId, String username) async {
    final message = '$username has left the space';
    await sendSystemMessage(spaceId, message);
  }

// Notify when a space is deleted
  Future<void> notifySpaceDeleted(String spaceId, String spaceName) async {
    final message = 'The space "$spaceName" has been deleted';
    await sendSystemMessage(spaceId, message);
  }

  Future<void> removeMemberFromSpaceChatRoom(
      String spaceId, String userId) async {
    try {
      await firebaseFirestore
          .collection('space_chat_rooms')
          .doc(spaceId)
          .update({
        'members': FieldValue.arrayRemove([userId])
      });

      // Optional: Send a system message
      final userDoc =
          await firebaseFirestore.collection('Users').doc(userId).get();
      final username = userDoc['username'] ?? 'Unknown User';

      await sendSystemMessage(spaceId, '$username was removed from the space');
    } catch (e) {
      print('Error removing member from space chat room: $e');
    }
  }

  Future<void> sendVerificationCode(
      String receiverID, String spaceId, String spaceName) async {
    final String senderID = _auth.currentUser!.uid;

    // ===== NEW: don't send invite if receiver already a member =====
    try {
      final alreadyMember = await isUserSpaceMember(spaceId, receiverID);
      if (alreadyMember) {
        debugPrint(
            'sendVerificationCode: receiver $receiverID is already a member of $spaceId — aborting invite');
        return;
      }
    } catch (e) {
      debugPrint('sendVerificationCode: error checking membership: $e');
      // if membership check fails, we still continue — you may want to abort instead
    }
    // ===============================================================

    // Get or generate verification code
    final spaceSnapshot =
        await firebaseFirestore.collection('Spaces').doc(spaceId).get();
    String verificationCode;
    DateTime codeTimestamp = DateTime.now();

    if (spaceSnapshot.exists) {
      final existingCode = spaceSnapshot.data()?['verificationCode'];
      final existingTimestamp =
          spaceSnapshot.data()?['codeTimestamp'] is Timestamp
              ? (spaceSnapshot.data()?['codeTimestamp'] as Timestamp).toDate()
              : null;

      if (existingCode != null && existingTimestamp != null) {
        final now = DateTime.now();
        final difference = now.difference(existingTimestamp).inMinutes;
        verificationCode =
            difference < 10 ? existingCode : _generateVerificationCode();
      } else {
        verificationCode = _generateVerificationCode();
      }
    } else {
      verificationCode = _generateVerificationCode();
    }

    codeTimestamp = DateTime.now();

    // Update space with verification code and timestamp
    await firebaseFirestore.collection('Spaces').doc(spaceId).update({
      'verificationCode': verificationCode,
      'codeTimestamp': Timestamp.fromDate(codeTimestamp),
    });

    // Prepare metadata for verification code (requestId will be set below)
    final metadataBase = {
      'type': 'verification_code',
      'spaceId': spaceId,
      'verificationCode': verificationCode,
      'spaceName': spaceName,
      'expiresAt':
          codeTimestamp.add(const Duration(minutes: 10)).toIso8601String(),
    };

    final message =
        'Join $spaceName! Verification code: $verificationCode (Expires in 10 minutes)';

    // Use the unified method to send with metadata (it will create a chat_requests doc if needed)
    await _sendMessageWithMetadata(receiverID, message, metadataBase);
  }

  Future<void> _sendMessageWithMetadata(
      String receiverID, String message, Map<String, dynamic> metadata) async {
    final String senderID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Ensure metadata is a new map so we can mutate safely
    final Map<String, dynamic> metaCopy = Map<String, dynamic>.from(metadata);

    try {
      // Create a chat_requests doc *always* for verification-like invites. This
      // ensures requestId points to a chat_requests document (so UI + accept flows work).
      final newRequestRef = firebaseFirestore.collection('chat_requests').doc();

      await newRequestRef.set({
        'senderID': senderID,
        'receiverID': receiverID,
        'message': message,
        'status': 'pending',
        'timestamp': timestamp,
        'metadata': {
          ...metaCopy,
          'requestId': newRequestRef.id,
        },
      });

      // Use the request doc id as the canonical requestId
      final String requestId = newRequestRef.id;

      // Check if chat room exists
      final bool chatRoomExists = await hasChatRoom(senderID, receiverID);

      if (chatRoomExists) {
        // Send message into existing chat room and include requestId in metadata
        List<String> ids = [senderID, receiverID];
        ids.sort();
        String chatRoomID = ids.join('_');

        await firebaseFirestore
            .collection('chat_rooms')
            .doc(chatRoomID)
            .collection('messages')
            .add({
          'senderID': senderID,
          'senderEmail': currentUserEmail,
          'receiverID': receiverID,
          'message': message,
          'timestamp': timestamp,
          'metadata': {
            ...metaCopy,
            'requestId': requestId, // now a chat_requests doc id
          },
        });

        debugPrint(
            'Sent verification message to chat room $chatRoomID with requestId $requestId');
      } else {
        // If no chat room, we've already created the chat_requests doc and it's the single source-of-truth.
        debugPrint(
            'Created chat_requests doc $requestId for receiver $receiverID');
      }
    } catch (e) {
      debugPrint('Error in _sendMessageWithMetadata: $e');
      rethrow;
    }
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser!.uid}';
  }

  Future<void> _sendChatRequestWithMetadata(
      String receiverID, String message, Map<String, dynamic> metadata) async {
    final String senderID = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    await firebaseFirestore.collection('chat_requests').add({
      'senderID': senderID,
      'receiverID': receiverID,
      'message': message,
      'status': 'pending',
      'timestamp': timestamp,
      'metadata': metadata, // Include metadata in chat requests
    });
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

// Add this method to check if user is space member
  Future<bool> isUserSpaceMember(String spaceId, String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('space_chat_rooms')
        .doc(spaceId)
        .get();

    if (!doc.exists) return false;

    final members = List<String>.from(doc['members'] ?? []);
    return members.contains(userId); // must check receiver, not sender
  }

  Future<void> editMessage({
    required String chatRoomId,
    required String messageId,
    required String newMessage,
    bool isSpaceChat = false,
  }) async {
    try {
      if (chatRoomId.isEmpty || messageId.isEmpty) {
        throw Exception('Chat room ID and message ID cannot be empty');
      }

      final collection = isSpaceChat
          ? firebaseFirestore
              .collection('space_chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
          : firebaseFirestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages');

      // Verify the message exists and belongs to current user
      final messageDoc = await collection.doc(messageId).get();
      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data();
      if (messageData?['senderID'] != _auth.currentUser!.uid) {
        throw Exception('You can only edit your own messages');
      }

      await collection.doc(messageId).update({
        'message': newMessage,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error editing message: $e');
      throw Exception('Failed to edit message: ${e.toString()}');
    }
  }

  Future<void> deleteMessage({
    required String chatRoomId,
    required String messageId,
    bool isSpaceChat = false,
  }) async {
    try {
      print('🔍 DELETE DEBUG - Starting delete process');
      print('🔍 DELETE DEBUG - chatRoomId: $chatRoomId');
      print('🔍 DELETE DEBUG - messageId: $messageId');
      print('🔍 DELETE DEBUG - isSpaceChat: $isSpaceChat');
      print('🔍 DELETE DEBUG - currentUser: ${_auth.currentUser!.uid}');

      if (chatRoomId.isEmpty || messageId.isEmpty) {
        throw Exception('Chat room ID and message ID cannot be empty');
      }

      final collection = isSpaceChat
          ? firebaseFirestore
              .collection('space_chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
          : firebaseFirestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages');

      print('🔍 DELETE DEBUG - Collection path: ${collection.path}');

      // Verify the message exists and belongs to current user
      final messageDoc = await collection.doc(messageId).get();
      print('🔍 DELETE DEBUG - Message exists: ${messageDoc.exists}');

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data();
      print('🔍 DELETE DEBUG - Message data: $messageData');

      if (messageData?['senderID'] != _auth.currentUser!.uid) {
        print(
            '🔍 DELETE DEBUG - User mismatch. Message sender: ${messageData?['senderID']}, Current user: ${_auth.currentUser!.uid}');
        throw Exception('You can only delete your own messages');
      }

      // Option 1: Soft delete (recommended)
      print('🔍 DELETE DEBUG - Performing soft delete update...');
      await collection.doc(messageId).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'originalMessage': messageData?['message'], // Store original message
      });

      print('✅ DELETE DEBUG - Message soft-deleted successfully');

      // Verify the update worked
      final updatedDoc = await collection.doc(messageId).get();
      print(
          '✅ DELETE DEBUG - After update - deleted field: ${updatedDoc.data()?['deleted']}');
      print('✅ DELETE DEBUG - After update - full data: ${updatedDoc.data()}');
    } catch (e) {
      print('❌ DELETE DEBUG - Error deleting message: $e');
      print('❌ DELETE DEBUG - Error type: ${e.runtimeType}');
      print('❌ DELETE DEBUG - Stack trace: ${e.toString()}');
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  String getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }
}
