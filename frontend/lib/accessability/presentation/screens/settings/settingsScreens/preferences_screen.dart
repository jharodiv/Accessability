import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/settings/settings_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool isNightmode = false;
  bool isColorblindmode = false;
  String selectedLanguage = 'English'; //Default Language

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
                    ));
              },
              icon: const Icon(Icons.arrow_back)),
          title: const Text(
            'Preference',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.nightlight_outlined,
                    color: Color(0xFF6750A4),
                  ),
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                      value: isNightmode,
                      onChanged: (bool value) {
                        setState(() {
                          isNightmode = value;
                        });
                      }),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Color(0xFF6750A4),
                  ),
                  title: const Text(
                    'Color Blind Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                      value: isColorblindmode,
                      onChanged: (bool value) {
                        setState(() {
                          isColorblindmode = value;
                        });
                      }),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.language,
                    color: Color(0xFF6750A4),
                  ),
                  title: const Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: DropdownButton<String>(
                    value: selectedLanguage,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedLanguage = newValue!;
                      });
                    },
                    items: <String>['English', 'Filipino']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
