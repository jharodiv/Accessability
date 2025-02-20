import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart';
import 'package:frontend/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';
import 'package:intl/intl.dart';

class ChatUsersList extends StatelessWidget {
  ChatUsersList({super.key});
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: chatService.getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        }

        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    if (userData['email'] != authService.getCurrentUser()!.email) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_getChatRoomID(userData['uid']))
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          String lastMessage = '';
          String lastMessageTime = '';

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            lastMessage = messageData['message'];
            lastMessageTime = DateFormat('hh:mm a').format(messageData['timestamp'].toDate());
          }

          return ChatUsersTile(
            email: userData['email'],
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            onTap: () {
              Navigator.pushNamed(context, '/chatconvo', arguments: {
                'receiverEmail': userData['email'],
                'receiverID': userData['uid'],
              });
            },
          );
        },
      );
    } else {
      return Container();
    }
  }

  String _getChatRoomID(String userID) {
    List<String> ids = [authService.getCurrentUser()!.uid, userID];
    ids.sort();
    return ids.join('_');
  }
}