import 'package:flutter/material.dart';

class JoinSpaceWidget extends StatefulWidget {
  const JoinSpaceWidget({Key? key}) : super(key: key);

  @override
  State<JoinSpaceWidget> createState() => _JoinSpaceWidgetState();
}

class _JoinSpaceWidgetState extends State<JoinSpaceWidget> {
  // 6 controllers for the 6 code fields
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  // 6 focus nodes for auto-focusing the next field
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _setupFocusNodes();
  }

  void _setupFocusNodes() {
    for (int i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.isNotEmpty &&
            i < _codeControllers.length - 1) {
          FocusScope.of(context).requestFocus(_codeFocusNodes[i + 1]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Example submit action
  void _submitCode() {
    final code = _codeControllers.map((c) => c.text).join();
    // Replace with your join-space logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code entered: $code')),
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
          'Join a Space',
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
            const Text(
              'Enter the Invite Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Row for 6 code boxes with a dash in between
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // First 3 fields
                for (int i = 0; i < 3; i++) _buildCodeBox(i),
                const SizedBox(width: 8),
                const Text('-', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                // Last 3 fields
                for (int i = 3; i < 6; i++) _buildCodeBox(i),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Get the code from the person setting up your Space',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _submitCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6750A4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'Join',
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

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          counterText: '',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
