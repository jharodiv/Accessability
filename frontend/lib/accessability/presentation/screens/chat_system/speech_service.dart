import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;
  TtsState _ttsState = TtsState.stopped;

  // TTS Configuration
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;

  SpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // Get available languages (optional)
      // List<dynamic> languages = await _flutterTts.getLanguages;

      // Set TTS settings
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setLanguage("en-US");

      // Set up TTS handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _ttsState = TtsState.playing;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _ttsState = TtsState.stopped;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _ttsState = TtsState.stopped;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _ttsState = TtsState.stopped;
        print("TTS Error: $msg");
      });
    } catch (e) {
      print("Error initializing TTS: $e");
    }
  }

  // Speech-to-Text Methods
  Future<bool> initializeSpeech() async {
    try {
      return await _speech.initialize(
        onStatus: (status) {
          _isListening = status == 'listening';
          print('Speech status: $status');
        },
        onError: (error) {
          _isListening = false;
          print('Speech recognition error: $error');
        },
      );
    } catch (e) {
      print('Error initializing speech: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function() onListeningStarted,
    required Function() onListeningStopped,
  }) async {
    if (_isListening) {
      await stopListening();
      return;
    }

    // CORRECTED: isAvailable is a property, not a method
    if (_speech.isAvailable) {
      try {
        onListeningStarted();
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              onResult(result.recognizedWords);
              onListeningStopped();
            } else {
              // You can also handle partial results here if needed
              onResult(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } catch (e) {
        print('Error starting speech recognition: $e');
        onListeningStopped();
      }
    } else {
      print('Speech recognition not available');
      onListeningStopped();
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  // Text-to-Speech Methods
  Future<void> speakText(String text) async {
    if (_isSpeaking) {
      await stopSpeaking();
      return;
    }

    if (text.trim().isEmpty) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error speaking text: $e');
      _isSpeaking = false;
      _ttsState = TtsState.stopped;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _ttsState = TtsState.stopped;
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    _rate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _flutterTts.setPitch(pitch);
  }

  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  // CORRECTED: isAvailable is a property
  bool get isAvailable => _speech.isAvailable;

  TtsState get ttsState => _ttsState;

  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;

  void dispose() {
    _speech.stop();
    _flutterTts.stop();
  }
}
