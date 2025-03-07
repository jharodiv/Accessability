import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AccessAbility/accessability/themes/dark_mode.dart';
import 'package:AccessAbility/accessability/themes/light_mode.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = lightMode;
  final SharedPreferences _prefs;

  ThemeProvider(this._prefs) {
    _loadThemePreference();
  }

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == darkMode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
  if (_themeData == lightMode) {
    themeData = darkMode;
  } else {
    themeData = lightMode;
  }
  await _prefs.setBool('isDarkMode', isDarkMode);
  print('Theme toggled. isDarkMode: $isDarkMode');
}

Future<void> _loadThemePreference() async {
  final isDarkMode = _prefs.getBool('isDarkMode') ?? false;
  _themeData = isDarkMode ? darkMode : lightMode;
  notifyListeners();
  print('Theme loaded. isDarkMode: $isDarkMode');
}
}