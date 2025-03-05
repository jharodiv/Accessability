import 'package:flutter/material.dart';

class ChatUsersTile extends StatelessWidget {
  final String username;
  final String lastMessage;
  final String lastMessageTime;
  final String profilePicture;
  final VoidCallback onTap;

  const ChatUsersTile({
    super.key,
    required this.username,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.profilePicture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profilePicture),
          ),
          title: Text(
            username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMessage,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: Text(
            lastMessageTime,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}