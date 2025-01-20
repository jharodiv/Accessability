import 'package:flutter/material.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/presentation/screens/gpsScreen/gps.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;

  void logout() async {
    final authService = AuthService();
    await authService.signOut();
  }

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
              Navigator.pushNamed(context, '/account');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune, color: Color(0xFF6750A4)),
            title: const Text('Preference',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushNamed(context, '/preferences');
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
              Navigator.pushNamed(context, '/privacy');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF6750A4)),
            title: const Text('Chat and Support',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushNamed(context, '/chat');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Color(0xFF6750A4)),
            title: const Text('Biometric Login',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushNamed(context, '/biometric');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: Color(0xFF6750A4)),
            title: const Text('About',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF6750A4)),
            title: const Text(
              'Log out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: logout, // Call the logout function here
          ),
        ],
      ),
    );
  }
}
