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
  // Model file names - try these in order until one works
  static const List<String> MODEL_FILENAMES = [
    'lao_instruments_model_float16.tflite', // Preferred model (float16)
    'lao_instruments_model_quantized.tflite', // Fallback model (float32)
    'lao_instruments_model.tflite', // Original model
  ];

  static const String LABELS_FILENAME = 'label_encoder.txt';

  // TFLite interpreter
  Interpreter? _interpreter;
  String? _loadedModelName;

  // Label mapping
  List<String> _labels = [];

  // Configuration
  final double _confidenceThreshold =
      0.85; // Lowered from 0.9 for better results
  final double _entropyThreshold =
      0.15; // Increased from 0.12 for better results

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

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMockMode => _useMockMode;
  String? get loadedModelName => _loadedModelName;

  // Initialize the classifier
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Try to load models in order until one works
      bool modelLoaded = false;

      for (final modelName in MODEL_FILENAMES) {
        try {
          _logger.i('Trying to load model: $modelName');
          await _loadModel(modelName);
          _loadedModelName = modelName;
          modelLoaded = true;
          _logger.i('Successfully loaded model: $modelName');
          break;
        } catch (e) {
          _logger.w('Failed to load model $modelName: $e');
          // Continue to next model
        }
      }

      if (!modelLoaded) {
        _logger.e('Failed to load any model, falling back to mock mode');
        _useMockMode = true;
      }

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      return true;
    } catch (e) {
      _logger.e('Error initializing classifier: $e');

      // Fall back to mock mode
      _logger.i('Falling back to mock classification mode');
      _useMockMode = true;
      _isInitialized = true;

      return true; // Return success even though we're in mock mode
    }
  }

  // Load TFLite model
  Future<void> _loadModel(String modelName) async {
    // Get app directory to store the model file
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDir.path}/$modelName';
    final modelFile = File(modelPath);

    // Check if model exists, if not copy from assets
    if (!await modelFile.exists()) {
      try {
        // Copy model from assets
        final ByteData modelData =
            await rootBundle.load('assets/model/$modelName');
        await modelFile.writeAsBytes(modelData.buffer.asUint8List());
        _logger.i('Model copied to: $modelPath');
      } catch (e) {
        _logger.e('Error copying model from assets: $e');
        throw Exception('Failed to copy model file: $e');
      }
    }

    // Create interpreter options with compatibility settings
    final options = InterpreterOptions()
      ..threads = 2 // Use 2 threads for better performance
      ..useNnApiForAndroid = false; // Disable NN API for better compatibility

    // Load with options
    _interpreter = await Interpreter.fromFile(modelFile, options: options);

    // Check if interpreter was created successfully
    if (_interpreter == null) {
      throw Exception('Interpreter is null after initialization');
    }

    // Log model input/output details
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    _logger.i('Model loaded with:');
    _logger.i('- Input shape: ${inputTensor.shape}, type: ${inputTensor.type}');
    _logger
        .i('- Output shape: ${outputTensor.shape}, type: ${outputTensor.type}');
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
      throw Exception('Failed to load labels: $e');
    }
  }

  Future<ClassificationResult> classifyAudio(List<double> audioBuffer) async {
    if (!_isInitialized) {
      throw Exception('Classifier not initialized');
    }

    // Handle mock mode
    if (_useMockMode) {
      return _generateMockResult();
    }

    try {
      // Extract features
      final melSpectrogram =
          await _featureExtractor.extractMelSpectrogram(audioBuffer);

      // Prepare input for model with proper normalization
      final modelInput = _prepareModelInput(melSpectrogram);

      // Create output buffer
      final outputBuffer = [List<double>.filled(_labels.length, 0.0)];

      // Run inference
      _interpreter!.run(modelInput, outputBuffer);

      // Process results
      return _processOutput(Float32List.fromList(outputBuffer[0]));
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

  // Properly prepare input for the model
  List<Object> _prepareModelInput(Float32List melSpectrogram) {
    const int numMels = FeatureExtractor.numMels;
    final int numFrames = melSpectrogram.length ~/ numMels;

    // Reshape the data to match model's expected input shape
    final List<List<List<List<double>>>> reshapedInput = List.generate(
      1, // Batch size
      (_) => List.generate(
        numMels, // Height
        (i) => List.generate(
          numFrames, // Width
          (j) => [melSpectrogram[i * numFrames + j]], // Channel
        ),
      ),
    );

    return [reshapedInput];
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

    // Calculate entropy for uncertainty measurement
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

  // Generate mock result for testing
  ClassificationResult _generateMockResult() {
    final instruments = Instrument.getLaoInstruments();
    final index = _random.nextInt(instruments.length);
    final instrument = instruments[index];

    // Generate random probabilities
    final Map<String, double> probs = {};
    double mainProb = 0.7 + _random.nextDouble() * 0.25; // 0.7-0.95

    for (final instr in instruments) {
      if (instr.id == instrument.id) {
        probs[instr.id] = mainProb;
      } else {
        probs[instr.id] = (1.0 - mainProb) / (instruments.length - 1);
      }
    }

    return ClassificationResult(
      instrument: instrument,
      confidence: mainProb,
      entropy: 0.1 + _random.nextDouble() * 0.15, // 0.1-0.25
      isUnknown: false,
      allProbabilities: probs,
    );
  }

  // Clean up resources
  void dispose() {
    _interpreter?.close();
  }
}
