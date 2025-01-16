import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/delete_account.dart';
import 'package:frontend/accessability/presentation/screens/settings/settings_screen.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/change_password_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back, color: Color(0xFF6750A4))),
          title: const Text(
            'Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            AssetImage('assets/images/others/profile.jpg'),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Jem Centino',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Account Details',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6750A4)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF6750A4)),
                  title: const Text('Username'),
                  subtitle: const Text('Jem Centino'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                    onPressed: () {},
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Color(0xFF6750A4)),
                  title: const Text('Email'),
                  subtitle: const Text('kawu@gmail.com'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                    onPressed: () {},
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.key, color: Color(0xFF6750A4)),
                  title: const Text('Password'),
                  subtitle: const Text('*******'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Changepassword()));
                    },
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  'Account Management',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6750A4)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Color(0xFF6750A4)),
                  title: const Text('Delete Account'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeleteAccount(),
                      ),
                    );
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.logout, color: Color(0xFF6750A4)),
                  title: Text('Log out'),
                ),
              ],
            ),
          ),
        ));
  }
}
