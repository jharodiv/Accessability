import 'package:flutter/material.dart';
import 'package:Accessability/accessability/presentation/screens/authScreens/new_password.dart';

class Forgotpasswordconfirmation extends StatelessWidget {
  const Forgotpasswordconfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Please enter the email address associated with your account and we'll send you a link to reset your password",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Email Input Field
          SizedBox(
            width: double.infinity, // Makes it full-width
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: 25),

          // Continue Button
          SizedBox(
            width: double.infinity, // Makes it full-width
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Newpassword()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6750A4),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account?",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text(
                  'Signup',
                  style: TextStyle(
                    color: Color(0xFF6750A4),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
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
