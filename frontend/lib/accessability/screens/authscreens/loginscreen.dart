import 'package:flutter/material.dart';
import 'package:frontend/accessability/widgets/authwidgets/authenticationImage.dart';
import 'package:frontend/accessability/widgets/authwidgets/loginform.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthenticationImage(),
              const SizedBox(height: 70),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const Loginform(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
