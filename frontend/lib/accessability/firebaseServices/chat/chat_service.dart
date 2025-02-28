import 'package:AccessAbility/accessability/firebaseServices/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
} 