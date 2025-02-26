import 'package:flutter/material.dart';
import 'package:Accessability/accessability/presentation/widgets/accessability_header.dart';
import 'package:Accessability/accessability/presentation/widgets/authwidgets/forgot_password_confirmation.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Accessabilityheader(),
                  const SizedBox(height: 70),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Forgotpasswordconfirmation(),
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
