import 'package:flutter/material.dart';
import 'package:accessability/accessability/presentation/widgets/auth_widgets/login_form.dart';
import 'package:accessability/accessability/presentation/widgets/auth_widgets/authentication_image.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthenticationImage(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: LoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
