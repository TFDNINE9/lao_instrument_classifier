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
  // Model file names
  static const String MODEL_FILENAME =
      'lao_instruments_model_compatible.tflite';
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

  // Mock mode flag - will use simulated results when true
  bool _useMockMode = false;

  // Random generator for mock mode
  final math.Random _random = math.Random();

  // Getter for initialization status
  bool get isInitialized => _isInitialized;

  // Getter for mock mode status
  bool get isMockMode => _useMockMode;

  // Initialize the classifier
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Try to load the real model
      await _loadModelWithCompatibility();

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      return true;
    } catch (e) {
      _logger.e('Error initializing classifier: $e');

      // Fall back to mock mode
      _logger.i('Falling back to mock classification mode');

      // Load labels for mock mode
      await _loadLabels();

      // Enable mock mode
      _useMockMode = true;
      _isInitialized = true;

      return true; // Return success even though we're in mock mode
    }
  }

  // Load TFLite model with compatibility options
  Future<void> _loadModelWithCompatibility() async {
    try {
      // Get app directory to store the model file
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final modelFile = File(modelPath);

      // Check if model exists, if not copy from assets
      if (!await modelFile.exists()) {
        try {
          // Copy model from assets
          final ByteData modelData =
              await rootBundle.load('assets/model/$MODEL_FILENAME');
          await modelFile.writeAsBytes(modelData.buffer.asUint8List());
          _logger.i('Model copied to: $modelPath');
        } catch (e) {
          _logger.e('Error copying model from assets: $e');
          rethrow;
        }
      }

      // Create interpreter options with compatibility settings
      final options = InterpreterOptions();

      // Use single thread for better compatibility
      options.threads = 1;

      // Disable NN API which can cause compatibility issues
      options.useNnApiForAndroid = false;

      // Load with compatibility options
      _interpreter = await Interpreter.fromFile(modelFile, options: options);

      // Check if interpreter was created successfully
      if (_interpreter == null) {
        throw Exception('Interpreter is null after initialization');
      }

      _logger.i('Model loaded successfully with compatibility options');
    } catch (e) {
      _logger.e('Error loading model: $e');
      rethrow;
    }
  }

  // Load label mapping
  Future<void> _loadLabels() async {
    try {
      try {
        final String labelsData =
            await rootBundle.loadString('assets/model/$LABELS_FILENAME');
        _labels = labelsData.trim().split('\n');
        _logger.i('Labels loaded successfully: $_labels');
      } catch (e) {
        _logger.w(
            'Could not load labels file, using default Lao instrument labels');

        // Get instrument IDs from the Instrument class
        final instruments = Instrument.getLaoInstruments();
        _labels = instruments.map((i) => i.id).toList();
        _logger.i('Using default labels: $_labels');
      }
    } catch (e) {
      _logger.e('Error loading labels: $e');
      rethrow;
    }
  }

  Future<ClassificationResult> classifyAudio(List<double> audioBuffer) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('Classifier not initialized');
    }

    try {
      // Extract features
      final melSpectrogram =
          await _featureExtractor.extractMelSpectrogram(audioBuffer);

      // Prepare input for model - simplify for compatibility
      final modelInput = _prepareInputForCompatibility(melSpectrogram);

      // Create output buffer with correct shape [1, 6] instead of [6]
      // This matches the expected output shape from the model
      final outputBuffer = [List<double>.filled(_labels.length, 0.0)];

      // Run inference
      _interpreter!.run(modelInput, outputBuffer);

      // Extract the inner array (remove batch dimension)
      final resultArray = outputBuffer[0];

      // Process results with the inner array
      return _processOutput(Float32List.fromList(resultArray));
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

  List<dynamic> _prepareInputForCompatibility(Float32List melSpectrogram) {
    const int numMels = FeatureExtractor.numMels;
    final int numFrames = melSpectrogram.length ~/ numMels;

    // Create a simple 4D input: [1, height, width, channels]
    final input = [
      List.generate(
          numMels,
          (i) => List.generate(
              numFrames, (j) => [melSpectrogram[i * numFrames + j]]))
    ];

    return input;
  }

  // Process model output
  ClassificationResult _processOutput(Float32List outputBuffer) {
    final List<double> probabilities = outputBuffer.toList();
    final Map<String, double> probabilityMap = {};

    for (int i = 0; i < _labels.length && i < probabilities.length; i++) {
      probabilityMap[_labels[i]] = probabilities[i];
    }

    int maxIndex = 0;
    double maxProb = probabilities.isNotEmpty ? probabilities[0] : 0.0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    double entropy = 0.0;
    for (final prob in probabilities) {
      if (prob > 0) {
        entropy -= prob * math.log(prob) / math.ln2;
      }
    }

    final maxEntropy = math.log(_labels.length) / math.ln2;
    final normalizedEntropy = entropy / maxEntropy;

    final bool isUnknown =
        maxProb < _confidenceThreshold || normalizedEntropy > _entropyThreshold;

    if (isUnknown) {
      return ClassificationResult.unknown(
        confidence: maxProb,
        entropy: normalizedEntropy,
        allProbabilities: probabilityMap,
      );
    } else {
      final String predictedId =
          maxIndex < _labels.length ? _labels[maxIndex] : 'unknown';

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
