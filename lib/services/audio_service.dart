import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:logger/logger.dart';

class AudioService {
  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  final Logger _logger = Logger();

  // Audio configuration
  static const int sampleRate = 44100;
  static const int channels = 1; // Mono
  static const int bitDepth = 16;
  static const int bufferDuration = 4; // seconds

  // Circular buffer for audio processing
  final List<double> _audioBuffer =
      List.filled(sampleRate * bufferDuration, 0.0);
  int _bufferPosition = 0;

  // Stream controllers for audio data and volume
  final StreamController<List<double>> _audioStreamController =
      StreamController<List<double>>.broadcast();
  final StreamController<double> _volumeStreamController =
      StreamController<double>.broadcast();

  // Status flags
  bool _isRecording = false;
  bool _isDisposed = false;

  // Stream subscription for audio amplitude
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // Temporary file path for recording
  String? _tempFilePath;
  Timer? _processingTimer;

  // Stream getters
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  Stream<double> get volumeStream => _volumeStreamController.stream;
  bool get isRecording => _isRecording;

  // Start recording and audio processing
  Future<bool> startRecording() async {
    if (_isDisposed) {
      throw Exception('AudioService has been disposed');
    }

    if (_isRecording) {
      return true; // Already recording
    }

    try {
      // Create a temporary file for recording
      final tempDir = await getTemporaryDirectory();
      _tempFilePath = '${tempDir.path}/temp_recording.wav';

      // Configure and start the recorder
      await _recorder.start(
        // Use wav encoder instead of pcm16bits
        encoder: AudioEncoder.wav, // Updated from pcm16bits to wav
        samplingRate: sampleRate,
        numChannels: channels,
        path: _tempFilePath,
      );

      _isRecording = true;

      // Listen to amplitude changes
      _startAmplitudeListening();

      // Start periodic processing
      _startPeriodicProcessing();

      return true;
    } catch (e) {
      _logger.e('Error starting recording: $e');
      return false;
    }
  }

