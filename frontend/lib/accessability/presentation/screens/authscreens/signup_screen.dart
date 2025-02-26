import 'package:flutter/material.dart';
import 'package:Accessability/accessability/presentation/widgets/authWidgets/signup_form.dart';
import 'package:Accessability/accessability/presentation/widgets/authwidgets/authentication_Image.dart';

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
