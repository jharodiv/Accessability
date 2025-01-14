import 'package:flutter/material.dart';

class Chatandsupport extends StatelessWidget {
  const Chatandsupport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back)),
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
