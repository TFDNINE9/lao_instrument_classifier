import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:lao_instrument_classifier/models/complex.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

/// Class to perform audio feature extraction and classification
/// with support for overlapping windows similar to the Python training code
class AudioProcessor {
  // Configuration - should match Python training values
  static const int sampleRate = 44100;
  static const int segmentDuration = 4; // seconds per segment
  static const double overlap = 0.5; // 50% overlap between segments
  static const int maxSegments = 5; // Maximum number of segments to process
  static const int nMels = 128; // Number of mel bands
  static const int nFft = 2048; // FFT size
  static const int hopLength = 512; // Hop length for STFT
  static const double fMax = 8000.0; // Maximum frequency

  // Pre-computed mel filterbank matrix
  late List<List<double>> _melFilterbank;
  // Hann window for STFT computation
  late List<double> _hannWindow;

  // TFLite Interpreter
  Interpreter? _interpreter;
  int _segmentFeatureDim = 0;

  AudioProcessor() {
    _initializeFilterbank();
    _initializeHannWindow();
  }

  /// Initialize the model from a file path
  Future<bool> initializeModel(String modelPath) async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter =
          await Interpreter.fromFile(File(modelPath), options: options);

      if (_interpreter != null) {
        // Get input and output shapes
        final inputShape = _interpreter!.getInputTensor(0).shape;
        _segmentFeatureDim =
            inputShape[2]; // [batch_size, max_segments, feature_dim]

        print('Model loaded with input shape: $inputShape');
        return true;
      }
      return false;
    } catch (e) {
      print('Error initializing model: $e');
      return false;
    }
  }

  /// Initialize the Mel filterbank
  void _initializeFilterbank() {
    _melFilterbank =
        _createMelFilterbank(nMels, nFft ~/ 2 + 1, sampleRate, 0.0, fMax);
  }

  /// Initialize the Hann window for STFT
  void _initializeHannWindow() {
    _hannWindow = List<double>.filled(nFft, 0.0);
    for (int i = 0; i < nFft; i++) {
      _hannWindow[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (nFft - 1)));
    }
  }

  /// Create mel filterbank matrix - matches librosa implementation
  List<List<double>> _createMelFilterbank(
      int numMels, int numFft, int sampleRate, double fMin, double fMax) {
    // Convert Hz to Mel
    double hzToMel(double hz) {
      return 2595.0 * math.log(1.0 + hz / 700.0) / math.log(10);
    }

    // Convert Mel to Hz
    double melToHz(double mel) {
      return 700.0 * (math.pow(10.0, mel / 2595.0) - 1.0);
    }

    // Create mel points
    List<double> melPoints = List<double>.filled(numMels + 2, 0.0);
    final double melMin = hzToMel(fMin);
    final double melMax = hzToMel(fMax);

    for (int i = 0; i < numMels + 2; i++) {
      melPoints[i] = melMin + i * (melMax - melMin) / (numMels + 1);
    }

    // Convert to Hz
    List<double> hzPoints = melPoints.map(melToHz).toList();

    // Convert to FFT bins
    List<int> bins = hzPoints
        .map((hz) => ((hz * numFft) / sampleRate).round().clamp(0, numFft - 1))
        .toList();

    // Create filterbank
    List<List<double>> filterbank =
        List.generate(numMels, (i) => List<double>.filled(numFft, 0.0));

    for (int i = 0; i < numMels; i++) {
      for (int j = bins[i]; j < bins[i + 2]; j++) {
        if (j < bins[i + 1]) {
          // Upward slope
          filterbank[i][j] = (j - bins[i]) / (bins[i + 1] - bins[i]);
        } else {
          // Downward slope
          filterbank[i][j] = (bins[i + 2] - j) / (bins[i + 2] - bins[i + 1]);
        }
      }
    }

    return filterbank;
  }

  /// Compute the Short-Time Fourier Transform
  List<List<Complex>> _computeSTFT(List<double> audioBuffer) {
    final bufferLength = audioBuffer.length;
    final numFrames = ((bufferLength - nFft) / hopLength).floor() + 1;

    List<List<Complex>> stft = [];
    final fft = FFT(nFft);

    for (int frame = 0; frame < numFrames; frame++) {
      final start = frame * hopLength;

      // Extract frame and apply window
      final List<double> windowedFrame = List<double>.filled(nFft, 0.0);
      for (int i = 0; i < nFft && start + i < bufferLength; i++) {
        windowedFrame[i] = audioBuffer[start + i] * _hannWindow[i];
      }

      // Compute FFT
      final frameFFT = fft.realFft(windowedFrame);
      stft.add(convertToComplexList(frameFFT));
    }

    return stft;
  }

  /// Compute mel spectrogram from STFT
  List<List<double>> _computeMelSpectrogram(List<List<Complex>> stft) {
    final numFrames = stft.length;
    final numFreqs = nFft ~/ 2 + 1;

    // Compute power spectrogram
    List<List<double>> powerSpec =
        List.generate(numFrames, (_) => List<double>.filled(numFreqs, 0.0));

    for (int frame = 0; frame < numFrames; frame++) {
      for (int freq = 0; freq < numFreqs && freq < stft[frame].length; freq++) {
        final Complex c = stft[frame][freq];
        powerSpec[frame][freq] = c.real * c.real + c.imag * c.imag;
      }
    }

    // Apply mel filterbank
    List<List<double>> melSpec =
        List.generate(numFrames, (_) => List<double>.filled(nMels, 0.0));

    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < nMels; mel++) {
        double sum = 0.0;
        for (int freq = 0; freq < numFreqs; freq++) {
          sum += powerSpec[frame][freq] * _melFilterbank[mel][freq];
        }
        melSpec[frame][mel] = sum;
      }
    }

    // Convert to decibels with small epsilon to avoid log(0)
    const double epsilon = 1e-10;
    double maxVal = double.negativeInfinity;

    // Find max value for reference
    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < nMels; mel++) {
        if (melSpec[frame][mel] > maxVal) {
          maxVal = melSpec[frame][mel];
        }
      }
    }

    // Convert to dB using the max value as reference
    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < nMels; mel++) {
        melSpec[frame][mel] = 10.0 *
            math.log((melSpec[frame][mel] + epsilon) / (maxVal + epsilon)) /
            math.ln10;
      }
    }

    return melSpec;
  }

  /// Extract features with overlapping windows
  Future<List<Float32List>> extractFeaturesWithOverlappingWindows(
      List<double> audioBuffer) async {
    // Calculate segment length and hop length in samples
    final segmentLength = segmentDuration * sampleRate;
    final segmentHop = (segmentLength * (1 - overlap)).toInt();

    // Calculate number of segments
    int numSegments = 1 + (audioBuffer.length - segmentLength) ~/ segmentHop;
    numSegments = math.min(numSegments, maxSegments);

    // Extract features for each segment
    List<Float32List> segmentFeatures = [];

    for (int i = 0; i < numSegments; i++) {
      final start = i * segmentHop;
      final end = start + segmentLength;

      // Ensure we don't go beyond the audio length
      if (end > audioBuffer.length) {
        break;
      }

      // Extract segment
      final segment = audioBuffer.sublist(start, end);

      // Compute STFT
      final stft = _computeSTFT(segment);

      // Compute mel spectrogram
      final melSpec = _computeMelSpectrogram(stft);

      // Flatten mel spectrogram to 1D array
      final features = Float32List(
          _segmentFeatureDim > 0 ? _segmentFeatureDim : nMels * melSpec.length);

      int idx = 0;
      for (int mel = 0; mel < nMels; mel++) {
        for (int frame = 0; frame < melSpec.length; frame++) {
          if (idx < features.length) {
            features[idx++] = melSpec[frame][mel];
          }
        }
      }

      // Add to list of segment features
      segmentFeatures.add(features);
    }

    // If we have fewer than MAX_SEGMENTS, pad with zeros
    while (segmentFeatures.length < maxSegments) {
      // Create a zero-filled array of the same shape as other segments
      final zeroSegment = Float32List(_segmentFeatureDim > 0
          ? _segmentFeatureDim
          : nMels * (segmentLength ~/ hopLength + 1));
      segmentFeatures.add(zeroSegment);
    }

    return segmentFeatures.sublist(0, maxSegments);
  }

  /// Classify audio using the loaded model
  Future<Map<String, dynamic>> classifyAudio(
      List<double> audioBuffer, List<String> labels) async {
    if (_interpreter == null) {
      throw Exception('Model not initialized');
    }

    try {
      // Extract features with overlapping windows
      final segmentFeatures =
          await extractFeaturesWithOverlappingWindows(audioBuffer);

      // Prepare input tensor - shape [1, MAX_SEGMENTS, feature_dim]
      final inputShape = [1, maxSegments, segmentFeatures[0].length];
      final input = List.generate(
        inputShape[0],
        (_) => List.generate(
          inputShape[1],
          (i) => segmentFeatures[i].toList(),
        ),
      );

      // Prepare output tensor - shape [1, num_classes]
      final outputShape = [1, labels.length];
      final output = List.generate(
        outputShape[0],
        (_) => List<double>.filled(outputShape[1], 0),
      );

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      final probabilities = output[0];

      // Find the class with highest probability
      int maxIdx = 0;
      double maxProb = probabilities[0];

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      // Calculate entropy for uncertainty measurement
      double entropy = 0.0;
      for (final prob in probabilities) {
        if (prob > 0) {
          entropy -= prob * math.log(prob) / math.ln2;
        }
      }

      final maxEntropy = math.log(labels.length) / math.ln2;
      final normalizedEntropy = entropy / maxEntropy;

      // Create probability map
      final Map<String, double> allProbabilities = {};
      for (int i = 0; i < labels.length && i < probabilities.length; i++) {
        allProbabilities[labels[i]] = probabilities[i];
      }

      // Return classification result
      return {
        'instrument': labels[maxIdx],
        'confidence': maxProb,
        'entropy': normalizedEntropy,
        'isUnknown': maxProb < 0.85 || normalizedEntropy > 0.15,
        'allProbabilities': allProbabilities,
      };
    } catch (e) {
      print('Error classifying audio: $e');
      rethrow;
    }
  }

  // Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
