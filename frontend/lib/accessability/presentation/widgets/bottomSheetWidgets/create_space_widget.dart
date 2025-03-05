import 'package:flutter/material.dart';

class CreateSpaceWidget extends StatelessWidget {
  final TextEditingController spaceNameController;
  final VoidCallback onCreateSpace;
  final VoidCallback onCancel;

  const CreateSpaceWidget({
    Key? key,
    required this.spaceNameController,
    required this.onCreateSpace,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          const Text(
            'Create my space',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Space Name Input
          TextField(
            controller: spaceNameController,
            decoration: const InputDecoration(
              labelText: 'Space Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCreateSpace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Create',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6750A4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Back',
                      style: TextStyle(color: Color(0xFF6750A4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}