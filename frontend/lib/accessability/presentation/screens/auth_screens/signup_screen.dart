import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/widgets/auth_widgets/signup_form.dart';
import 'package:AccessAbility/accessability/presentation/widgets/auth_widgets/authentication_image.dart';

class SignupScreen extends StatelessWidget {
  static const String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthenticationImage(),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SignupForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
