// tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._private();
  static final TtsService instance = TtsService._private();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init({
    String language = 'en-US',
    double rate = 0.45,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (_initialized) return;
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
    if (text.trim().isEmpty) return;
    if (!_initialized) await init();
    try {
      _tts.speak(text);
    } catch (e) {
      print('TTS speak error: $e');
    }
  }
}
