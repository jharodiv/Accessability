import 'package:flutter/material.dart';
import 'package:frontend/accessability/widgets/authwidgets/authenticationImage.dart';
import 'package:frontend/accessability/widgets/authwidgets/signupform.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthenticationImage(), // Displays the login image
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const Signupform(), // Displays the login form
              ),
            ],
          ),
        ),
      ),
    );
  }
}