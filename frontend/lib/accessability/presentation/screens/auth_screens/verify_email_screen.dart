import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:accessability/accessability/presentation/screens/auth_screens/login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user;

  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Timer? _timer;
  Timer? _resendTimer;

  bool _isResendDisabled = true;
  int _resendCountdown = 60;
  bool _navigated = false;

  DocumentSnapshot? _cachedSnapshot; // cache to prevent spinner flicker

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
    _startResendTimer();

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    await widget.user.reload();
    final updatedUser = FirebaseAuth.instance.currentUser;

    if (updatedUser != null && updatedUser.emailVerified && !_navigated) {
      _navigated = true;

      await _firestore.collection('Users').doc(updatedUser.uid).update({
        'emailVerified': true,
      });

      _timer?.cancel();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        });
      }
    }
  }

  void _startResendTimer() {
    setState(() {
      _isResendDisabled = true;
      _resendCountdown = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
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

  Future<void> _resendVerificationEmail() async {
    await widget.user.sendEmailVerification();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Verification email sent!'),
        backgroundColor: const Color(0xFF6750A4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        body: Center(
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                _firestore.collection('Users').doc(widget.user.uid).snapshots(),
            builder: (context, snapshot) {
              // Cache first successful snapshot to avoid flicker
              if (snapshot.hasData && snapshot.data != null) {
                _cachedSnapshot = snapshot.data;
              }

              // Use cached snapshot if available, even if waiting
              final effectiveSnapshot = snapshot.hasData
                  ? snapshot
                  : (_cachedSnapshot != null
                      ? AsyncSnapshot.withData(
                          ConnectionState.active, _cachedSnapshot!)
                      : snapshot);

              if (!effectiveSnapshot.hasData ||
                  !(effectiveSnapshot.data!.exists)) {
                return const Text('User data not found.');
              }

              final userData =
                  effectiveSnapshot.data!.data() as Map<String, dynamic>;
              final isEmailVerified = userData['emailVerified'] ?? false;

              if (isEmailVerified) {
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
                            await _resendVerificationEmail();
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
      ),
    );
  }
}
