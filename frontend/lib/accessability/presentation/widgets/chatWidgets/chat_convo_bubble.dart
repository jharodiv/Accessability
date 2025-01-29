// chat_convo_bubble.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; 

class ChatConvoBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser ;
  final Timestamp timestamp; // Add timestamp field

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser ,
    required this.message,
    required this.timestamp, 
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    String formattedTime = DateFormat('hh:mm a').format(timestamp.toDate()); // Format the timestamp

    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser  
        ? const Color(0xFF6750A4)
        : (isDarkMode ? const Color.fromARGB(255, 65, 63, 71) : const Color.fromARGB(255, 145, 141, 141)),
        borderRadius: BorderRadius.circular(12)
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(
            color: isCurrentUser  
            ? Colors.white
            : (isDarkMode ? Colors.white : Colors.black)),
          ),
          const SizedBox(height: 4), // Add some space between message and time
          Text(formattedTime, style: TextStyle(
            color: isCurrentUser  ? Colors.white70 : Colors.black54, 
            fontSize: 12,
          )),
        ],
      ),
    );
  }
}