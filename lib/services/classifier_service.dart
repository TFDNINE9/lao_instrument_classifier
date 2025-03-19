import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

import '../models/classification_result.dart';
import '../models/instrument.dart';
import '../utils/feature_extraction.dart';

class ClassifierService {
  // ignore: constant_identifier_names
  static const String MODEL_FILENAME = 'lao_instruments_model_quantized.tflite';
  // ignore: constant_identifier_names
  static const String LABELS_FILENAME = 'label_encoder.txt';

  // TFLite interpreter
  Interpreter? _interpreter;

  // Label mapping
  List<String> _labels = [];

  // Configuration
  final double _confidenceThreshold = 0.9;
  final double _entropyThreshold = 0.12;

  // Feature extractor
  final FeatureExtractor _featureExtractor = FeatureExtractor();

  // Logger
  final Logger _logger = Logger();

  // Initialization flag
  bool _isInitialized = false;

  // Getter for initialization status
  bool get isInitialized => _isInitialized;

  // Initialize the classifier
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Load model
      await _loadModel();

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      return true;
    } catch (e) {
      _logger.e('Error initializing classifier: $e');
      return false;
    }
  }

  // Load TFLite model
  Future<void> _loadModel() async {
    try {
      // Get app directory to store the model file
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';

      // Check if model exists, if not copy from assets
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        // Copy model from assets
        final modelData = await rootBundle.load('assets/model/$MODEL_FILENAME');
        await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      }

      // Load the interpreter with custom options for better performance
      final options = InterpreterOptions()
        ..threads = 4 // Use 4 threads for inference
        ..useNnApiForAndroid =
            true; // Use Android Neural Networks API if available

      // ignore: await_only_futures
      _interpreter = await Interpreter.fromFile(modelFile, options: options);

      _logger.i('Model loaded successfully.');
      _logger.i('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      _logger.i('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      _logger.e('Error loading model: $e');
      rethrow;
    }
  }

  // Load label mapping
  Future<void> _loadLabels() async {
    try {
      final String labelsData =
          await rootBundle.loadString('assets/model/$LABELS_FILENAME');
      _labels = labelsData.trim().split('\n');
      _logger.i('Labels loaded successfully: $_labels');
    } catch (e) {
      _logger.e('Error loading labels: $e');
      rethrow;
    }
  }

  // Classify audio buffer
  Future<ClassificationResult> classifyAudio(List<double> audioBuffer) async {
    if (!_isInitialized) {
      throw Exception('Classifier not initialized');
    }

    try {
      // Extract features
      final melSpectrogram =
          await _featureExtractor.extractMelSpectrogram(audioBuffer);

      // Prepare input for model
      final modelInput = _featureExtractor.prepareModelInput(melSpectrogram);

      // Get the number of frames in the spectrogram
      const int numMels = FeatureExtractor.numMels;
      final int numFrames = modelInput.length ~/ numMels;

      // Get input tensor info from the model
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;

      _logger.i('Model expects input shape: $inputShape');
      _logger.i('Got spectrogram with mels: $numMels, frames: $numFrames');

      // Prepare input buffer with the correct shape
      // Most TFLite models expect shape [batch_size, height, width, channels]
      // For spectrograms this is typically [1, num_mels, num_frames, 1]
      final inputArray = [
        [
          modelInput.reshape([numMels, numFrames, 1])
        ]
      ];

      // Create output buffer for the result
      // This typically has shape [1, num_classes]
      final outputShape = [1, _labels.length];
      final outputBuffer =
          List.filled(outputShape.reduce((a, b) => a * b), 0.0);

      // Run inference
      _interpreter!.run(inputArray, outputBuffer);

      // Convert output buffer to Float32List for further processing
      final Float32List probabilities =
          Float32List.fromList(outputBuffer.map((e) => e.toDouble()).toList());

      // Process results
      return _processOutput(probabilities);
    } catch (e) {
      _logger.e('Error classifying audio: $e');
      // Return unknown if there's an error
      return ClassificationResult.unknown(
        confidence: 0.0,
        entropy: 1.0,
        allProbabilities: {for (var label in _labels) label: 0.0},
      );
    }
  }

  // Process model output
  ClassificationResult _processOutput(Float32List outputBuffer) {
    // Get probabilities for each class
    final List<double> probabilities = outputBuffer.toList();

    // Create map of class probabilities
    final Map<String, double> probabilityMap = {};
    for (int i = 0; i < _labels.length && i < probabilities.length; i++) {
      probabilityMap[_labels[i]] = probabilities[i];
    }

    // Find the class with highest probability
    int maxIndex = 0;
    double maxProb = probabilities.isNotEmpty ? probabilities[0] : 0.0;
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    // Calculate entropy to measure prediction certainty
    double entropy = 0.0;
    for (final prob in probabilities) {
      if (prob > 0) {
        entropy -= prob * math.log(prob) / math.ln2;
      }
    }

    // Normalize entropy (0-1 scale)
    final maxEntropy = math.log(_labels.length) / math.ln2;
    final normalizedEntropy = entropy / maxEntropy;

    // Check if prediction should be classified as unknown
    final bool isUnknown =
        maxProb < _confidenceThreshold || normalizedEntropy > _entropyThreshold;

    if (isUnknown) {
      return ClassificationResult.unknown(
        confidence: maxProb,
        entropy: normalizedEntropy,
        allProbabilities: probabilityMap,
      );
    } else {
      // Get instrument object for the predicted class
      final String predictedId = maxIndex < _labels.length
          ? _labels[maxIndex].toLowerCase().replaceAll(' ', '_')
          : 'unknown';
      final instrument = Instrument.findById(predictedId) ??
          Instrument(
            id: predictedId,
            name: maxIndex < _labels.length ? _labels[maxIndex] : 'Unknown',
            description: 'A Lao musical instrument.',
            imagePath: 'assets/images/default_instrument.png',
          );

      return ClassificationResult(
        instrument: instrument,
        confidence: maxProb,
        entropy: normalizedEntropy,
        isUnknown: false,
        allProbabilities: probabilityMap,
      );
    }
  }

  // Clean up resources
  void dispose() {
    _interpreter?.close();
  }
}
