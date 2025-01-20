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
            return const Text('Error');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }

          return ListView(
            children: snapshot.data!
                .map<Widget>(
                    (userData) => _buildUserListItem(userData, context))
                .toList(),
          );
        });
  }

  Widget _buildUserListItem(
      Map<String, dynamic> userData, BuildContext context) {
    if (userData['email'] != authService.getCurrentUser()!.email) {
      return ChatUsersTile(
        text: userData['email'],
        onTap: () {
          Navigator.pushNamed(context, '/chatconvo',
              arguments: {'receiverEmail': userData['email']});
        },
      );
    } else {
      return Container();
    }
  }
}
