// tts_service.dart (only show changed/added parts)
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  TtsService._private();
  static final TtsService instance = TtsService._private();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isEnabled = true; // Default ON

  // NEW: last time we started a speak - used to debounce near-duplicates
  DateTime? _lastSpeakAt;
  final Duration _speakDebounce = const Duration(milliseconds: 600);

  Future<void> init({
    String language = 'en-US',
    double rate = 0.45,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('isTtsEnabled') ?? true; // default ON

    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(volume);
      await _tts.setPitch(pitch);
      _initialized = true;
    } catch (e) {
      print('TTS init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled) return;
    if (text.trim().isEmpty) return;
    if (!_initialized) await init();

    // Debounce: if we spoke very recently, ignore to avoid duplicates
    final now = DateTime.now();
    if (_lastSpeakAt != null &&
        now.difference(_lastSpeakAt!) < _speakDebounce) {
      return;
    }
    _lastSpeakAt = now;

    try {
      await _tts.stop(); // stop previous speech
      await _tts.speak(text);
    } catch (e) {
      print('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTtsEnabled', value);
  }

  bool get isEnabled => _isEnabled;
}
