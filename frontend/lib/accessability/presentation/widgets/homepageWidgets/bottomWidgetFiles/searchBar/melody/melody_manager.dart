import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

typedef WakeWordCallback = void Function();

class MelodyManager {
  PorcupineManager? _porcupineManager;
  final WakeWordCallback onWakeWordDetected;

  MelodyManager({required this.onWakeWordDetected});

  Future<void> start() async {
    // Request microphone permission
    if (!await Permission.microphone.request().isGranted) {
      print("Microphone permission denied!");
      return;
    }

    final apiKey = dotenv.env['PORCUPINE_API_KEY'] ?? "";
    if (apiKey.isEmpty) {
      print("Porcupine API key missing in .env");
      return;
    }

    _porcupineManager = await PorcupineManager.fromKeywordPaths(
      apiKey,
      ["assets/model/Melody.ppn"],
      (_) => onWakeWordDetected(),
    );

    await _porcupineManager?.start();
  }

  Future<void> stop() async {
    await _porcupineManager?.stop();
    await _porcupineManager?.delete();
  }
}
