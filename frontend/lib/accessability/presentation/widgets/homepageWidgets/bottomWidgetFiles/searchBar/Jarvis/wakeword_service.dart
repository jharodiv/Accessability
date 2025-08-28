import 'dart:typed_data';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Jarvis/tts_helper.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/huggingface/dory_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'mfcc_service.dart';
//import 'tts_helper.dart';

class WakeWordService {
  final MFCCService _mfccService = MFCCService();
  final DoryService _doryService = DoryService();
  final TTSHelper _ttsHelper = TTSHelper();

  Interpreter? _interpreter;
  bool _isProcessing = false;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('rhaspi.tflite');
  }

  Future<void> processAudio(Uint8List audioBytes) async {
    if (_isProcessing || _interpreter == null) return;
    _isProcessing = true;

    try {
      List<double> mfcc = _mfccService.extractMFCC(audioBytes);

      var input = [mfcc]; // Shape: [1,1536]
      var output = List.filled(1, 0.0).reshape([1, 1]);

      _interpreter!.run(input, output);
      double prediction = output[0][0];

      if (prediction > 0.8) { // threshold
        print("Wake word detected!");
        await _ttsHelper.speak("Hi!");
        await Future.delayed(Duration(milliseconds: 300));
        //_doryService.startListening();
      }
    } catch (e) {
      print("WakeWordService error: $e");
    }

    _isProcessing = false;
  }
}
