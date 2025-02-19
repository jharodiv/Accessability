import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_event.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/forgot_password_screen.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:local_auth/local_auth.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _hasNavigated = false;
  bool isBiometricEnabled = true; // Replace this with actual settings value
  late final LocalAuthentication _localAuth;
  bool _supportState = false;

  @override
  void initState() {
    super.initState();
    _localAuth = LocalAuthentication();
    _localAuth.isDeviceSupported().then(
          (bool isSupported) => setState(
            () {
              _supportState = isSupported;
            },
          ),
        );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) {
    final email = emailController.text;
    final password = passwordController.text;
    context.read<AuthBloc>().add(LoginEvent(email: email, password: password));
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool isAvailable = await _localAuth.canCheckBiometrics;
      bool didAuthenticate = false;

      if (isAvailable) {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          // Simulate successful login
          context.read<AuthBloc>().add(LoginWithBiometricEvent());
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Biometric authentication not available')),
        );
      }
    } catch (e) {
      print('Error using biometrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthenticatedLogin) {
              context.read<UserBloc>().add(FetchUserData());
            } else if (state is AuthError) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Login Failed'),
                  content: Text(state.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        BlocListener<UserBloc, UserState>(
          listener: (context, userState) {
            if (userState is UserLoaded) {
              final authState = context.read<AuthBloc>().state;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    authState is AuthenticatedLogin &&
                    !_hasNavigated) {
                  _hasNavigated = true;
                  if (authState.hasCompletedOnboarding) {
                    Navigator.pushReplacementNamed(context, '/homescreen');
                  } else {
                    Navigator.pushReplacementNamed(context, '/onboarding');
                  }
                }
              });
            }
          },
        ),
      ],
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                        fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                            color: Color(0xFF6750A4),
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      minimumSize: const Size(250, 50),
                      textStyle: const TextStyle(fontSize: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignupScreen()),
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                              color: Color(0xFF6750A4),
                              fontWeight: FontWeight.w800,
                              fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  GestureDetector(
                    onTap: _authenthicate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fingerprint,
                            size: 30, color: Color(0xFF6750A4)),
                        const SizedBox(width: 8),
                        Text(
                          isBiometricEnabled
                              ? 'Biometric Login Enabled'
                              : 'Login with Biometrics',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _authenthicate() async {
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Try',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      print(e);
    }
  }
}
