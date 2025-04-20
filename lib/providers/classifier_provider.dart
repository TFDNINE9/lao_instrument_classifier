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
  revealingResult,
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

  // Recording configuration
  final int _recordingDurationSeconds = 5; // 5 seconds of recording
  Timer? _recordingTimer;

  // Audio buffer subscription
  StreamSubscription? _audioStreamSubscription;

  // Recording progress
  double _recordingProgress = 0.0;

  // Public getters
  ClassifierState get state => _state;
  String? get errorMessage => _errorMessage;
  ClassificationResult? get currentResult => _currentResult;
  List<ClassificationResult> get recentResults => _recentResults;
  Stream<double> get volumeStream => _audioService.volumeStream;
  double get recordingProgress => _recordingProgress;

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

  // Start recording for fixed duration
  Future<void> startClassification() async {
    if (_state != ClassifierState.ready) {
      if (_state == ClassifierState.uninitialized) {
        await initialize();
      } else {
        return;
      }
    }

    try {
      // Reset recording progress
      _recordingProgress = 0.0;
      notifyListeners();

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

      // Start a timer to update recording progress
      const progressUpdateInterval = Duration(milliseconds: 100);
      final totalUpdates = _recordingDurationSeconds *
          (1000 / progressUpdateInterval.inMilliseconds);
      int currentUpdate = 0;

      _recordingTimer = Timer.periodic(progressUpdateInterval, (timer) {
        if (currentUpdate < totalUpdates) {
          currentUpdate++;
          _recordingProgress = currentUpdate / totalUpdates;
          notifyListeners();
        } else {
          timer.cancel();
          // Automatically stop recording and process when time is up
          stopClassification();
        }
      });

      // Set up audio stream subscription to collect data
      _audioStreamSubscription =
          _audioService.audioStream.listen((audioBuffer) {
        // Just collect the data, we'll process it when recording stops
      });
    } catch (e) {
      _logger.e('Error starting classification: $e');
      _state = ClassifierState.error;
      _errorMessage = 'Recording error: ${e.toString()}';
      notifyListeners();
    }
  }

  // Stop recording and classify audio
  Future<void> stopClassification() async {
    // Cancel the progress timer if it's running
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Cancel audio stream subscription
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    if (_state == ClassifierState.recording) {
      try {
        // Update state to processing
        _state = ClassifierState.processing;
        notifyListeners();

        // Stop recording and get the audio buffer
        final audioBuffer = await _audioService.stopRecording();

        if (audioBuffer.isNotEmpty) {
          // Process the complete audio buffer
          final result = await _classifierService.classifyAudio(audioBuffer);

          // Update current result
          _currentResult = result;

          // Add to recent results (keep last 10)
          if (!result.isUnknown || result.confidence > 0.3) {
            // Only save meaningful results
            _recentResults.insert(0, result);
            if (_recentResults.length > 10) {
              _recentResults.removeLast();
            }
          }
        }

        // Show result reveal animation
        _state = ClassifierState.revealingResult;
        _recordingProgress = 0.0;
        notifyListeners();

        // After 2 seconds, return to ready state (animation will be handled in UI)
        // This gives time for the result reveal animation to play
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (_state == ClassifierState.revealingResult) {
            _state = ClassifierState.ready;
            notifyListeners();
          }
        });
      } catch (e) {
        _logger.e('Error processing audio: $e');
        _state = ClassifierState.error;
        _errorMessage = 'Processing error: ${e.toString()}';
        notifyListeners();
      }
    }
  }

  // Save current audio for testing or feedback
  Future<String?> saveCurrentAudio(String filename) async {
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
    _recordingTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _audioService.dispose();
    _classifierService.dispose();
    super.dispose();
  }
}
