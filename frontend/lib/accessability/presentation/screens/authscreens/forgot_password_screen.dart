import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/presentation/widgets/accessability_header.dart';
import 'package:AccessAbility/accessability/presentation/widgets/authWidgets/forgot_password_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();

  ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // reset the auth state so no stale failure is hanging around
            context.read<AuthBloc>().add(ResetAuthState());
            Navigator.pop(context);
          },
        ),
      ),
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
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Forgotpasswordconfirmation(
                        emailController: emailController),
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
