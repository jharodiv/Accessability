import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/widgets/authWidgets/login_form.dart';
import 'package:AccessAbility/accessability/presentation/widgets/authwidgets/authentication_Image.dart';

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
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
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
          );
        }),
      ),
    );
  }
}
