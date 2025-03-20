import 'package:AccessAbility/accessability/firebaseServices/models/message.dart';
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
        final data = doc.data() as Map<String, dynamic>;
        final senderID = data['senderID'];
        final receiverID = data['receiverID'];

        // Fetch the other user's data (either sender or receiver)
        final otherUserID = senderID == currentUserID ? receiverID : senderID;

        final userSnapshot = await firebaseFirestore
            .collection('Users')
            .doc(otherUserID)
            .get();

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
      final spaceData = spaceDoc.data() as Map<String, dynamic>;
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
  Future<void> sendMessage(String chatId, String message, {bool isSpaceChat = false}) async {
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

  // Accept a chat request and create a chat room with the last message
  Future<void> acceptChatRequest(String requestID) async {
    final requestSnapshot = await firebaseFirestore
        .collection('chat_requests')
        .doc(requestID)
        .get();

    if (!requestSnapshot.exists) return;

    final requestData = requestSnapshot.data() as Map<String, dynamic>;
    final senderID = requestData['senderID'];
    final receiverID = requestData['receiverID'];
    final message = requestData['message'];
    final timestamp = requestData['timestamp'];

    // Create a chat room if it doesn't exist
    List<String> ids = [senderID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).set({
      'participants': [senderID, receiverID],
      'createdAt': timestamp,
    });

    // Add the last message from the chat request as the first message in the chat room
    await firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add({
      'senderID': senderID,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
    });

    // Mark the chat request as accepted
    await firebaseFirestore.collection('chat_requests').doc(requestID).update({
      'status': 'accepted',
    });
  }

  // Reject a chat request
  Future<void> rejectChatRequest(String requestID) async {
    await firebaseFirestore.collection('chat_requests').doc(requestID).update({
      'status': 'rejected',
    });
  }

  // Get pending chat requests for the current user
  Stream<QuerySnapshot> getPendingChatRequests() {
    final String receiverID = _auth.currentUser!.uid;
    return firebaseFirestore
        .collection('chat_requests')
        .where('receiverID', isEqualTo: receiverID)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
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

    final snapshot = await firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .get();

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

    // Send a welcome message to the space chat room
    await sendMessage(spaceId, 'Welcome to the $spaceName space!', isSpaceChat: true);
  }

  // Add a member to the space chat room and create chat rooms with all members
  Future<void> addMemberToSpaceChatRoom(String spaceId, String userId) async {
  // Fetch the user's data from Firestore
  final userSnapshot = await firebaseFirestore.collection('Users').doc(userId).get();
  if (!userSnapshot.exists) return;

  final username = userSnapshot.data()?['username'] ?? 'Unknown User';

  // Check if the space chat room exists
  final spaceSnapshot = await firebaseFirestore.collection('space_chat_rooms').doc(spaceId).get();
  if (!spaceSnapshot.exists) return;

  final spaceName = spaceSnapshot['name'] ?? 'Unnamed Space';

  // Add the user to the space chat room members list
  await firebaseFirestore.collection('space_chat_rooms').doc(spaceId).update({
    'members': FieldValue.arrayUnion([userId]),
  });

  // Send a message indicating the user has joined the space
  await sendMessage(spaceId, '$username has joined the space!', isSpaceChat: true);

  // Create chat rooms for the new member with all existing members
  await createChatRoomsForNewMember(spaceId, userId, spaceName);
}

Future<void> createChatRoomForMembers(String userID1, String userID2, String spaceName) async {
  List<String> ids = [userID1, userID2];
  ids.sort();
  String chatRoomID = ids.join('_');

  // Check if the chat room already exists
  final chatRoomSnapshot = await firebaseFirestore.collection('chat_rooms').doc(chatRoomID).get();
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
 Future<void> createChatRoomsForNewMember(String spaceId, String newMemberId, String spaceName) async {
  // Fetch all members in the space
  final spaceSnapshot = await firebaseFirestore.collection('space_chat_rooms').doc(spaceId).get();
  if (!spaceSnapshot.exists) return;

  final members = List<String>.from(spaceSnapshot['members'] ?? []);

  // Create chat rooms between the new member and all existing members
  for (final memberId in members) {
    if (memberId != newMemberId) {
      await createChatRoomForMembers(newMemberId, memberId, spaceName);
    }
  }
}

  // Get messages for a chat room (handles both space and private chat rooms)
  Stream<QuerySnapshot> getMessages(String receiverID, {bool isSpaceChat = false}) {
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
 Future<void> _acceptPendingChatRequests(String userID1, String userID2) async {
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
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'],
        'createdAt': doc['createdAt'],
      };
    }).toList();
  });
}
}