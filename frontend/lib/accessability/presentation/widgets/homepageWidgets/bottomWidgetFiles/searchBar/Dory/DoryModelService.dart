import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Dorymodelservice {
  Interpreter? _interpreter;
  String? _currentModel;
  bool _isModelLoaded = false;
  List<String>? _classLabels;

  final List<String> _defaultLabels = [
    'dory_speaking',
    'background_noise',
    'other_voice',
    'silence'
  ];

  Future<bool> loadModel(String modelName) async {
    try {
      _interpreter?.close();
      _interpreter = await Interpreter.fromAsset(modelName);
      if (_interpreter == null) {
        print('Failed to create interpreter from assets: $modelName');
        return false;
      }
      _currentModel = modelName;
      _isModelLoaded = true;
      //_classLabels = _defaultLabels;
      try {
        final inputTensor = _interpreter?.getInputTensor(0);
        final outputTensor = _interpreter?.getOutputTensor(0);

        print('Input Shape: ${inputTensor?.shape ?? "unknown"}');
        print('Output Shape: ${outputTensor?.shape ?? "unknown"}');
        print('Input type: ${inputTensor?.type ?? "unknown"}');
        print('Output type: ${outputTensor?.type ?? "unknown"}');
      } catch (e) {
        print('Tensor info not available: $e');
      }
      return true;
    } on PlatformException catch (e) {
      print('❌ PlatformException while loading model: $e');
      return false;
    } catch (e) {
      print('❌ General error loading model: $e');
      return false;
    }
  }

  // Predict from audio features
  DoryPrediction? predict(List<double> audioFeatures) {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Model not loaded');
      return null;
    }

    try {
      // Get model input shape
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;

      print('Input shape expected: $inputShape');
      print('Features provided: ${audioFeatures.length}');

      // Ensure input matches expected shape
      int expectedInputSize =
          inputShape.length > 1 ? inputShape[1] : inputShape[0];
      if (audioFeatures.length != expectedInputSize) {
        print(
            '❌ Input sized mismatch. Expected: $expectedInputSize, Got:${audioFeatures.length}');
        return null;
      }

      // Prepare input tensor
      var input = [audioFeatures]; // Add batch dimension

      // Prepare output tensor
      var output = List.generate(
          outputShape[0], (i) => List.filled(outputShape[1], 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      List<double> probabilities = output[0];

      // Find predicted class
      int predictedIndex = 0;
      double maxProbability = probabilities[0];

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProbability) {
          maxProbability = probabilities[i];
          predictedIndex = i;
        }
      }

      String predictedClass =
          _classLabels != null && predictedIndex < _classLabels!.length
              ? _classLabels![predictedIndex]
              : 'Unknown';

      return DoryPrediction(
        predictedClass: predictedClass,
        confidence: maxProbability,
        probabilities: probabilities,
        classLabels: _classLabels ?? [],
      );
    } catch (e) {
      print('❌ Prediction error: $e');
      return null;
    }
  }

  Map<String, dynamic>? getModelInfo() {
    if (!_isModelLoaded || _interpreter == null) return null;

    return {
      'currentModel': _currentModel,
      'inputShape': _interpreter!.getInputTensor(0).shape,
      'outputShape': _interpreter!.getOutputTensor(0).shape,
      'inputType': _interpreter!.getInputTensor(0).type.toString(),
      'outputType': _interpreter!.getOutputTensor(0).type.toString(),
      'classLabels': _classLabels,
    };
  }

  //check if model is loaded
  bool get isLoaded => _isModelLoaded;

  //Get current model name
  String? get currentModel => _currentModel;

  //Get class labels
  List<String>? get classLabels => _classLabels;

  //Dispose Resources
  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    _currentModel = null;
  }
}

//Prediction result class
class DoryPrediction {
  final String predictedClass;
  final double confidence;
  final List<double> probabilities;
  final List<String> classLabels;

  DoryPrediction({
    required this.predictedClass,
    required this.confidence,
    required this.probabilities,
    required this.classLabels,
  });

  //Get all predictions with confidence rate

  List<ClassPrediction> getAllPredictions() {
    List<ClassPrediction> predictions = [];
    for (int i = 0; i < probabilities.length && i < classLabels.length; i++) {
      predictions.add(ClassPrediction(
        className: classLabels[i],
        confidence: probabilities[i],
      ));
    }
    // Sort by confidence descending
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return predictions;
  }
}

class ClassPrediction {
  final String className;
  final double confidence;

  ClassPrediction({
    required this.className,
    required this.confidence,
  });
}
