import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; 

class ChatConvoBubble extends StatefulWidget {
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
  _ChatConvoBubbleState createState() => _ChatConvoBubbleState();
}

class _ChatConvoBubbleState extends State<ChatConvoBubble> {
  bool _showTimestamp = false; // State variable to track visibility of timestamp

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    String formattedTime = DateFormat('hh:mm a').format(widget.timestamp.toDate()); // Format the timestamp

    return GestureDetector(
      onTap: () {
        setState(() {
          _showTimestamp = !_showTimestamp; // Toggle the visibility of the timestamp
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isCurrentUser   
          ? const Color(0xFF6750A4)
          : (isDarkMode ? const Color.fromARGB(255, 65, 63, 71) : const Color.fromARGB(255, 145, 141, 141)),
          borderRadius: BorderRadius.circular(12)
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: TextStyle(
              color: widget.isCurrentUser   
              ? Colors.white
              : (isDarkMode ? Colors.white : Colors.black)),
            ),
            const SizedBox(height: 4), // Add some space between message and time
            if (_showTimestamp) // Only show the timestamp if _showTimestamp is true
              Text(formattedTime, style: TextStyle(
                color: widget.isCurrentUser   ? Colors.white70 : Colors.black54, 
                fontSize: 12,
              )),
          ],
        ),
      ),
    );
  }
}