import 'dart:math';

import 'package:accessability/accessability/data/model/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Send a chat request
  Future<void> sendChatRequest(String receiverID, String message) async {
    final String senderID = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    await firebaseFirestore.collection('chat_requests').add({
      'senderID': senderID,
      'receiverID': receiverID,
      'message': message,
      'status': 'pending',
      'timestamp': timestamp,
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
    print('Accepting chat request with ID: $requestID'); // Add debug print

    if (requestID.isEmpty) {
      print('Error: Request ID is empty');
      throw Exception('Request ID cannot be empty');
    }

    final requestSnapshot = await firebaseFirestore
        .collection('chat_requests')
        .doc(requestID)
        .get();

    print('Request snapshot exists: ${requestSnapshot.exists}'); // Debug

    if (!requestSnapshot.exists) {
      print('Error: Chat request document does not exist');
      return;
    }

    final requestData = requestSnapshot.data() as Map<String, dynamic>;
    final senderID = requestData['senderID'];
    final receiverID = requestData['receiverID'];
    final message = requestData['message'];
    final timestamp = requestData['timestamp'];
    final metadata = requestData['metadata']; // Preserve metadata

    print('Sender: $senderID, Receiver: $receiverID'); // Debug

    // Create a chat room if it doesn't exist
    List<String> ids = [senderID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).set({
      'participants': [senderID, receiverID],
      'createdAt': timestamp,
    });

    // Add the message with preserved metadata
    await firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add({
      'senderID': senderID,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
      'metadata': metadata, // Preserve metadata
    });

    // Mark the chat request as accepted
    await firebaseFirestore.collection('chat_requests').doc(requestID).update({
      'status': 'accepted',
    });

    print('Chat request accepted successfully');
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
        .orderBy('timestamp', descending: true)
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
          .orderBy('timestamp', descending: false)
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
          .orderBy('timestamp', descending: false)
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

    // Get or generate verification code
    final spaceSnapshot =
        await firebaseFirestore.collection('Spaces').doc(spaceId).get();
    String verificationCode;
    DateTime codeTimestamp;

    if (spaceSnapshot.exists) {
      final existingCode = spaceSnapshot['verificationCode'];
      final existingTimestamp = spaceSnapshot['codeTimestamp']?.toDate();

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
      'codeTimestamp': codeTimestamp,
    });

    // Prepare metadata for verification code
    final metadata = {
      'type': 'verification_code',
      'spaceId': spaceId,
      'verificationCode': verificationCode,
      'spaceName': spaceName,
      'expiresAt': codeTimestamp.add(Duration(minutes: 10)).toIso8601String(),
      'requestId': '', // This will be populated when sending as chat request
    };

    final message =
        'Join $spaceName! Verification code: $verificationCode (Expires in 10 minutes)';

    // Use the unified method to send with metadata
    await _sendMessageWithMetadata(receiverID, message, metadata);
  }

  Future<void> _sendMessageWithMetadata(
      String receiverID, String message, Map<String, dynamic> metadata) async {
    final String senderID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Check if chat room exists
    final bool chatRoomExists = await hasChatRoom(senderID, receiverID);

    if (chatRoomExists) {
      // Send to existing chat room - we need to generate a unique ID for this case
      List<String> ids = [senderID, receiverID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // Generate a unique ID for this verification message
      final messageId = _generateMessageId();

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
          ...metadata,
          'requestId': messageId, // Use generated ID for chat room messages
        },
      });
    } else {
      // Send as chat request with metadata - use a document reference with known ID
      final newDocRef = firebaseFirestore.collection('chat_requests').doc();

      await newDocRef.set({
        'senderID': senderID,
        'receiverID': receiverID,
        'message': message,
        'status': 'pending',
        'timestamp': timestamp,
        'metadata': {
          ...metadata,
          'requestId': newDocRef.id, // Use the document ID for chat requests
        },
      });
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
    try {
      final spaceDoc =
          await firebaseFirestore.collection('Spaces').doc(spaceId).get();
      if (spaceDoc.exists) {
        final members = List<String>.from(spaceDoc['members'] ?? []);
        return members.contains(userId);
      }
      return false;
    } catch (e) {
      print('Error checking space membership: $e');
      return false;
    }
  }
}
