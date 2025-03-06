import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/data/repositories/auth_repository.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/main.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
    final authBloc = context.read<AuthBloc>();

    try {
      await authService.signOut();
      authBloc.add(LogoutEvent());

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white, // AppBar background color
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Shadow color
                offset: const Offset(0, 1), // Horizontal and Vertical offset
                blurRadius: 2, // How much to blur the shadow
              ),
            ],
          ),
          child: AppBar(
            elevation: 0, // Remove default elevation
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent, // Make AppBar transparent
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white, // Background color
        child: ListView(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.person_2_outlined, color: Color(0xFF6750A4)),
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
              leading: const Icon(Icons.notifications_active_outlined,
                  color: Color(0xFF6750A4)),
              title: const Text('Notification',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Switch(
                activeColor: const Color(0xFF6750A4),
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
              leading:
                  const Icon(Icons.security_outlined, color: Color(0xFF6750A4)),
              title: const Text('Privacy & Security',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pushNamed(context, '/privacy');
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
              leading: const Icon(Icons.info_outline, color: Color(0xFF6750A4)),
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
              onTap: () => logout(context), // Call the logout function here
            ),
          ],
        ),
      ),
    );
  }
}