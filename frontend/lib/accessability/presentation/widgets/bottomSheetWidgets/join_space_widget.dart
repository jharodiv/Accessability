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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Main heading
          const Text(
            'Enter the Invite Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Subheading or helper text
          const Text(
            'Get the code from the person setting up your Space',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          // Code input fields
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First 3 fields
              for (int i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
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
                  width: 40,
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
          ),
          const SizedBox(height: 24),
          // Submit and Back buttons
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onJoinSpace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6750A4)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Color(0xFF6750A4)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