  // Listen to amplitude changes
  void _startAmplitudeListening() {
    _amplitudeSubscription =
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
      (amplitude) {
        // Normalize amplitude to 0-1 range (approximate)
        final normalizedVolume = min(1.0, amplitude.current / 100);
        _volumeStreamController.add(normalizedVolume);
      },
      onError: (e) {
        _logger.e('Error getting amplitude: $e');
      },
    );
  }

  // Process audio data periodically
  void _startPeriodicProcessing() {
    _processingTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isRecording || _isDisposed) {
        timer.cancel();
        return;
      }

      try {
        // We need to periodically save and reload the audio file to process it
        // This is a workaround since we can't directly access the PCM data
        final currentPath = _tempFilePath;
        if (currentPath != null && File(currentPath).existsSync()) {
          // Read file bytes
          final bytes = await File(currentPath).readAsBytes();

          // Process WAV file (skip WAV header)
          if (bytes.length > 44) {
            // 44 bytes is the WAV header size
            final audioData = _extractPcmFromWav(bytes);
            if (audioData.isNotEmpty) {
              // Convert to double samples
              final samples = _convertPcmToDouble(audioData);

              // Update buffer
              _addToBuffer(samples);

              // Notify listeners
              if (!_audioStreamController.isClosed) {
                _audioStreamController.add(List.from(_audioBuffer));
              }
            }
          }
        }
      } catch (e) {
        _logger.e('Error processing audio: $e');
      }
    });
  }

  // Extract PCM data from WAV file
  Uint8List _extractPcmFromWav(Uint8List wavBytes) {
    // Skip the WAV header (44 bytes)
    if (wavBytes.length <= 44) {
      return Uint8List(0);
    }
    return wavBytes.sublist(44);
  }

  // Convert PCM data to double values (-1.0 to 1.0)
  List<double> _convertPcmToDouble(Uint8List pcmData) {
    // Convert 16-bit PCM data to float
    final ByteData byteData = ByteData(pcmData.length);
    for (int i = 0; i < pcmData.length; i++) {
      byteData.setUint8(i, pcmData[i]);
    }

    final List<double> samples = [];
    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      if (i + 1 < byteData.lengthInBytes) {
        final int16Sample = byteData.getInt16(i, Endian.little);
        // Convert to float in range [-1.0, 1.0]
        samples.add(int16Sample / 32768.0);
      }
    }

    return samples;
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      _processingTimer?.cancel();
      _processingTimer = null;

      final path = await _recorder.stop();
      _isRecording = false;

      return path;
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      return null;
    }
  }

  // Add new samples to the circular buffer
  void _addToBuffer(List<double> newSamples) {
    for (final sample in newSamples) {
      _audioBuffer[_bufferPosition] = sample;
      _bufferPosition = (_bufferPosition + 1) % _audioBuffer.length;
    }
  }

  // Play an audio file
  Future<void> playAudioFile(String path) async {
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      _logger.e('Error playing audio file: $e');
    }
  }

  // Save buffer to a WAV file
  Future<String?> saveBufferToFile(String filename) async {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$filename.wav';
      final file = File(path);

      // Create WAV header
      final ByteData header = _createWavHeader(_audioBuffer.length);

      // Convert audio buffer to bytes
      final ByteData audioBytes = ByteData(_audioBuffer.length * 2);
      for (int i = 0; i < _audioBuffer.length; i++) {
        final int sampleAsInt =
            (_audioBuffer[i] * 32767).round().clamp(-32768, 32767);
        audioBytes.setInt16(i * 2, sampleAsInt, Endian.little);
      }

      // Write header and audio data
      final bytes = Uint8List(header.lengthInBytes + audioBytes.lengthInBytes);
      bytes.setRange(0, header.lengthInBytes, header.buffer.asUint8List());
      bytes.setRange(
          header.lengthInBytes, bytes.length, audioBytes.buffer.asUint8List());

      await file.writeAsBytes(bytes);
      return path;
    } catch (e) {
      _logger.e('Error saving buffer to file: $e');
      return null;
    }
  }

  // Create a WAV header
  ByteData _createWavHeader(int numSamples) {
    final ByteData header = ByteData(44);
    final List<int> riff = 'RIFF'.codeUnits;
    final List<int> wave = 'WAVE'.codeUnits;
    final List<int> fmt = 'fmt '.codeUnits;
    final List<int> data = 'data'.codeUnits;

    // Write 'RIFF' chunk descriptor
    for (int i = 0; i < 4; i++) {
      header.setUint8(i, riff[i]);
    }

    final int fileSize = 36 + (numSamples * 2); // 2 bytes per sample
    header.setUint32(4, fileSize, Endian.little);

    // Write 'WAVE' format
    for (int i = 0; i < 4; i++) {
      header.setUint8(8 + i, wave[i]);
    }

    // Write 'fmt ' sub-chunk
    for (int i = 0; i < 4; i++) {
      header.setUint8(12 + i, fmt[i]);
    }

    header.setUint32(16, 16, Endian.little); // Sub-chunk size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    header.setUint16(22, channels, Endian.little); // NumChannels
    header.setUint32(24, sampleRate, Endian.little); // SampleRate
    header.setUint32(28, sampleRate * channels * 2, Endian.little); // ByteRate
    header.setUint16(32, channels * 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample

    // Write 'data' sub-chunk
    for (int i = 0; i < 4; i++) {
      header.setUint8(36 + i, data[i]);
    }

    header.setUint32(40, numSamples * 2, Endian.little); // Sub-chunk size

    return header;
  }

  // Clean up resources
  Future<void> dispose() async {
    _isDisposed = true;
    await stopRecording();
    await _recorder.dispose();
    await _player.dispose();

    _amplitudeSubscription?.cancel();
    _processingTimer?.cancel();

    await _audioStreamController.close();
    await _volumeStreamController.close();
  }
}
