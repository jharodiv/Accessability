import 'dart:typed_data';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Jarvis/tts_helper.dart';
//import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/huggingface/dory_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'mfcc_service.dart';
//import 'tts_helper.dart';

class WakeWordService {
  final MFCCService _mfccService = MFCCService();
  final TTSHelper _ttsHelper = TTSHelper();

  Interpreter? _interpreter;
  bool _isProcessing = false;

  //LoadTheTFLITEMODEL
  Future<void> loadModel() async {
    try {
      print("✅🔃Loading wake word model...");
      _interpreter = await Interpreter.fromAsset('assets/model/jarvis.tflite');
    } catch (e) {
      print("❌ Error Loading Model: $e");
    }
  }

  /// Process audio bytes and check for wake word
  Future<void> processAudio(Uint8List audioBytes) async {
    if (_isProcessing) {
      print("⏳ Already processing audio, skipping this chunk...");
      return;
    }
    if (_interpreter == null) {
      print("⚠️ Interpreter not loaded yet.");
      return;
    }

    _isProcessing = true;

    try {
      print("🎧 Received audio chunk: ${audioBytes.length} bytes");

      List<double> mfcc = _mfccService.extractMFCC(audioBytes);
      print("🎛 Extracted MFCC vector length: ${mfcc.length}");

      var input = [mfcc]; // Shape: [1,1536]
      var output = List.filled(1, 0.0).reshape([1, 1]);

      _interpreter!.run(input, output);
      double prediction = output[0][0];

      print("📊 Model prediction: $prediction");

      if (prediction > 0.8) {
        print("✅ Wake word detected!");
        await _ttsHelper.speak("Hi!");
        print("💬 TTS spoke 'Hi!'");
        await Future.delayed(Duration(milliseconds: 300));
        // print("🎤 Starting Dory listening...");
        // _doryService.startListening();
      } else {
        print("❌ Wake word not detected (prediction below threshold).");
      }
    } catch (e) {
      print("❌ WakeWordService error: $e");
    }

    _isProcessing = false;
  }
}
