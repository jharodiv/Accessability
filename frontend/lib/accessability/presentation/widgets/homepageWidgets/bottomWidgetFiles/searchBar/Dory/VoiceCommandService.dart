// lib/services/voice_command_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Dory/DoryModelService.dart';
import 'package:audio_streamer/audio_streamer.dart';

class VoiceCommandService {
  final Dorymodelservice _doryService = Dorymodelservice();
  final SpeechToText _speechToText = SpeechToText();

  // AudioStreamer related variables
  AudioStreamer? _audioStreamer;
  StreamSubscription<List<double>>? _audioSubscription;

  bool _isListening = false;
  bool _isDoryActive = false;
  bool _isProcessingCommand = false;
  StreamController<VoiceCommandState>? _stateController;

  // Audio processing for wake word detection
  List<double> _audioBuffer = [];
  static const int SAMPLE_RATE = 16000;
  static const int BUFFER_SIZE = SAMPLE_RATE * 2; // 2 seconds of audio
  static const double DORY_CONFIDENCE_THRESHOLD = 0.6;
  static const double COMMAND_CONFIDENCE_THRESHOLD = 50.0;
  static const int COMMAND_TIMEOUT_SECONDS = 10;

  VoiceCommandService() {
    _stateController = StreamController<VoiceCommandState>.broadcast();
  }

