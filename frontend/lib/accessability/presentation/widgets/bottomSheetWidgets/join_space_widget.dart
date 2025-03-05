import 'package:flutter/material.dart';

class JoinSpaceWidget extends StatelessWidget {
  final List<TextEditingController> verificationCodeControllers;
  final List<FocusNode> verificationCodeFocusNodes;
  final VoidCallback onJoinSpace;
  final VoidCallback onCancel;

  const JoinSpaceWidget({
    Key? key,
    required this.verificationCodeControllers,
    required this.verificationCodeFocusNodes,
    required this.onJoinSpace,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          const Text(
            'Enter the Invite Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Subheading
          const Text(
            'Get the code from the person setting up your Space',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Code Input Fields
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the width of each TextField dynamically
              final textFieldWidth = constraints.maxWidth * 0.12;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First 3 fields
                  for (int i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: textFieldWidth,
                      child: TextField(
                        controller: verificationCodeControllers[i],
                        focusNode: verificationCodeFocusNodes[i],
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Text('-', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  // Last 3 fields
                  for (int i = 3; i < 6; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: textFieldWidth,
                      child: TextField(
                        controller: verificationCodeControllers[i],
                        focusNode: verificationCodeFocusNodes[i],
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onJoinSpace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Submit',
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