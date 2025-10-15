import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessability/accessability/themes/dark_mode.dart';
import 'package:accessability/accessability/themes/light_mode.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = lightMode;
  final SharedPreferences _prefs;

  // Color Blind Mode state
  bool _isColorBlindMode = false;

  // TTS state
  bool _isTtsEnabled = true; // default ON

  // Supported color blindness types
  static const List<String> colorBlindTypes = [
    'none',
    'protanopia',
    'deuteranopia',
    'tritanopia',
    'achromatopsia',
  ];

  String _colorBlindType = 'none';

  ThemeProvider(this._prefs) {
    _loadThemePreference();
    _loadColorBlindPreference();
    _loadColorBlindTypePreference();
    _loadTtsPreference(); // 👈 new line
  }

  ThemeData get themeData => _themeData;
  bool get isDarkMode => _themeData == darkMode;

  // Color Blind getters
  bool get isColorBlindMode => _isColorBlindMode;
  String get colorBlindType => _colorBlindType;

  // TTS getter
  bool get isTtsEnabled => _isTtsEnabled;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  // 🌙 Toggle dark mode
  Future<void> toggleTheme() async {
    if (_themeData == lightMode) {
      themeData = darkMode;
    } else {
      themeData = lightMode;
    }
    await _prefs.setBool('isDarkMode', isDarkMode);
    print('Theme toggled. isDarkMode: $isDarkMode');
  }

  // 👁️ Toggle color blind mode
  Future<void> toggleColorBlindMode() async {
    _isColorBlindMode = !_isColorBlindMode;
    await _prefs.setBool('isColorBlindMode', _isColorBlindMode);
    notifyListeners();
    print('Color Blind Mode toggled. isColorBlindMode: $_isColorBlindMode');
  }

  // 🎨 Set color blind type
  Future<void> setColorBlindType(String type) async {
    if (colorBlindTypes.contains(type)) {
      _colorBlindType = type;
      await _prefs.setString('colorBlindType', type);
      notifyListeners();
      print('Color Blind Type set: $type');
    }
  }

  // 🗣️ Toggle TTS mode
  Future<void> toggleTts(bool value) async {
    _isTtsEnabled = value;
    await _prefs.setBool('isTtsEnabled', value);
    notifyListeners();
    print('TTS toggled. isTtsEnabled: $_isTtsEnabled');
  }

  // 🌙 Load dark mode preference
  Future<void> _loadThemePreference() async {
    final isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _themeData = isDarkMode ? darkMode : lightMode;
    notifyListeners();
    print('Theme loaded. isDarkMode: $isDarkMode');
  }

  // 👁️ Load color blind mode preference
  Future<void> _loadColorBlindPreference() async {
    _isColorBlindMode = _prefs.getBool('isColorBlindMode') ?? false;
    notifyListeners();
    print('Color Blind Mode loaded. isColorBlindMode: $_isColorBlindMode');
  }

  // 🎨 Load color blind type preference
  Future<void> _loadColorBlindTypePreference() async {
    _colorBlindType = _prefs.getString('colorBlindType') ?? 'none';
    notifyListeners();
    print('Color Blind Type loaded: $_colorBlindType');
  }

  // 🗣️ Load TTS preference
  Future<void> _loadTtsPreference() async {
    _isTtsEnabled = _prefs.getBool('isTtsEnabled') ?? true;
    notifyListeners();
    print('TTS preference loaded. isTtsEnabled: $_isTtsEnabled');
  }
}
