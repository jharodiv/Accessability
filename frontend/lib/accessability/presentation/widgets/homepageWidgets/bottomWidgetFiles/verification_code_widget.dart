import 'package:flutter/material.dart';

class VerificationCodeWidget extends StatelessWidget {
  final String verificationCode;
  final VoidCallback onSendCode;

  const VerificationCodeWidget({
    super.key,
    required this.verificationCode,
    required this.onSendCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Invite members to the Space',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share your code out loud or send it in a message',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 213, 205, 237),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                verificationCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6750A4),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This code will be active for 5 hours',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onSendCode,
                child: const Text('Send code'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}