import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool isColorblindmode = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentLanguage = context.locale.languageCode;
    final bool isDarkMode = themeProvider.isDarkMode;

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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              'preference'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Center(
        child: ListView(
          children: [
            // Dark Mode Toggle
            Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: 10,
                right: 10,
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.nightlight_outlined,
                  color: Color(0xFF6750A4),
                ),
                title: Text(
                  'darkMode'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Switch(
                  activeColor: const Color(0xFF6750A4),
                  value: isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ),
            ),
            const Divider(),
            // Color Blind Mode Toggle
            Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Color(0xFF6750A4),
                ),
                title: Text(
                  'colorBlindMode'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
            ),
            const Divider(),
            // Language Dropdown using EasyLocalization's locale
            Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.language,
                  color: Color(0xFF6750A4),
                ),
                title: Text(
                  'language'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: DropdownButton<String>(
                  value: currentLanguage,
                  onChanged: (String? newValue) {
                    if (newValue == null) return;
                    // Change the locale and trigger a rebuild:
                    context.setLocale(Locale(newValue));
                    setState(() {}); // Optionally trigger a rebuild if needed
                  },
                  items: <String>['en', 'fil', 'pag']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value == 'en'
                            ? 'english'.tr()
                            : value == 'fil'
                                ? 'filipino'.tr()
                                : 'pangasinan'.tr(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
