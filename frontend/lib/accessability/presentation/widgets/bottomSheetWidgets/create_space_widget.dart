import 'package:flutter/material.dart';

class CreateSpaceWidget extends StatefulWidget {
  const CreateSpaceWidget({Key? key}) : super(key: key);

  @override
  State<CreateSpaceWidget> createState() => _CreateSpaceWidgetState();
}

class _CreateSpaceWidgetState extends State<CreateSpaceWidget> {
  final TextEditingController _spaceNameController = TextEditingController();

  @override
  void dispose() {
    _spaceNameController.dispose();
    super.dispose();
  }

  // Example create action
  void _createSpace() {
    final spaceName = _spaceNameController.text;
    // Replace with your create-space logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Space Created: $spaceName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with back button on the right side
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Remove default left back arrow
        leading: const SizedBox.shrink(),
        centerTitle: true,
        title: const Text(
          'Create my Space',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            TextField(
              controller: _spaceNameController,
              decoration: const InputDecoration(
                labelText: 'Space Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createSpace,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6750A4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Back',
                style: TextStyle(
                  color: Color(0xFF6750A4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
