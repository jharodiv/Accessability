import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/gpsScreen/gps.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/about_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/account_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/biometric_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/chat_with_support_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/preferences_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          leading: IconButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GpsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4)),
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black,
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF6750A4)),
            title: const Text('Account',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune, color: Color(0xFF6750A4)),
            title: const Text('Preference',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Preferencescreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications, color: Color(0xFF6750A4)),
            title: const Text('Notification',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Switch(
              value: isNotificationEnabled,
              onChanged: (bool value) {
                setState(
                  () {
                    isNotificationEnabled = value;
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security, color: Color(0xFF6750A4)),
            title: const Text('Privacy & Security',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Privacysecurity(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF6750A4)),
            title: const Text('Chat and Support',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Chatandsupport(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Color(0xFF6750A4)),
            title: const Text('Biometric Login',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Biometriclogin(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: Color(0xFF6750A4)),
            title: const Text('About',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF6750A4)),
            title: const Text(
              'Log out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