  /// Stream of voice command states (keeping same interface as before)
  Stream<VoiceCommandState> get stateStream => _stateController!.stream;

  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.microphone.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      print(
          '❌ Microphone permission permanently denied. Please enable it from settings.');
      openAppSettings();
      return false;
    }

    return false;
  }

  /// Initialize both Dory model and speech recognition
  Future<bool> initialize() async {
    try {
      // Initialize Dory wake word model
      final doryLoaded =
          await _doryService.loadModel('assets/model/best_dory_model.tflite');
      if (!doryLoaded) {
        print('❌ Failed to load Dory model');
        return false;
      }

      // Initialize speech recognition (only for commands after Dory detection)
      final speechAvailable = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );

      if (!speechAvailable) {
        print('❌ Speech recognition not available');
        return false;
      }

      print('✅ Voice Command Service initialized with wake word detection');
      _emitState(VoiceCommandState.ready());
      return true;
    } catch (e) {
      print('❌ Initialization error: $e');
      return false;
    }
  }

  /// Start continuous listening for Dory wake word using AudioStreamer
  Future<void> startListening() async {
    if (_isListening) return;

    print('🎙️ Starting continuous wake word detection...');
    _isListening = true;
    _isDoryActive = false;
    _emitState(VoiceCommandState.listeningForDory());

    try {
      // Request microphone permission first
      if (!await requestMicrophonePermission()) {
        throw Exception('Microphone permission not granted');
      }

      // Initialize AudioStreamer
      _audioStreamer = AudioStreamer();

      // Listen to audio stream for wake word detection
      // AudioStreamer starts automatically when you subscribe to the stream
      _audioSubscription = _audioStreamer!.audioStream.listen(
        (audioData) => _processAudioForWakeWord(audioData),
        onError: (error) {
          print('❌ Audio stream error: $error');
          _handleAudioStreamError();
        },
        onDone: () {
          print('🔚 Audio stream ended');
          if (_isListening && !_isDoryActive) {
            _restartWakeWordListening();
          }
        },
      );

      // No need to call start() - streaming begins automatically when you listen to audioStream
      print('✅ Wake word detection started');
    } catch (e) {
      print('❌ Failed to start wake word detection: $e');
      _isListening = false;
      _emitState(VoiceCommandState.error('Failed to start listening: $e'));
    }
  }

  /// Process audio chunks for wake word detection
  void _processAudioForWakeWord(List<double> audioData) {
    if (_isDoryActive) return; // Skip if Dory already detected

    // AudioStreamer already provides List<double>, so use directly
    _audioBuffer.addAll(audioData);

    // Maintain rolling buffer
    if (_audioBuffer.length > BUFFER_SIZE) {
      _audioBuffer.removeRange(0, _audioBuffer.length - BUFFER_SIZE);
    }

    // Process when we have enough data
    if (_audioBuffer.length >= BUFFER_SIZE) {
      _detectDoryWakeWord();
    }
  }

  /// Detect Dory wake word using your trained model
  void _detectDoryWakeWord() async {
    try {
      // Extract features from audio buffer
      List<double> features = _extractAudioFeatures(_audioBuffer);

      // Run Dory wake word detection
      final prediction = _doryService.predict(features);

      if (prediction != null) {
        print(
            '🔮 Wake Word Prediction: ${prediction.predictedClass} (${(prediction.confidence * 100).toStringAsFixed(2)}%)');

        // Check if Dory wake word is detected
        if (_isDoryWakeWordDetected(prediction)) {
          await _handleDoryDetected(prediction);
        }
      }
    } catch (e) {
      print('❌ Wake word detection error: $e');
    }
  }

  /// Check if prediction indicates Dory wake word
  bool _isDoryWakeWordDetected(DoryPrediction prediction) {
    return (prediction.predictedClass.toLowerCase().contains('dory') ||
            prediction.predictedClass
                .toLowerCase()
                .contains('dory_speaking')) &&
        prediction.confidence >= DORY_CONFIDENCE_THRESHOLD;
  }

  /// Handle Dory wake word detection
  Future<void> _handleDoryDetected(DoryPrediction prediction) async {
    print(
        '🐠 DORY WAKE WORD DETECTED! Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%');

    _isDoryActive = true;
    _emitState(VoiceCommandState.doryDetected(prediction.confidence));

    // Stop audio stream for wake word detection
    await _stopAudioStream();

    // Short delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    // Start command listening using STT
    await _startCommandListening();
  }

  /// Stop the current audio stream
  Future<void> _stopAudioStream() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // AudioStreamer doesn't have a stop() method - it stops when you cancel the subscription
    _audioStreamer = null;
  }

  /// Start speech-to-text for command recognition after Dory detected
  Future<void> _startCommandListening() async {
    print('🎯 Dory activated! Starting command listening...');
    _emitState(VoiceCommandState.listeningForCommand());

    try {
      await _speechToText.listen(
        onResult: _handleCommandResult,
        listenFor: Duration(seconds: COMMAND_TIMEOUT_SECONDS),
        pauseFor: const Duration(seconds: 2),
        partialResults: false, // Only final results for commands
        cancelOnError: false,
        localeId: 'auto', // Auto-detect language
      );

      // Start timeout timer
      _startCommandTimeout();
    } catch (e) {
      print('❌ Command listening error: $e');
      await _returnToWakeWordMode();
    }
  }

  /// Handle speech recognition results for commands
  void _handleCommandResult(result) async {
    if (!_isDoryActive || _isProcessingCommand) return;

    final command = result.recognizedWords.trim();
    print('📝 Command received: "$command" (final: ${result.finalResult})');

    if (result.finalResult && command.isNotEmpty) {
      await _processCommand(command);
    }
  }

  /// Process voice command using HuggingFace API (same as before)
  Future<void> _processCommand(String command) async {
    if (_isProcessingCommand) return;

    _isProcessingCommand = true;
    _emitState(VoiceCommandState.processingCommand(command));

    try {
      print('🤖 Processing command: "$command"');

      // Call your existing HuggingFace multilingual API
      final result = await predictCommand(command);
      final label = result['label'];
      final confidence = result['confidence'];

      print('📊 Command result: $label (${confidence}% confidence)');

      if (confidence >= COMMAND_CONFIDENCE_THRESHOLD) {
        _emitState(
            VoiceCommandState.commandExecuted(label, confidence.toDouble()));
        _emitState(VoiceCommandState.executeNavigation(label));
      } else {
        print('⚠️ Low confidence ($confidence%). Command not executed.');
        _emitState(VoiceCommandState.lowConfidence(confidence.toDouble()));
      }
    } catch (e) {
      print('❌ Command processing error: $e');
      _emitState(VoiceCommandState.error('Failed to process command: $e'));
    } finally {
      await _returnToWakeWordMode();
    }
  }

  /// Your existing command prediction function (unchanged)
  Future<Map<String, dynamic>> predictCommand(String text) async {
    final url =
        Uri.parse("https://jharodiv-accessability.hf.space/api/predict");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to get prediction: ${response.body}");
    }
  }

  /// Return to wake word detection mode after command processing
  Future<void> _returnToWakeWordMode() async {
    print('🔄 Returning to wake word detection mode...');

    _isDoryActive = false;
    _isProcessingCommand = false;

    // Stop speech-to-text
    await _speechToText.stop();

    // Clear audio buffer
    _audioBuffer.clear();

    // Short delay before restarting
    await Future.delayed(const Duration(milliseconds: 500));

    // Restart wake word listening if still enabled
    if (_isListening) {
      _emitState(VoiceCommandState.listeningForDory());
      await startListening();
    }
  }

  /// Handle command timeout
  void _startCommandTimeout() {
    Timer(Duration(seconds: COMMAND_TIMEOUT_SECONDS), () {
      if (_isDoryActive && !_isProcessingCommand) {
        print('⏰ Command timeout - returning to wake word mode');
        _returnToWakeWordMode();
      }
    });
  }

  /// Handle audio stream errors
  void _handleAudioStreamError() async {
    print('🔧 Audio stream error - restarting wake word detection...');
    await Future.delayed(const Duration(seconds: 2));
    if (_isListening && !_isDoryActive) {
      await _restartWakeWordListening();
    }
  }

  /// Restart wake word listening after error
  Future<void> _restartWakeWordListening() async {
    print('🔄 Restarting wake word detection...');
    await Future.delayed(const Duration(seconds: 1));
    if (_isListening && !_isDoryActive) {
      await startListening();
    }
  }

  /// Stop listening (updated for AudioStreamer)
  Future<void> stopListening() async {
    print('🛑 Stopping voice command service...');

    _isListening = false;
    _isDoryActive = false;
    _isProcessingCommand = false;

    // Stop audio stream
    await _stopAudioStream();

    // Stop speech recognition
    await _speechToText.stop();

    _audioBuffer.clear();
    _emitState(VoiceCommandState.idle());
  }

  /// Extract audio features for wake word detection
  List<double> _extractAudioFeatures(List<double> audioData) {
    // Get expected input size from your Dory model
    final modelInfo = _doryService.getModelInfo();
    final inputSize = modelInfo?['inputShape'][1] ?? 128;

    // TODO: Implement proper MFCC feature extraction here
    // For now, using simplified feature extraction that should work with your model
    List<double> features = [];

    // Simple windowing and feature extraction
    for (int i = 0; i < inputSize; i++) {
      if (i < audioData.length) {
        // Apply simple preprocessing (you may need to adjust this based on your model's training)
        double feature = audioData[i % audioData.length];
        features.add(feature);
      } else {
        features.add(0.0);
      }
    }

    return features;
  }

  /// Emit state to listeners (same interface as before)
  void _emitState(VoiceCommandState state) {
    _stateController?.add(state);
  }

  /// Dispose resources (updated for AudioStreamer)
  void dispose() {
    stopListening();
    _doryService.dispose();
    _stateController?.close();
  }
}

