import 'package:AccessAbility/accessability/firebaseServices/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

   // Get users with accepted chat requests
  Stream<List<Map<String, dynamic>>> getUsersWithAcceptedChatRequests() {
    final String currentUserID = _auth.currentUser!.uid;

    return firebaseFirestore
        .collection('chat_requests')
        .where('status', isEqualTo: 'accepted')
        .where('receiverID', isEqualTo: currentUserID)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final senderID = data['senderID'];

        final userSnapshot = await firebaseFirestore
            .collection('Users')
            .doc(senderID)
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

      final usersSnapshot = await firebaseFirestore
          .collection('Users')
          .where('uid', whereIn: userIds.toList())
          .get();

      return usersSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // Send a message
  Future<void> sendMessage(String receiverID, message) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
    );

    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add(newMessage.toMap());
  }

  // Get messages for a chat room
  Stream<QuerySnapshot> getMessages(String userID, otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .orderBy('timestamp', descending: false) // Ensure ascending order
        .snapshots();
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

} 