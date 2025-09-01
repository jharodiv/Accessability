import 'dart:async';
import 'dart:typed_data';
//import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Jarvis/wakeword_service.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  //final WakeWordService wakeWordService;

  final StreamController<Uint8List> audioStreamController =
      StreamController.broadcast();

  //Prevent Spam Triggers
  bool _wakeWordDetectedRecently = false;

  Timer? _cooldownTimer;

  //Ignore Audio during startup
  bool _ignoreStartupAudio = true;

  Future<void> startRecording() async {
    if (!await Permission.microphone.request().isGranted) {
      throw Exception("Microphone permission not granted");
    }
    await _recorder.openRecorder();

    // Add a slight delay before listening to audio
    await Future.delayed(Duration(milliseconds: 200));

    final controller = StreamController<Uint8List>.broadcast();
    await _recorder.startRecorder(
      toStream: controller.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );

    controller.stream.listen((bytes) {
      _handleAudioData(bytes);
    });
  }

  void _handleAudioData(Uint8List data) {
    //Skip detection if cooldown is active
    if (_wakeWordDetectedRecently) {
      return; //ignore audio until cooldown is over
    }

    //push audio to wake word service
    audioStreamController.add(data);
  }

  void onWakeWordDetected() {
    print("🎤 Wake word detected!");

    _wakeWordDetectedRecently = true;

    //Start Cooldown: prevent multiple detections within 2 seconds
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: 2), () {
      _wakeWordDetectedRecently = false;
      print("♻️ cooldown ended, listening again");
    });
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
    audioStreamController.close();
    _cooldownTimer?.cancel();
  }

  Future<void> stopRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    print("⛔ Recording stopped.");
  }
}