/// Keep all your existing VoiceCommandState classes exactly the same
class VoiceCommandState {
  final VoiceCommandStatus status;
  final String? message;
  final double? confidence;
  final String? command;
  final String? label;

  VoiceCommandState._(this.status,
      {this.message, this.confidence, this.command, this.label});

  factory VoiceCommandState.idle() =>
      VoiceCommandState._(VoiceCommandStatus.idle);
  factory VoiceCommandState.ready() =>
      VoiceCommandState._(VoiceCommandStatus.ready);
  factory VoiceCommandState.listeningForDory() =>
      VoiceCommandState._(VoiceCommandStatus.listeningForDory);
  factory VoiceCommandState.doryDetected(double confidence) =>
      VoiceCommandState._(VoiceCommandStatus.doryDetected,
          confidence: confidence);
  factory VoiceCommandState.listeningForCommand() =>
      VoiceCommandState._(VoiceCommandStatus.listeningForCommand);
  factory VoiceCommandState.processingCommand(String command) =>
      VoiceCommandState._(VoiceCommandStatus.processingCommand,
          command: command);
  factory VoiceCommandState.commandExecuted(String label, double confidence) =>
      VoiceCommandState._(VoiceCommandStatus.commandExecuted,
          label: label, confidence: confidence);
  factory VoiceCommandState.executeNavigation(String label) =>
      VoiceCommandState._(VoiceCommandStatus.executeNavigation, label: label);
  factory VoiceCommandState.lowConfidence(double confidence) =>
      VoiceCommandState._(VoiceCommandStatus.lowConfidence,
          confidence: confidence);
  factory VoiceCommandState.error(String message) =>
      VoiceCommandState._(VoiceCommandStatus.error, message: message);
}

enum VoiceCommandStatus {
  idle,
  ready,
  listeningForDory,
  doryDetected,
  listeningForCommand,
  processingCommand,
  commandExecuted,
  executeNavigation,
  lowConfidence,
  error,
}
