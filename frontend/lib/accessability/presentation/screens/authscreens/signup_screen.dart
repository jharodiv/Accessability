import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/widgets/authwidgets/authentication_Image.dart';
import 'package:frontend/accessability/presentation/widgets/authwidgets/signup_form.dart';

class SignupScreen extends StatelessWidget {
  static const String routeName =
      '/signup'; // Define route name for named routing

  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isOverflowing = constraints.maxHeight < 600;

            return SingleChildScrollView(
              physics: isOverflowing
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthenticationImage(),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Signupform(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
