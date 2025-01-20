import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/settings/settings_screen.dart';

class ChatAndSupport extends StatelessWidget {
  const ChatAndSupport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Chat and Support',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Text('Chat and Support'),
      ),
    );
  }
}
