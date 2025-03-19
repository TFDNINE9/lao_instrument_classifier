import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lao_instrument_classifier/models/classification_result.dart';
import 'package:lao_instrument_classifier/services/audio_service.dart';
import 'package:lao_instrument_classifier/services/classifier_service.dart';
import 'package:lao_instrument_classifier/services/permission_service.dart';
import 'package:logger/logger.dart';

enum ClassifierState {
  uninitialized,
  initializing,
  ready,
  recording,
  processing,
  permissionDenied,
  error,
}

class ClassifierProvider with ChangeNotifier {
  // Services
  final AudioService _audioService = AudioService();
  final ClassifierService _classifierService = ClassifierService();

  // Logger
  final Logger _logger = Logger();

  // State management
  ClassifierState _state = ClassifierState.uninitialized;
  String? _errorMessage;

  // Classification results
  ClassificationResult? _currentResult;
  final List<ClassificationResult> _recentResults = [];

  // Continuous classification timer
  Timer? _classificationTimer;

  // Audio buffer subscription
  StreamSubscription? _audioStreamSubscription;

  // Public getters
  ClassifierState get state => _state;
  String? get errorMessage => _errorMessage;
  ClassificationResult? get currentResult => _currentResult;
  List<ClassificationResult> get recentResults => _recentResults;
  Stream<double> get volumeStream => _audioService.volumeStream;

  // Initialize the classifier
  Future<void> initialize() async {
    if (_state == ClassifierState.initializing ||
        _state == ClassifierState.ready) {
      return;
    }

    _state = ClassifierState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check microphone permission
      final hasPermission =
          await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        _state = ClassifierState.permissionDenied;
        notifyListeners();
        return;
      }

      // Initialize the classifier
      final initialized = await _classifierService.initialize();
      if (!initialized) {
        _state = ClassifierState.error;
        _errorMessage = 'Failed to initialize classifier';
        notifyListeners();
        return;
      }

      _state = ClassifierState.ready;
      notifyListeners();
    } catch (e) {
      _logger.e('Error initializing classifier: $e');
      _state = ClassifierState.error;
      _errorMessage = 'Initialization error: ${e.toString()}';
      notifyListeners();
    }
  }

  // Start continuous recording and classification
  Future<void> startClassification() async {
    if (_state != ClassifierState.ready) {
      if (_state == ClassifierState.uninitialized) {
        await initialize();
      } else {
        return;
      }
    }

    try {
      // Start recording
      final started = await _audioService.startRecording();
      if (!started) {
        _state = ClassifierState.error;
        _errorMessage = 'Failed to start recording';
        notifyListeners();
        return;
      }

      _state = ClassifierState.recording;
      notifyListeners();

      // Set up audio stream subscription for classification
      _audioStreamSubscription =
          _audioService.audioStream.listen((audioBuffer) {
        // Process every 500ms to avoid overwhelming the device
        if (_classificationTimer == null || !_classificationTimer!.isActive) {
          _classificationTimer = Timer(const Duration(milliseconds: 500), () {
            _classifyCurrentAudio(audioBuffer);
          });
        }
      });
    } catch (e) {
      _logger.e('Error starting classification: $e');
      _state = ClassifierState.error;
      _errorMessage = 'Recording error: ${e.toString()}';
      notifyListeners();
    }
  }

  // Stop recording and classification
  Future<void> stopClassification() async {
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    _classificationTimer?.cancel();
    _classificationTimer = null;

    if (_state == ClassifierState.recording ||
        _state == ClassifierState.processing) {
      await _audioService.stopRecording();
      _state = ClassifierState.ready;
      notifyListeners();
    }
  }

  // Classify current audio buffer
  Future<void> _classifyCurrentAudio(List<double> audioBuffer) async {
    if (_state != ClassifierState.recording) return;

    _state = ClassifierState.processing;
    notifyListeners();

    try {
      final result = await _classifierService.classifyAudio(audioBuffer);

      // Update current result
      _currentResult = result;

      // Add to recent results (keep last 10)
      _recentResults.insert(0, result);
      if (_recentResults.length > 10) {
        _recentResults.removeLast();
      }

      _state = ClassifierState.recording;
      notifyListeners();
    } catch (e) {
      _logger.e('Error classifying audio: $e');
      // Don't update state to error, just continue recording
      _state = ClassifierState.recording;
      notifyListeners();
    }
  }

  // Save current audio for testing or feedback
  Future<String?> saveCurrentAudio(String filename) async {
    if (_state != ClassifierState.recording &&
        _state != ClassifierState.ready) {
      return null;
    }

    try {
      return await _audioService.saveBufferToFile(filename);
    } catch (e) {
      _logger.e('Error saving audio: $e');
      return null;
    }
  }

  // Play a saved audio file
  Future<void> playAudioFile(String path) async {
    try {
      await _audioService.playAudioFile(path);
    } catch (e) {
      _logger.e('Error playing audio: $e');
    }
  }

  // Clear recent results
  void clearRecentResults() {
    _recentResults.clear();
    notifyListeners();
  }

  // Clean up resources
  @override
  void dispose() {
    stopClassification();
    _audioService.dispose();
    _classifierService.dispose();
    super.dispose();
  }
}
