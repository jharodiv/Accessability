import 'package:flutter/material.dart';

class ChatUsersTile extends StatelessWidget {
  final String username;
  final String lastMessage;
  final String lastMessageTime;
  final String profilePicture; // Add profile picture URL
  final VoidCallback onTap;

  const ChatUsersTile({
    super.key,
    required this.username,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.profilePicture, // Add profile picture URL
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    
    const double tileHeight = 80.0;

    return Column(
      children: [
        Divider(
          color: Colors.grey[300],
          thickness: 1,
        ),
        Container(
          height: tileHeight, 
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profilePicture), 
            ),
            title: Expanded( 
              child: Text(
                username,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Expanded( 
              child: Text(
                lastMessage,
                overflow: TextOverflow.ellipsis, 
              ),
            ),
            trailing: Text(lastMessageTime),
            onTap: onTap,
            isThreeLine: true,
          ),
        ),
      ],
    );
  }
}
