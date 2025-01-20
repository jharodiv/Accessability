import 'package:flutter/material.dart';

class ChatAndSupport extends StatelessWidget {
  const ChatAndSupport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.popAndPushNamed(context, '/settings');
            },
            icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Chat and Support',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
