import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lao_instrument_classifier/services/audio_processing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

import '../models/classification_result.dart';
import '../models/instrument.dart';

class ClassifierService {
  // Model file names
  static const List<String> MODEL_FILENAMES = [
    'lao_instruments_model_dnn_attention_float16.tflite', // Preferred model (float16)
    'lao_instruments_model_dnn_attention.tflite', // Original model
  ];

  static const String LABELS_FILENAME = 'label_encoder.txt';
  static const String INPUT_INFO_FILENAME =
      'lao_instruments_model_dnn_attention_input_info.json';

  // TFLite interpreter
  Interpreter? _interpreter;
  String? _loadedModelName;

  // Input shape information
  Map<String, dynamic>? _inputInfo;

  // Label mapping
  List<String> _labels = [];

  // Audio processor
  late AudioProcessor _audioProcessor;

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
      // Initialize the audio processor
      _audioProcessor = AudioProcessor();

      // Load labels
      await _loadLabels();

      // Load input shape info
      await _loadInputInfo();

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
    _interpreter = Interpreter.fromFile(modelFile, options: options);

    // Check if interpreter was created successfully
    if (_interpreter == null) {
      throw Exception('Interpreter is null after initialization');
    }

    // Initialize the audio processor with the model
    await _audioProcessor.initializeModel(modelPath);

    // Log model input/output details
    final inputTensor = _interpreter!.getInputTensors()[0];
    final outputTensor = _interpreter!.getOutputTensors()[0];

    _logger.i('Model loaded with:');
    _logger.i('- Input shape: ${inputTensor.shape}, type: ${inputTensor.type}');
    _logger
        .i('- Output shape: ${outputTensor.shape}, type: ${outputTensor.type}');
  }

  // Load input shape information
  Future<void> _loadInputInfo() async {
    try {
      final String infoData =
          await rootBundle.loadString('assets/model/$INPUT_INFO_FILENAME');
      _inputInfo = json.decode(infoData);
      _logger.i('Input info loaded: $_inputInfo');
    } catch (e) {
      _logger.w('Could not load input info, using default values: $e');
      // Default values for attention model
      _inputInfo = {
        "max_segments": 5,
        "segment_feature_dim": 43648, // Approximate based on 128 mel bands
        "total_input_size": 218240
      };
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
        // Add background class
        _labels.add('background');
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
      // Log buffer size for debugging
      _logger.i('Audio buffer length: ${audioBuffer.length} samples');

      // Check if the audio buffer is essentially silence
      if (_isEssentiallySilence(audioBuffer)) {
        _logger
            .i('Audio buffer is essentially silence, returning unknown result');
        return ClassificationResult.unknown(
          confidence: 0.0,
          entropy: 1.0,
          allProbabilities: {for (var label in _labels) label: 0.0},
        );
      }

      // Use the audio processor to classify audio
      final result = await _audioProcessor.classifyAudio(audioBuffer, _labels);

      // Extract data from result
      final String predictedInstrument = result['instrument'];
      final double confidence = result['confidence'];
      final double entropy = result['entropy'];
      final bool isUnknown = result['isUnknown'];
      final Map<String, double> allProbabilities = result['allProbabilities'];

      // Create classification result
      if (isUnknown) {
        return ClassificationResult.unknown(
          confidence: confidence,
          entropy: entropy,
          allProbabilities: allProbabilities,
        );
      } else {
        final instrument = Instrument.findById(predictedInstrument) ??
            Instrument(
              id: predictedInstrument,
              name: predictedInstrument,
              description: 'A Lao musical instrument.',
              imagePath: 'assets/images/default_instrument.png',
            );

        return ClassificationResult(
          instrument: instrument,
          confidence: confidence,
          entropy: entropy,
          isUnknown: false,
          allProbabilities: allProbabilities,
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error classifying audio: $e');
      _logger.e('Stack trace: $stackTrace');

      // Return unknown if there's an error
      return ClassificationResult.unknown(
        confidence: 0.0,
        entropy: 1.0,
        allProbabilities: {for (var label in _labels) label: 0.0},
      );
    }
  }

  // Check if audio buffer is essentially silence
  bool _isEssentiallySilence(List<double> audioBuffer) {
    // Calculate RMS volume
    double sumSquared = 0.0;
    for (final sample in audioBuffer) {
      sumSquared += sample * sample;
    }
    double rms = math.sqrt(sumSquared / audioBuffer.length);

    // Return true if below threshold (experiment with this value)
    return rms < 0.01;
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
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
    _audioProcessor.dispose();
  }
}
