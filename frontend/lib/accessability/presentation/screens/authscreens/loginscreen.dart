import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:frontend/accessability/presentation/widgets/authwidgets/authenticationImage.dart';
import 'package:frontend/accessability/presentation/widgets/authwidgets/loginform.dart';

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
                SizedBox(height: 90),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Loginform(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
