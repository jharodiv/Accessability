import 'package:AccessAbility/accessability/presentation/widgets/shimmer/shimmer_change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/auth_screens/forgot_password_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isRetypePasswordVisible = false;
  String? _currentPasswordError;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleChangePassword() {
    setState(() {
      // clear any previous field error:
      _currentPasswordError = null;
    });

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters long.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Dispatch the ChangePasswordEvent to the AuthBloc
    context.read<AuthBloc>().add(ChangePasswordEvent(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() {
            _isLoading = true;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
        if (state is AuthSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          // Set loading to true so the shimmer is shown
          setState(() {
            _isLoading = true;
          });
          // After a short delay, dispatch LogoutEvent and navigate to the root route "/"
          Future.delayed(const Duration(seconds: 2), () {
            context.read<AuthBloc>().add(LogoutEvent());
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          });
        } else if (state is AuthError) {
          if (state.message == 'Current password is incorrect.') {
            // 1. Show inline under field
            setState(() => _currentPasswordError = state.message);
            // 2. Also show a SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: _isLoading
          ? const ShimmerChangePasswordScreen()
          : Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(65),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: AppBar(
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF6750A4),
                    ),
                    title: const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    centerTitle: true,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 32.0),
                      child: Column(
                        children: [
                          // Current Password
                          TextField(
                            controller: _currentPasswordController,
                            obscureText: !isCurrentPasswordVisible,
                            decoration: InputDecoration(
                              isDense: true,
                              errorText: _currentPasswordError, // ← add this
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              labelText: 'Current Password',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.deepPurple),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isCurrentPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isCurrentPasswordVisible =
                                        !isCurrentPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // New Password
                          TextField(
                            controller: _newPasswordController,
                            obscureText: !isNewPasswordVisible,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              labelText: 'New Password',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.deepPurple),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isNewPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isNewPasswordVisible =
                                        !isNewPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Re-type New Password
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: !isRetypePasswordVisible,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              labelText: 'Re-type New Password',
                              labelStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.deepPurple),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isRetypePasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isRetypePasswordVisible =
                                        !isRetypePasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Requirements Heading
                          const Row(
                            children: [
                              Text(
                                'Your new password must have:',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Requirements List
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  'At least 8 characters',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  '1 letter and 1 number',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  '1 special character (Ex: ? # ! * % \$ @ & )',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 80),
                          // Save Button
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: _handleChangePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6750A4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Forgot Password Button
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF6750A4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
