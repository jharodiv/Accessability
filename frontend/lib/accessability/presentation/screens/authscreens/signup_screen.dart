import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/widgets/authWidgets/signup_form.dart';
import 'package:AccessAbility/accessability/presentation/widgets/authwidgets/authentication_Image.dart';

class SignupScreen extends StatelessWidget {
  static const String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); 
          },
        ),
      ),
      body: const SafeArea(
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
