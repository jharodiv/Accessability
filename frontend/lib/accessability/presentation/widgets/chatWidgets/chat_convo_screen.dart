import 'package:flutter/material.dart';

class ChatConvoScreen extends StatelessWidget {
  const ChatConvoScreen({super.key, required this.receiverEmail});

  final String receiverEmail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverEmail)),
    );
  }
}
