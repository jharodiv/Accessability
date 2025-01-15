import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/forgotpasswordscreen.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/signupscreen.dart';
import 'package:frontend/accessability/presentation/screens/gpsscreen/gps.dart';

class Loginform extends StatelessWidget {
  const Loginform({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 10), // Reduced height
                Container(
                  height: 80,
                  child: Stack(
                    children: [
                      const TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.black, width: 3.0),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -13,
                        right: 0,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF6750A4),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10), // Reduced height
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/onboarding');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 50),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5), // Reduced height
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xFF6750A4),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
