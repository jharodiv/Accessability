import 'package:accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:accessability/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'dart:async';

class Forgotpasswordconfirmation extends StatefulWidget {
  final TextEditingController emailController;

  const Forgotpasswordconfirmation({super.key, required this.emailController});

  @override
  _ForgotpasswordconfirmationState createState() =>
      _ForgotpasswordconfirmationState();
}

class _ForgotpasswordconfirmationState
    extends State<Forgotpasswordconfirmation> {
  bool isButtonDisabled = false;
  int remainingTime = 60; // Duration for the countdown (in seconds)
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel(); // Only cancel if timer was initialized
    super.dispose();
  }

  void _onContinuePressed(BuildContext context) {
    final email = widget.emailController.text.trim();

    if (email.isNotEmpty) {
      // Disable the button and start the countdown
      setState(() {
        isButtonDisabled = true;
      });

      // Trigger the event to send the reset password link
      context.read<AuthBloc>().add(ForgotPasswordEvent(email));

      // Start the timer to enable the button after 1 minute
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (remainingTime > 0) {
          setState(() {
            remainingTime--;
          });
        } else {
          _timer?.cancel(); // Only cancel if timer was initialized
          setState(() {
            isButtonDisabled = false;
          });
        }
      });

      // Optionally, show a snackbar or other UI feedback that the request is sent
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ForgotPasswordSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is ForgotPasswordFailure) {
          showDialog(
            context: context,
            builder: (_) => ErrorDisplayWidget(
              title: 'Reset Failed',
              message: state.errorMessage,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Please enter the email address associated with your account and we'll send you a link to reset your password",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Email Input Field
            SizedBox(
              width: double.infinity, // Makes it full-width
              child: TextField(
                controller: widget.emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 25),

            // Continue Button with countdown
            SizedBox(
              width: double.infinity, // Makes it full-width
              child: Semantics(
                label: 'Continue',
                child: ElevatedButton(
                  onPressed: isButtonDisabled
                      ? null // Disable the button if the timer is running
                      : () => _onContinuePressed(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: isButtonDisabled
                      ? Text(
                          'Please wait... ${remainingTime}s',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/signup');
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Color(0xFF6750A4),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
