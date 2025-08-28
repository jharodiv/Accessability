import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final _controller = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _controller.stream;

  Future<void> startRecording() async {
    if (!await Permission.microphone.request().isGranted) {
      throw Exception("Microphone permission not granted");
    }

    await _recorder.openRecorder();

    await _recorder.startRecorder(
      toStream: _controller.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );

    Future<void> stopRecording() async {
      await _recorder.stopRecorder();
      await _recorder.closeRecorder();
      await _controller.close();
    }
  }
}
