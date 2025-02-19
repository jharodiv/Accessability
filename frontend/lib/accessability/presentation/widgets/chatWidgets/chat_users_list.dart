import 'package:flutter/material.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart';
import 'package:frontend/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';

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
          return const Center(child: Text('Error loading users'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final userData = snapshot.data![index];
            return _buildUserListItem(userData, context);
          },
        );
      },
    );
  }

  Widget _buildUserListItem(
      Map<String, dynamic> userData, BuildContext context) {
    if (userData['email'] != authService.getCurrentUser()!.email) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade200,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          userData['email'] ?? 'Unknown User',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          "Tap to chat",
          style: TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(Icons.chat, color: Colors.blueAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          Navigator.pushNamed(context, '/chatconvo', arguments: {
            'receiverEmail': userData['email'],
            'receiverID': userData['uid'],
          });
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
