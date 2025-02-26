import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Accessability/accessability/firebaseServices/models/message.dart';

class ChatService {
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get a stream of users
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return firebaseFirestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
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