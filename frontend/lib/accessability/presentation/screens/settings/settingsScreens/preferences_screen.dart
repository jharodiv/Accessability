import 'package:accessability/accessability/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentLanguage = context.locale.languageCode;
    final bool isDarkMode = themeProvider.isDarkMode;
    final bool isColorBlindMode = themeProvider.isColorBlindMode;
    final bool isTtsEnabled = themeProvider.isTtsEnabled; // 👈 new flag

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
      body: ListView(
        children: [
          // 🌙 Dark Mode
          _buildSwitchTile(
            icon: Icons.nightlight_outlined,
            label: 'darkMode'.tr(),
            value: isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),

          const Divider(),

          // 👁️ Color Blind Mode
          _buildSwitchTile(
            icon: Icons.remove_red_eye_outlined,
            label: 'colorBlindMode'.tr(),
            value: isColorBlindMode,
            onChanged: (_) async {
              await themeProvider.toggleColorBlindMode();
              setState(() {});
            },
          ),

          const Divider(),

          // 🗣️ TTS Enable/Disable
          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            label: 'Text-to-Speech',
            value: isTtsEnabled,
            onChanged: (value) async {
              await TtsService.instance.stop();
              await TtsService.instance.setEnabled(value);
              await themeProvider.toggleTts(value);
              if (mounted) setState(() {});
            },
          ),

          const Divider(),

          // 🌐 Language Dropdown
          Semantics(
            label: 'Languages',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    context.setLocale(Locale(newValue));
                    setState(() {});
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
                                : 'Pangasinan'.tr(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _reloadApp(BuildContext context) {
    // Reload entire MaterialApp by forcing rebuild
    WidgetsBinding.instance.performReassemble(); // works in debug
    // OR, for production-safe:
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF6750A4)),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Semantics(
            label: label,
            child: Switch(
              activeColor: const Color(0xFF6750A4),
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}
