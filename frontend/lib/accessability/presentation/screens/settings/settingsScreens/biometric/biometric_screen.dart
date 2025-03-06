import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/data/model/user_model.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/biometric/fingerprint_enrollment_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  _BiometricScreenState createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool isBiometricEnabled = false;
  String? _deviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getDeviceId();
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceId = androidInfo.id;
      });
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceId = iosInfo.identifierForVendor;
      });
    }
  }

  Future<void> _showDisableBiometricDialog(BuildContext context, UserModel user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disable Biometric Login'),
          content: const Text(
            'Are you sure you want to disable biometric login? You have to verify your fingerprint again to enable it.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6750A4)),
              ),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                prefs.remove('biometric_email');
                prefs.remove('biometric_password');

                context.read<UserBloc>().add(
                  DisableBiometricLogin(user.uid),
                );
                setState(() {
                  isBiometricEnabled = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                'Disable',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final user = (state is UserLoaded) ? state.user : null;
        final biometricEnabled = user?.biometricEnabled ?? false;
        final storedDeviceId = user?.deviceId;
        isBiometricEnabled = biometricEnabled && storedDeviceId == _deviceId;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(65),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 1),
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
                  'Biometric Login',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          body: Stack(
            children: [
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/settings/biometric_login.png',
                    width: 350,
                    height: 350,
                  ),
                ),
              ),
              Positioned(
                top: 320,
                left: 0,
                right: 0,
                child: Text(
                  'Biometric Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Positioned(
                top: 350,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Sign in to your account faster using Biometrics \n login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 440,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: ListTile(
                    title: Text(
                      'Enable Biometric Login',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: Switch(
                      value: isBiometricEnabled,
                      onChanged: (value) async {
                        if (value) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FingerprintEnrollmentScreen(),
                            ),
                          );

                          if (result == true && _deviceId != null) {
                            final prefs = await SharedPreferences.getInstance();
                            final backupUsername = prefs.getString('backup_email');
                            final backupPassword = prefs.getString('backup_password');
                            if (backupUsername != null && backupPassword != null) {
                              prefs.setString('biometric_email', backupUsername);
                              prefs.setString('biometric_password', backupPassword);
                            }

                            context.read<UserBloc>().add(
                              EnableBiometricLogin(user!.uid, _deviceId!),
                            );
                            setState(() {
                              isBiometricEnabled = true;
                            });
                          }
                        } else {
                          await _showDisableBiometricDialog(context, user!);
                        }
                      },
                      activeColor: const Color(0xFF6750A4),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'By enabling biometrics login, you will allow Accessability to access your saved biometrics data in your device to create and save data in Accessability that shall be used for securing your login. The data will not be used for any other purposes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}