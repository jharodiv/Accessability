import 'package:flutter/material.dart';

class ChatUsersTile extends StatelessWidget {
  final String email;
  final String lastMessage;
  final String lastMessageTime;
  final String profilePicture; // Add profile picture URL
  final VoidCallback onTap;

  const ChatUsersTile({
    super.key,
    required this.email,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.profilePicture, // Add profile picture URL
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
          color: Colors.grey[300],
          thickness: 1,
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profilePicture), // Display profile picture
          ),
          title: Text(email),
          subtitle: Text(lastMessage),
          trailing: Text(lastMessageTime),
          onTap: onTap,
        ),
      ],
    );
  }
}