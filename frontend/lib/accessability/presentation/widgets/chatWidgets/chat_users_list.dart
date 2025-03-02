import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

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
    stream: CombineLatestStream.list([
      chatService.getUsersInSameSpaces(),
      chatService.getUsersWithAcceptedChatRequests(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Error');
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final List<Map<String, dynamic>> usersInSameSpaces = snapshot.data![0];
      final List<Map<String, dynamic>> usersWithAcceptedRequests = snapshot.data![1];

      // Combine the two lists and remove duplicates using a Map
      final Map<String, Map<String, dynamic>> uniqueUsers = {};

      for (var user in usersInSameSpaces) {
        uniqueUsers[user['uid']] = user;
      }

      for (var user in usersWithAcceptedRequests) {
        uniqueUsers[user['uid']] = user;
      }

      if (uniqueUsers.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No users found.'),
              SizedBox(height: 16),
              Text('Create or join a space in the main screen')
            ],
          ),
        );
      }

      // Sort users by the timestamp of their last message
      final sortedUsers = uniqueUsers.values.toList()
        ..sort((a, b) {
          final aLastMessage = a['lastMessageTimestamp'] ?? Timestamp(0, 0);
          final bLastMessage = b['lastMessageTimestamp'] ?? Timestamp(0, 0);
          return bLastMessage.compareTo(aLastMessage); // Sort in descending order
        });

      return ListView(
        children: sortedUsers
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
        Timestamp lastMessageTimestamp = Timestamp(0, 0);

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final messageData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          lastMessage = messageData['message'];
          lastMessageTime =
              DateFormat('hh:mm a').format(messageData['timestamp'].toDate());
          lastMessageTimestamp = messageData['timestamp'];
        }

        return ChatUsersTile(
          username: userData['username'], // Use username
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          profilePicture: userData['profilePicture'] ?? 'https://via.placeholder.com/150',
          onTap: () {
            Navigator.pushNamed(context, '/chatconvo', arguments: {
              'receiverUsername': userData['username'], // Pass username
              'receiverID': userData['uid'],
              'receiverProfilePicture': userData['profilePicture'],
            });
          },
        );
      },
    );
  } else {
    return const SizedBox.shrink();
  }
}
 String _getChatRoomID(String userID) {
    List<String> ids = [authService.getCurrentUser()!.uid, userID];
    ids.sort();
    return ids.join('_');
  }

}