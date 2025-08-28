import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart';
//import 'package:flutter_fft/flutter_fft.dart';

class MFCCService {
  final int sampleRate = 16000;
  final int frameSize = 400; // 25 ms frames
  final int hopSize = 160; // 10 ms hop
  final int numCoeffs = 16; // MFCC per frame
  final int targetLength = 1536;

  /// Converts raw PCM16 bytes (Uint8List) to Float32 normalized audio
  Float32List pcm16ToFloat32(Uint8List audioBytes) {
    final buffer = Int16List.view(audioBytes.buffer);
    final floatBuffer = Float32List(buffer.length);
    for (int i = 0; i < buffer.length; i++) {
      floatBuffer[i] = buffer[i] / 32768.0;
    }
    return floatBuffer;
  }

  /// Main function: converts Float32List audio → flattened MFCC vector
  List<double> extractMFCC(Uint8List audioBytes) {
    final audio = pcm16ToFloat32(audioBytes);
    List<double> mfccFeatures = [];

    for (int start = 0; start + frameSize <= audio.length; start += hopSize) {
      final frame = audio.sublist(start, start + frameSize);

      // 1️⃣ Pre-emphasis
      for (int i = frame.length - 1; i > 0; i--) {
        frame[i] = frame[i] - 0.97 * frame[i - 1];
      }

      // 2️⃣ Hamming window
      for (int i = 0; i < frame.length; i++) {
        frame[i] *= 0.54 - 0.46 * cos(2 * pi * i / (frame.length - 1));
      }

      // 3️⃣ FFT
      final fft = FFT(frame.length);
      final fftComplex = fft.realFft(frame);
      final magnitude = fftComplex.discardConjugates().magnitudes().toList();

      // 4️⃣ Mel filterbank approximation
      // For simplicity, take first `numCoeffs` magnitude bins as MFCC placeholder
      for (int i = 0; i < numCoeffs; i++) {
        mfccFeatures
            .add(magnitude[i].isFinite ? log(magnitude[i] + 1e-8) : 0.0);
      }
    }

    // 5️⃣ Flatten / pad / truncate to match model input
    if (mfccFeatures.length > targetLength) {
      mfccFeatures = mfccFeatures.sublist(0, targetLength);
    } else if (mfccFeatures.length < targetLength) {
      mfccFeatures.addAll(List.filled(targetLength - mfccFeatures.length, 0.0));
    }

    return mfccFeatures;
  }
}
