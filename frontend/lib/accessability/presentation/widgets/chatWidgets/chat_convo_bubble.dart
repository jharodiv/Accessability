import 'package:flutter/material.dart';
import 'package:frontend/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';

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
    bool isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser 
        ? const Color(0xFF6750A4)
        : (isDarkMode ? const Color.fromARGB(255, 65, 63, 71) : const Color.fromARGB(255, 145, 141, 141)),
        borderRadius: BorderRadius.circular(12)
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
      child: Text(message, style: TextStyle(
        color: isCurrentUser 
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black)),
      ),
    );
  }
}