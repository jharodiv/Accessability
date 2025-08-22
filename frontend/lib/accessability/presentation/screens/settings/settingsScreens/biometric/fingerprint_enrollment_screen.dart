import 'dart:io';
import 'package:AccessAbility/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_settings/app_settings.dart';
import 'package:android_intent_plus/android_intent.dart';

class FingerprintEnrollmentScreen extends StatefulWidget {
  const FingerprintEnrollmentScreen({super.key});

  @override
  _FingerprintEnrollmentScreenState createState() =>
      _FingerprintEnrollmentScreenState();
}

class _FingerprintEnrollmentScreenState
    extends State<FingerprintEnrollmentScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isEnrolling = false;

  /// Entry point for the enroll button.
  Future<void> _onEnrollPressed() async {
    setState(() {
      _isEnrolling = true;
    });

    try {
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (!isDeviceSupported ||
          !canCheckBiometrics ||
          availableBiometrics.isEmpty) {
        setState(() {
          _isEnrolling = false;
        });
        _showNoBiometricsDialog();
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: tr('fingerprintLocalizedReason'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      setState(() {
        _isEnrolling = false;
      });

      Navigator.pop(context, didAuthenticate);
    } catch (e) {
      setState(() {
        _isEnrolling = false;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('error'.tr()),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }
  }

  /// Use the custom ErrorDisplayWidget when there are no enrolled biometrics.
  void _showNoBiometricsDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ErrorDisplayWidget(
          title: tr('noBiometricsTitle'),
          message: tr('noBiometricsMessage'),

          // Cancel on the left:
          secondaryLabel: tr('cancel'),
          secondaryOnPressed: () {
            Navigator.of(context).pop();
          },

          // Open settings on the right (primary) — primary is typically rendered bold/prominent.
          primaryLabel: tr('openSettings'),
          primaryOnPressed: () {
            Navigator.of(context).pop();
            _openSettings();
          },
        );
      },
    );
  }

  /// Single _openSettings method that uses android_intent_plus where useful,
  /// and falls back to AppSettings.openAppSettings() for other platforms.
  void _openSettings() async {
    if (kIsWeb) return AppSettings.openAppSettings();

    if (Platform.isAndroid) {
      try {
        // Try direct biometric enrollment (Android 11+ / API 30+).
        final enrollIntent =
            AndroidIntent(action: 'android.settings.BIOMETRIC_ENROLL');
        await enrollIntent.launch();
        return;
      } catch (_) {
        // If BIOMETRIC_ENROLL isn't available, try opening security settings.
        try {
          final secIntent =
              AndroidIntent(action: 'android.settings.SECURITY_SETTINGS');
          await secIntent.launch();
          return;
        } catch (_) {
          // fallback to app settings
          AppSettings.openAppSettings();
          return;
        }
      }
    }

    // iOS and other platforms: open the app settings (iOS cannot deep-link to Face/Touch ID pages)
    AppSettings.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            title: Text(
              tr('enrollFingerprintTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 100,
              color: Color(0xFF6750A4),
            ),
            const SizedBox(height: 20),
            Text(
              tr('fingerprintInstruction'),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _isEnrolling
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _onEnrollPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      tr('enrollFingerprintButton'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
