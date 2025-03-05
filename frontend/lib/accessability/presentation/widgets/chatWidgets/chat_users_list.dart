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
        chatService.getSpaceChatRooms(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chats.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Map<String, dynamic>> usersInSameSpaces = snapshot.data![0];
        final List<Map<String, dynamic>> usersWithAcceptedRequests = snapshot.data![1];
        final List<Map<String, dynamic>> spaceChatRooms = snapshot.data![2];

        // Combine the lists and remove duplicates
        final Map<String, Map<String, dynamic>> uniqueUsers = {};

        for (var user in usersInSameSpaces) {
          uniqueUsers[user['uid']] = user;
        }

        for (var user in usersWithAcceptedRequests) {
          uniqueUsers[user['uid']] = user;
        }

        for (var space in spaceChatRooms) {
          uniqueUsers[space['id']] = {
            'uid': space['id'],
            'username': space['name'],
            'isSpaceChat': true,
          };
        }

        if (uniqueUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No chats available.'),
                SizedBox(height: 16),
                Text('Create or join a space to start chatting.'),
              ],
            ),
          );
        }

        // Separate space chats and individual users
        final List<Map<String, dynamic>> spaceChats = uniqueUsers.values
            .where((user) => user['isSpaceChat'] == true)
            .toList();
        final List<Map<String, dynamic>> individualUsers = uniqueUsers.values
            .where((user) => user['isSpaceChat'] != true)
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (spaceChats.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Space Chats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...spaceChats.map((userData) => _buildUserListItem(userData, context)),
              const Divider(thickness: 1, height: 20),
            ],
            if (individualUsers.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'People',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...individualUsers.map((userData) => _buildUserListItem(userData, context)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    final bool isSpaceChat = userData['isSpaceChat'] == true;
    final String profilePicture = isSpaceChat
        ? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389'
        : userData['profilePicture'] ?? 'https://via.placeholder.com/150';

    if (isSpaceChat) {
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(profilePicture),
        ),
        title: Text(
          userData['username'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Space Chat Room'),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/chatconvo',
            arguments: {
              'receiverUsername': userData['username'],
              'receiverID': userData['uid'],
              'isSpaceChat': true,
              'receiverProfilePicture': profilePicture,
            },
          );
        },
      );
    } else {
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
              username: userData['username'],
              lastMessage: lastMessage,
              lastMessageTime: lastMessageTime,
              profilePicture: profilePicture,
              onTap: () {
                Navigator.pushNamed(context, '/chatconvo', arguments: {
                  'receiverUsername': userData['username'],
                  'receiverID': userData['uid'],
                  'receiverProfilePicture': profilePicture,
                });
              },
            );
          },
        );
      } else {
        return const SizedBox.shrink();
      }
    }
  }

  String _getChatRoomID(String userID) {
    List<String> ids = [authService.getCurrentUser()!.uid, userID];
    ids.sort();
    return ids.join('_');
  }
}