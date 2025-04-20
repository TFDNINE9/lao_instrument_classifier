import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Class to handle audio feature extraction including Mel Spectrogram generation
/// Matches Python implementation for model compatibility
class FeatureExtractor {
  // Constants - must match Python training code exactly
  static const int sampleRate = 44100;
  static const int fftSize = 2048;
  static const int hopLength = 512;
  static const int numMels = 128;
  static const double fMin = 0.0;
  static const double fMax = 8000.0;

  // Pre-computed mel filter bank matrix
  late List<List<double>> _melFilterbank;

  // Hann window for STFT computation
  late List<double> _hannWindow;

  FeatureExtractor() {
    _initializeFilterbank();
    _initializeHannWindow();
  }

  // Initialize the Mel filterbank matrix
  void _initializeFilterbank() {
    _melFilterbank =
        _createMelFilterbank(numMels, fftSize ~/ 2 + 1, sampleRate, fMin, fMax);
  }

  // Initialize Hann window for STFT
  void _initializeHannWindow() {
    _hannWindow = List<double>.filled(fftSize, 0.0);
    for (int i = 0; i < fftSize; i++) {
      _hannWindow[i] = 0.5 * (1 - cos(2 * pi * i / (fftSize - 1)));
    }
  }

  // Create mel filterbank matrix
  List<List<double>> _createMelFilterbank(
      int numMels, int numFft, int sampleRate, double fMin, double fMax) {
    // Convert Hz to Mel - matches librosa implementation
    double hzToMel(double hz) {
      return 2595.0 * log10(1.0 + hz / 700.0);
    }

    // Convert Mel to Hz - matches librosa implementation
    double melToHz(double mel) {
      return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
    }

    // Create an array of equally spaced frequencies in the Mel scale
    List<double> melPoints = List<double>.filled(numMels + 2, 0.0);
    final double melMin = hzToMel(fMin);
    final double melMax = hzToMel(fMax);

    for (int i = 0; i < numMels + 2; i++) {
      melPoints[i] = melMin + i * (melMax - melMin) / (numMels + 1);
    }

    // Convert Mel points back to Hz
    List<double> hzPoints = melPoints.map(melToHz).toList();

    // Convert Hz points to FFT bin indices
    List<int> bins = hzPoints
        .map((hz) => ((hz * numFft) / sampleRate).round().clamp(0, numFft - 1))
        .toList();

    // Create the filterbank matrix - exactly match librosa implementation
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

  // Custom FFT implementation
  List<_Complex> _fft(List<double> x) {
    int n = x.length;

    // Base case
    if (n == 1) {
      return [_Complex(x[0], 0)];
    }

    // Check if n is a power of 2
    if (n & (n - 1) != 0) {
      throw Exception('FFT length must be a power of 2');
    }

    // Split even and odd
    List<double> even = [];
    List<double> odd = [];
    for (int i = 0; i < n; i += 2) {
      even.add(x[i]);
      if (i + 1 < n) {
        odd.add(x[i + 1]);
      }
    }

    // Recursively compute FFT
    List<_Complex> evenFFT = _fft(even);
    List<_Complex> oddFFT = _fft(odd);

    // Combine results
    List<_Complex> result = List<_Complex>.filled(n, _Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      double angle = -2 * pi * k / n;
      _Complex twiddle = _Complex(cos(angle), sin(angle));
      _Complex t = oddFFT[k] * twiddle;
      result[k] = evenFFT[k] + t;
      result[k + n ~/ 2] = evenFFT[k] - t;
    }

    return result;
  }

  // Compute Short-Time Fourier Transform (STFT)
  List<List<_Complex>> _computeSTFT(List<double> audioBuffer) {
    final int bufferLength = audioBuffer.length;
    final int numFrames = ((bufferLength - fftSize) / hopLength).floor() + 1;

    List<List<_Complex>> stft = [];

    // Process each frame
    for (int frame = 0; frame < numFrames; frame++) {
      final int start = frame * hopLength;

      // Extract frame and apply window
      final List<double> windowedFrame = List<double>.filled(fftSize, 0.0);
      for (int i = 0; i < fftSize && start + i < bufferLength; i++) {
        windowedFrame[i] = audioBuffer[start + i] * _hannWindow[i];
      }

      // Ensure frame length is a power of 2 for FFT
      int paddedLength = 1;
      while (paddedLength < windowedFrame.length) {
        paddedLength *= 2;
      }

      if (windowedFrame.length < paddedLength) {
        windowedFrame.addAll(
            List<double>.filled(paddedLength - windowedFrame.length, 0.0));
      }

      // Compute FFT
      List<_Complex> frameFFT = _fft(windowedFrame);
      stft.add(frameFFT);
    }

    return stft;
  }

  // Compute Mel spectrogram from STFT - match Python implementation exactly
  Float32List _computeMelSpectrogram(List<List<_Complex>> stft) {
    final int numFrames = stft.length;
    const int numFreqs = fftSize ~/ 2 + 1;

    // Compute power spectrogram
    List<List<double>> powerSpec =
        List.generate(numFrames, (_) => List<double>.filled(numFreqs, 0.0));

    for (int frame = 0; frame < numFrames; frame++) {
      for (int freq = 0; freq < numFreqs && freq < stft[frame].length; freq++) {
        final _Complex c = stft[frame][freq];
        powerSpec[frame][freq] = c.real * c.real + c.imag * c.imag;
      }
    }

    // Apply mel filterbank
    List<List<double>> melSpec =
        List.generate(numFrames, (_) => List<double>.filled(numMels, 0.0));

    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < numMels; mel++) {
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

    // Find max value for reference (matches librosa's ref=np.max)
    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < numMels; mel++) {
        if (melSpec[frame][mel] > maxVal) {
          maxVal = melSpec[frame][mel];
        }
      }
    }

    // Convert to dB using the max value as reference
    for (int frame = 0; frame < numFrames; frame++) {
      for (int mel = 0; mel < numMels; mel++) {
        melSpec[frame][mel] =
            10.0 * log10((melSpec[frame][mel] + epsilon) / (maxVal + epsilon));
      }
    }

    // Create flat Float32List for model input
    final int totalSize = numMels * numFrames;
    final Float32List result = Float32List(totalSize);
    int index = 0;

    // Flatten in row-major order (all frames for mel 0, then all frames for mel 1, etc.)
    for (int mel = 0; mel < numMels; mel++) {
      for (int frame = 0; frame < numFrames; frame++) {
        result[index++] = melSpec[frame][mel];
      }
    }

    return result;
  }

  // Helper for log base 10
  double log10(double x) => log(x) / ln10;

  // Main method to extract features
  Future<Float32List> extractMelSpectrogram(List<double> audioBuffer) async {
    // Use compute to run in a separate isolate for better performance
    return compute(_isolateExtractFeatures, audioBuffer);
  }

  // Static method for isolate computation
  static Future<Float32List> _isolateExtractFeatures(
      List<double> audioBuffer) async {
    final extractor = FeatureExtractor();
    final stft = extractor._computeSTFT(audioBuffer);
    final features = extractor._computeMelSpectrogram(stft);

    // Ensure this is always Float32List
    return features;
  }
}

/// Helper class for complex numbers
class _Complex {
  final double real;
  final double imag;

  _Complex(this.real, this.imag);

  _Complex operator +(_Complex other) =>
      _Complex(real + other.real, imag + other.imag);

  _Complex operator -(_Complex other) =>
      _Complex(real - other.real, imag - other.imag);

  _Complex operator *(_Complex other) {
    return _Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }

  double magnitude() => sqrt(real * real + imag * imag);
}
