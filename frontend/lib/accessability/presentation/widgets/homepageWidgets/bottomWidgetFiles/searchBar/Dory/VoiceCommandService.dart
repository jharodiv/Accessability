// lib/services/voice_command_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Dory/DoryModelService.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceCommandService {
  final Dorymodelservice _doryService = Dorymodelservice();
  final SpeechToText _speechToText = SpeechToText();

  bool _isListening = false;
  bool _isDoryActive = false;
  bool _isProcessingCommand = false;
  StreamController<VoiceCommandState>? _stateController;

  // Configuration
  static const double DORY_CONFIDENCE_THRESHOLD =
      0.7; // 70% confidence for Dory detection
  static const double COMMAND_CONFIDENCE_THRESHOLD =
      50.0; // 50% for command execution
  static const int COMMAND_TIMEOUT_SECONDS =
      10; // Wait 10 seconds for command after Dory

  VoiceCommandService() {
    _stateController = StreamController<VoiceCommandState>.broadcast();
  }

  /// Stream of voice command states
  Stream<VoiceCommandState> get stateStream => _stateController!.stream;

  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      // This will show the permission dialog
      status = await Permission.microphone.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // User denied permanently → open settings
      print(
          '❌ Microphone permission permanently denied. Please enable it from settings.');
      openAppSettings(); // From permission_handler
      return false;
    }

    return false;
  }

  /// Initialize both Dory model and speech recognition
  Future<bool> initialize() async {
    try {
      // Initialize Dory model
      final doryLoaded =
          await _doryService.loadModel('assets/model/best_dory_model.tflite');
      if (!doryLoaded) {
        print('❌ Failed to load Dory model');
        return false;
      }

      // Initialize speech recognition
      final speechAvailable = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );

      if (!speechAvailable) {
        print('❌ Speech recognition not available');
        return false;
      }

      if (!speechAvailable) {
        print('❌ Speech recognition not available');
        return false;
      }

      print('✅ Voice Command Service initialized');
      _emitState(VoiceCommandState.ready());
      return true;
    } catch (e) {
      print('❌ Initialization error: $e');
      return false;
    }
  }

  /// Start continuous listening for Dory wake word
  Future<void> startListening() async {
    if (_isListening) return;

    _isListening = true;
    _emitState(VoiceCommandState.listeningForDory());

    await _speechToText.listen(
      onResult: _handleSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(milliseconds: 500),
      partialResults: true,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    _isDoryActive = false;
    _isProcessingCommand = false;

    await _speechToText.stop();
    _emitState(VoiceCommandState.idle());
  }

  /// Handle speech recognition results
  void _handleSpeechResult(result) async {
    final text = result.recognizedWords.toLowerCase();
    print('🎙️ Heard: "$text"');

    if (!_isDoryActive) {
      // Phase 1: Check for Dory wake word
      await _checkForDory(text);
    } else {
      // Phase 2: Process command after Dory detected
      if (result.finalResult) {
        await _processCommand(text);
      }
    }
  }

  /// Check if speech contains Dory wake word
  Future<void> _checkForDory(String text) async {
    try {
      // Extract audio features (placeholder - you'd implement actual feature extraction)
      List<double> audioFeatures = await _extractAudioFeatures(text);

      // Run Dory detection
      final prediction = _doryService.predict(audioFeatures);

      if (prediction != null &&
          prediction.predictedClass.toLowerCase().contains('dory') &&
          prediction.confidence >= DORY_CONFIDENCE_THRESHOLD) {
        print(
            '🐠 Dory detected! Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%');

        _isDoryActive = true;
        _emitState(VoiceCommandState.doryDetected(prediction.confidence));

        // Start command listening timeout
        _startCommandTimeout();

        // Continue listening for actual command
        _emitState(VoiceCommandState.listeningForCommand());
      }
    } catch (e) {
      print('❌ Dory detection error: $e');
    }
  }

  /// Process voice command using HuggingFace API
  Future<void> _processCommand(String command) async {
    if (_isProcessingCommand) return;

    _isProcessingCommand = true;
    _emitState(VoiceCommandState.processingCommand(command));

    try {
      print('🤖 Processing command: "$command"');

      // Call your existing HuggingFace API
      final result = await predictCommand(command);
      final label = result['label'];
      final confidence = result['confidence'];

      print('📊 Command result: $label (${confidence}% confidence)');

      if (confidence >= COMMAND_CONFIDENCE_THRESHOLD) {
        _emitState(
            VoiceCommandState.commandExecuted(label, confidence.toDouble()));

        // Execute the command (you can move this logic here or emit event)
        await _executeCommand(label);
      } else {
        print('⚠️ Low confidence ($confidence%). Command not executed.');
        _emitState(VoiceCommandState.lowConfidence(confidence.toDouble()));
      }
    } catch (e) {
      print('❌ Command processing error: $e');
      _emitState(VoiceCommandState.error('Failed to process command: $e'));
    } finally {
      // Reset states
      _isDoryActive = false;
      _isProcessingCommand = false;

      // Return to listening for Dory
      if (_isListening) {
        _emitState(VoiceCommandState.listeningForDory());
      }
    }
  }

  /// Your existing command prediction function
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

  /// Execute command based on label
  Future<void> _executeCommand(String label) async {
    // You can either emit an event or execute directly
    // For now, we'll emit an event that your UI can listen to
    _emitState(VoiceCommandState.executeNavigation(label));
  }

  /// Extract audio features for Dory (placeholder implementation)
  Future<List<double>> _extractAudioFeatures(String text) async {
    // This is a placeholder. In a real implementation, you would:
    // 1. Get raw audio data
    // 2. Extract MFCC/spectral features
    // 3. Return the same features used during Dory training

    // For now, return dummy features based on text characteristics
    List<double> features = [];
    final modelInfo = _doryService.getModelInfo();
    final inputSize = modelInfo?['inputShape'][1] ?? 128;

    // Generate features based on text (this is just for demo)
    for (int i = 0; i < inputSize; i++) {
      double feature = 0.0;
      if (text.contains('dory')) {
        feature = (i % 10) * 0.1 - 0.5; // Pattern that might indicate Dory
      } else {
        feature = (i % 5) * 0.05 - 0.25; // Different pattern
      }
      features.add(feature);
    }

    return features;
  }

  /// Start timeout for command listening
  void _startCommandTimeout() {
    Timer(const Duration(seconds: COMMAND_TIMEOUT_SECONDS), () {
      if (_isDoryActive && !_isProcessingCommand) {
        print('⏰ Command timeout - returning to Dory listening');
        _isDoryActive = false;
        if (_isListening) {
          _emitState(VoiceCommandState.listeningForDory());
        }
      }
    });
  }

  /// Emit state to listeners
  void _emitState(VoiceCommandState state) {
    _stateController?.add(state);
  }

  /// Dispose resources
  void dispose() {
    _doryService.dispose();
    _stateController?.close();
  }
}

/// Voice command states
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
