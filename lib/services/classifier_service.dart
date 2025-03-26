import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

import '../models/classification_result.dart';
import '../models/instrument.dart';
import '../utils/feature_extraction.dart';
import '../models/tf_lite_helper.dart';

class ClassifierService {
  // Model file names - updated for DNN model
  static const List<String> MODEL_FILENAMES = [
    'lao_instruments_model_dnn_float16.tflite', // Preferred model (float16)
    'lao_instruments_model_dnn.tflite', // Original model
  ];

  static const String LABELS_FILENAME = 'label_encoder.txt';
  static const String INPUT_INFO_FILENAME =
      'lao_instruments_model_dnn_input_info.json';

  // TFLite interpreter
  Interpreter? _interpreter;
  String? _loadedModelName;

  // Input shape information
  Map<String, int>? _inputInfo;

  // Label mapping
  List<String> _labels = [];

  // Configuration
  final double _confidenceThreshold = 0.90;
  final double _entropyThreshold = 0.1;

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
      // Load labels
      await _loadLabels();

      // Load input shape info
      await _loadInputInfo();

      // Try to load models in order until one works
      bool modelLoaded = false;

      for (final modelName in MODEL_FILENAMES) {
        try {
          _logger.i('Trying to load model: $modelName');
          final interpreter = await TFLiteHelper.loadInterpreter(modelName);
          if (interpreter != null) {
            _interpreter = interpreter;
            _loadedModelName = modelName;
            modelLoaded = true;
            _logger.i('Successfully loaded model: $modelName');
            break;
          }
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

  // Load TFLite model manually - not used anymore, replaced by TFLiteHelper
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
      // Default values for flattened mel spectrogram
      _inputInfo = {
        "input_size": 44160 // For 128 mel bands and ~345 time frames
      };
    }
  }

  // Load label mapping
  Future<void> _loadLabels() async {
    try {
      try {
        // final String labelsData =
        //     await rootBundle.loadString('assets/model/$LABELS_FILENAME');
        // _labels = labelsData.trim().split('\n');
        _labels = ['kheang', 'kong_vong', 'pin', 'ra_nad', 'sing', 'sor_ou'];
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
      // Log buffer size for debugging
      _logger.i('Audio buffer length: ${audioBuffer.length} samples');

      // Ensure buffer is the right length for processing
      List<double> processedBuffer = _padOrTrimBuffer(audioBuffer);
      _logger.i('Processed buffer length: ${processedBuffer.length} samples');

      // Extract features
      final melSpectrogram =
          await _featureExtractor.extractMelSpectrogram(processedBuffer);
      _logger.i('Mel spectrogram length: ${melSpectrogram.length} elements');

      // Get required input size from model
      final inputSize = _inputInfo?['input_size'] ?? 44160;
      _logger.i('Expected model input size: $inputSize');

      // Create input tensor data with proper batch dimension
      final inputShape = [1, inputSize]; // Add batch dimension
      final outputSize = _labels.length;
// Add batch dimension

      // Reshape input tensor if needed
      if (_interpreter != null &&
          _interpreter!.getInputTensor(0).shape != inputShape) {
        _logger.i('Reshaping input tensor to $inputShape');
        _interpreter!.resizeInputTensor(0, inputShape);
        _interpreter!.allocateTensors();
      }

      // Create inputData and copy melSpectrogram into it
      final inputData = List.filled(inputSize, 0.0);
      final copyLength = math.min(melSpectrogram.length, inputSize);
      for (int i = 0; i < copyLength; i++) {
        inputData[i] = melSpectrogram[i];
      }

      _logger.i('Input data prepared, length: ${inputData.length}');

      // Prepare output container
      List<List<double>> outputBuffer = [List<double>.filled(outputSize, 0.0)];

      // Log tensor shapes before inference
      _logger.i('Input tensor shape: ${_interpreter!.getInputTensor(0).shape}');
      _logger
          .i('Output tensor shape: ${_interpreter!.getOutputTensor(0).shape}');

      // Run inference with batch dimension
      _interpreter!.run([inputData], outputBuffer);
      _logger.i('Inference completed successfully');

      // Log the raw output
      _logger.i('Raw output: ${outputBuffer[0]}');

      // Process the first item in the batch (our only result)
      return _processOutput(Float32List.fromList(outputBuffer[0]));
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

  // Helper method to ensure audio buffer has the right length
  List<double> _padOrTrimBuffer(List<double> buffer) {
    // Target duration in samples (4 seconds at 44.1kHz)
    const targetLength = 4 * 44100;

    if (buffer.length == targetLength) {
      return buffer;
    } else if (buffer.length > targetLength) {
      // Take the last 4 seconds if buffer is too long
      return buffer.sublist(buffer.length - targetLength);
    } else {
      // Pad with zeros if buffer is too short
      final result = List<double>.filled(targetLength, 0.0);
      // Copy existing samples
      for (int i = 0; i < buffer.length; i++) {
        result[i] = buffer[i];
      }
      return result;
    }
  }

  // Process model output
  ClassificationResult _processOutput(Float32List outputBuffer) {
    // Log raw output for debugging
    _logger.i('Raw output buffer length: ${outputBuffer.length}');
    if (outputBuffer.isNotEmpty) {
      _logger.i('First few values: ${outputBuffer.take(5).toList()}');
    }

    // Make sure we only take as many values as we have labels
    final List<double> probabilities = [];
    for (int i = 0; i < math.min(outputBuffer.length, _labels.length); i++) {
      probabilities.add(outputBuffer[i]);
    }

    // Apply softmax if needed (if values don't sum to ~1.0)
    double sum = probabilities.fold(0.0, (sum, item) => sum + item);
    if (sum < 0.9 || sum > 1.1) {
      _logger.i('Applying softmax normalization (sum=$sum)');
      // Softmax calculation
      final List<double> expValues =
          probabilities.map((p) => math.exp(p)).toList();
      final double expSum = expValues.fold(0.0, (sum, item) => sum + item);
      for (int i = 0; i < probabilities.length; i++) {
        probabilities[i] = expValues[i] / expSum;
      }
    }

    final Map<String, double> probabilityMap = {};

    // Create probability map
    for (int i = 0; i < _labels.length && i < probabilities.length; i++) {
      probabilityMap[_labels[i]] = probabilities[i];
    }

    // Find the maximum probability and its index
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
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
  }
}
