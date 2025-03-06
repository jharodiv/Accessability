import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool isColorblindmode = false;
  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

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
              'Preference',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
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
                  activeColor: const Color(0xFF6750A4),
                  value: isDarkMode,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                  },
                ),
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
                  activeColor: const Color(0xFF6750A4),
                  onChanged: (bool value) {
                    setState(() {
                      isColorblindmode = value;
                    });
                  },
                ),
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
      ),
    );
  }
}