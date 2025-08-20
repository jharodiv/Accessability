import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Dorymodelservice {
  Interpreter? _interpreter;
  String? _currentModel;
  bool _isModelLoaded = false;
  List<String>? _classLabels;

  final List<String> _defaultLabels = ['wake', 'not_wake', 'noise'];

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
      _classLabels = _defaultLabels;
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

  DoryPrediction? predict(List<List<double>> audioFeatures2D) {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Model is not loaded');
      return null;
    }
    try {
      // Convert 2D -> 4D for Conv2D input: [1, height, width, 1]
      var input4D = List.generate(
        1, // batch size
        (_) => List.generate(
          audioFeatures2D.length, // height
          (i) => List.generate(
            audioFeatures2D[i].length, // width
            (j) => [audioFeatures2D[i][j]], // channel dimension
          ),
        ),
      );

      var outputShape = _interpreter!.getOutputTensor(0).shape;
      var output = List.generate(
          outputShape[0], (i) => List.filled(outputShape[1], 0.0));

      //Run inference
      _interpreter!.run(input4D, output);

      //Process results
      List<double> probabilities = output[0];

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
      print('Prediction error: $e');
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
