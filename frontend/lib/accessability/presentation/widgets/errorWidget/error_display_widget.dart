import 'package:flutter/material.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String title;
  final String message;

  const ErrorDisplayWidget({
    Key? key,
    required this.title,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Rounded corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      backgroundColor:
          const Color.fromARGB(255, 246, 244, 244).withOpacity(0.95),

      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1️⃣ The main body: title, message, OK button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Color(0xFF6750A4),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2️⃣ The logo circle, overlapping the top border
          Positioned(
            top: -40,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Image.asset(
                'assets/images/authentication/authenticationImage.png',
                width: 60,
                height: 60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
