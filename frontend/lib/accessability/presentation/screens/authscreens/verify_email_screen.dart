import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:AccessAbility/accessability/presentation/screens/authscreens/login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user;

  const VerifyEmailScreen({super.key, required this.user});

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  Timer? _resendTimer;
  bool _isResendDisabled = true;
  int _resendCountdown = 60;
  Future<void> _checkEmailVerification() async {
    await widget.user.reload();
    final updatedUser = FirebaseAuth.instance.currentUser;
    if (updatedUser != null && updatedUser.emailVerified) {
      await _firestore.collection('Users').doc(updatedUser.uid).update({
        'emailVerified': true,
      });

      _timer?.cancel();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
    }
  }

  void _startResendTimer() {
    _isResendDisabled = true;
    _resendCountdown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _isResendDisabled = false;
          _resendTimer?.cancel();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
    _startResendTimer();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              _firestore.collection('Users').doc(widget.user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('User data not found.');
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final isEmailVerified = userData['emailVerified'] ?? false;

            if (isEmailVerified) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              });

              return const Text(
                'Email verified! Redirecting to login...',
                style: TextStyle(fontSize: 18, color: Colors.green),
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Please verify your email address',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isResendDisabled
                      ? null
                      : () async {
                          await _checkEmailVerification();
                          _resendVerificationEmail();
                          _startResendTimer();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                  child: Text(
                    _isResendDisabled
                        ? 'Resend in $_resendCountdown seconds'
                        : 'Resend Verification Email',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    await widget.user.sendEmailVerification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent!')),
    );
  }
}
