import 'dart:async';
import 'dart:typed_data';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Jarvis/wakeword_service.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final WakeWordService wakeWordService;

  AudioService({required this.wakeWordService});

  StreamSubscription? _audioSubscription;

  Future<void> startRecording() async {
    if (!await Permission.microphone.request().isGranted) {
      throw Exception("Microphone permission not granted");
    }

    await wakeWordService.loadModel();
    await _recorder.openRecorder();

    // Listen to the audio stream
    final controller = StreamController<Uint8List>.broadcast();
    _audioSubscription = controller.stream.listen((chunk) async {
      print("🎤 Audio chunk received: ${chunk.length} bytes");
      await wakeWordService.processAudio(chunk);
    });

    await _recorder.startRecorder(
      toStream: controller.sink, // push PCM16 bytes here
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );

    print("🎧 Recording started!");
  }

  Future<void> stopRecording() async {
    await _audioSubscription?.cancel();
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    print("⛔ Recording stopped.");
  }
}