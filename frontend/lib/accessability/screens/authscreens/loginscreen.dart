import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:frontend/accessability/widgets/authwidgets/authenticationImage.dart';
import 'package:frontend/accessability/widgets/authwidgets/loginform.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          bool isOverflowing = constraints.maxHeight < 600;

          return SingleChildScrollView(
            physics: isOverflowing
                ? AlwaysScrollableScrollPhysics()
                : NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthenticationImage(),
                const SizedBox(height: 90),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const Loginform(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
