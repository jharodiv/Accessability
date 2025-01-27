import 'package:flutter/material.dart';

class ChatConvoBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser,
    required this.message
    });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFF6750A4) : Colors.grey.shade500,
        borderRadius: BorderRadius.circular(12)
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
      child: Text(message, style: const TextStyle(color: Colors.white),)
    );
  }
}