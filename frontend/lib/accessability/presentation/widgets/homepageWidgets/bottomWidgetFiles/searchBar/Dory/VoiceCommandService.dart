// lib/services/voice_command_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Dory/DoryModelService.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'dart:math' as math;
import 'dart:typed_data';

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
  static const double DORY_CONFIDENCE_THRESHOLD = 0.85;
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
      List<List<double>> features = _extractMelSpectogramFeatures(_audioBuffer);
      final prediction = _doryService.predict(features);

      if (prediction != null) {
        // Debug ALL predictions
        print('🔍 All predictions:');
        for (var pred in prediction.getAllPredictions()) {
          print(
              '   ${pred.className}: ${(pred.confidence * 100).toStringAsFixed(2)}%');
        }

        // Log audio statistics
        final maxAudio = _audioBuffer.reduce((a, b) => a > b ? a : b);
        final minAudio = _audioBuffer.reduce((a, b) => a < b ? a : b);
        print('🎵 Audio range: $minAudio to $maxAudio');
      }
    } catch (e) {
      print('❌ Wake word detection error: $e');
    }
  }

  List<List<double>> _extractMelSpectogramFeatures(List<double> audioData) {
    final modelInfo = _doryService.getModelInfo();
    if (modelInfo == null) return [[]];

    const int SAMPLE_RATE = 16000;
    const int DURATION = 2;
    const int N_MELS = 40;
    const int N_FFT = 2048;
    const int HOP_LENGTH = 512;

    // Ensure audio is exactly 2 seconds
    List<double> processedAudio =
        _prepareAudio(audioData, SAMPLE_RATE * DURATION);

    //Compute STFT (short-time fourier transform)
    List<List<double>> stftMagnitude =
        _computeSTFT(processedAudio, N_FFT, HOP_LENGTH);

    //Apply mel filter bank to convert to mel-spectogram
    List<List<double>> melSpectogram =
        _applyMelFilterBank(stftMagnitude, SAMPLE_RATE, N_MELS, N_FFT);

    //Convert to dB scale (log scale) (crucial)
    List<List<double>> melSpectogramDB = _powerToDB(melSpectogram);

    print(
        '‼️ Mel-spectogram shape: ${melSpectogramDB.length}x${melSpectogramDB.isNotEmpty ? melSpectogramDB[0].length : 0}');

    return melSpectogramDB;
  }

  List<double> _prepareAudio(List<double> audio, int targetLength) {
    List<double> result = List.from(audio);

    if (result.length < targetLength) {
      int padLength = targetLength - result.length;
      result.addAll(List.filled(padLength, 0.0));
    } else if (result.length > targetLength) {
      result = result.sublist(0, targetLength);
    }

    print('🎶Audio Prepraed: ${result.length} samples');
    return result;
  }

  List<List<double>> _computeSTFT(List<double> audio, int nFft, int hopLength) {
    int numFrames = ((audio.length - nFft) / hopLength).floor() + 1;
    int numFreqBins = (nFft / 2).floor() + 1;

    List<List<double>> spectrogram = [];

    for (int frame = 0; frame < numFrames; frame++) {
      int startSample = frame * hopLength;

      // Extract window
      List<double> window = [];
      for (int i = 0; i < nFft; i++) {
        int sampleIndex = startSample + i;
        if (sampleIndex < audio.length) {
          // Apply Hann window
          double hannValue = 0.5 - 0.5 * math.cos(2 * math.pi * i / (nFft - 1));
          window.add(audio[sampleIndex] * hannValue);
        } else {
          window.add(0.0);
        }
      }

      // Compute magnitude spectrum (simplified - normally would use FFT)
      List<double> magnitudes = [];
      for (int freq = 0; freq < numFreqBins; freq++) {
        double real = 0.0;
        double imag = 0.0;

        for (int i = 0; i < window.length; i++) {
          double angle = -2 * math.pi * freq * i / nFft;
          real += window[i] * math.cos(angle);
          imag += window[i] * math.sin(angle);
        }

        double magnitude = math.sqrt(real * real + imag * imag);
        magnitudes.add(magnitude * magnitude); // Power spectrum
      }

      spectrogram.add(magnitudes);
    }

    // Transpose to match librosa format: [freq_bins, time_frames]
    List<List<double>> transposed = [];
    for (int freq = 0; freq < numFreqBins; freq++) {
      List<double> freqBin = [];
      for (int time = 0; time < spectrogram.length; time++) {
        freqBin.add(spectrogram[time][freq]);
      }
      transposed.add(freqBin);
    }

    return transposed;
  }

  List<List<double>> _applyMelFilterBank(
      List<List<double>> spectogram, int sampleRate, int nMels, int nFft) {
    int numFreqBins = spectogram.length;
    int numTimeFrames = spectogram.isNotEmpty ? spectogram[0].length : 0;

    List<List<double>> melFilters =
        _createMelFilterBanks(nMels, numFreqBins, sampleRate, nFft);

    List<List<double>> melSpectogram = [];

    for (int mel = 0; mel < nMels; mel++) {
      List<double> melBin = [];

      for (int time = 0; time < numTimeFrames; time++) {
        double melValue = 0.0;

        for (int freq = 0; freq < numFreqBins; freq++) {
          melValue += spectogram[freq][time] * melFilters[mel][freq];
        }

        melBin.add(melValue);
      }

      melSpectogram.add(melBin);
    }

    return melSpectogram;
  }

  List<List<double>> _createMelFilterBanks(
      int nMels, int numFreqBins, int sampleRate, int nFft) {
    double hzToMel(double hz) => 2595.0 * math.log(1 + hz / 700.0) / math.ln10;
    double melToHz(double mel) => 700.0 * (math.pow(10, mel / 2595.0) - 1);

    double minMel = hzToMel(0);
    double maxMel = hzToMel(sampleRate / 2);

    List<double> melPoints = [];

    for (int i = 0; i <= nMels + 1; i++) {
      double mel = minMel + (maxMel - minMel) * i / (nMels + 1);
      melPoints.add(melToHz(mel));
    }

    List<int> binIndices = melPoints
        .map((hz) => ((numFreqBins - 1) * 2 * hz / sampleRate).floor())
        .toList();

    List<List<double>> filters = [];
    for (int mel = 0; mel < nMels; mel++) {
      List<double> filter = List.filled(numFreqBins, 0.0);

      int leftBin = binIndices[mel];
      int centerBin = binIndices[mel + 1];
      int rightBin = binIndices[mel + 2];

      //LeftSlope

      for (int bin = leftBin; bin <= centerBin; bin++) {
        if (bin < numFreqBins && centerBin != leftBin) {
          filter[bin] = (bin - leftBin) / (centerBin - leftBin);
        }
      }

      //RightSlope
      for (int bin = centerBin; bin <= rightBin; bin++) {
        if (bin < numFreqBins && rightBin != centerBin) {
          filter[bin] = (rightBin - bin) / (rightBin - centerBin);
        }
      }

      filters.add(filter);
    }

    return filters;
  }

  List<List<double>> _powerToDB(List<List<double>> powerSpec) {
    double maxPower = 0.0;

    for (var row in powerSpec) {
      for (var value in row) {
        if (value > maxPower) maxPower = value;
      }
    }

    if (maxPower == 0.0) maxPower = 1e-10;

    List<List<double>> dbSpec = [];
    for (var row in powerSpec) {
      List<double> dbRow = [];
      for (var power in row) {
        double db =
            10.0 * math.log(math.max(power, 1e-10) / maxPower) / math.ln10;
        dbRow.add(db);
      }
      dbSpec.add(dbRow);
    }

    return dbSpec;
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

  List<double> _normalizedAudio(List<double> audio) {
    if (audio.isEmpty) return [];

    double maxAbs = 0.0;
    for (double sample in audio) {
      double absSample = sample.abs();
      if (absSample > maxAbs) {
        maxAbs = absSample;
      }
    }

    if (maxAbs == 0.0) return audio;

    return audio.map((sample) => sample / maxAbs).toList();
  }

  List<double> _resizeAudioLinear(List<double> audio, int targetLength) {
    if (audio.isEmpty) return List.filled(targetLength, 0.0);
    if (audio.length == targetLength) return audio;

    List<double> result = [];

    double ratio = (audio.length - 1) / (targetLength - 1);

    for (int i = 0; i < targetLength; i++) {
      double sourceIndex = i * ratio;
      int lowIndex = sourceIndex.floor();
      int highIndex = math.min(lowIndex + 1, audio.length - 1);

      if (lowIndex == highIndex) {
        result.add(audio[lowIndex]);
      } else {
        double fraction = sourceIndex - lowIndex;
        double interpolated =
            audio[lowIndex] * (1 - fraction) + audio[highIndex] * fraction;

        result.add(interpolated);
      }
    }

    return result;
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
