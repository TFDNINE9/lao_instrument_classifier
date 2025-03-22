import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

class TFLiteHelper {
  static final Logger _logger = Logger();

  /// Load an interpreter from assets or file with error handling
  static Future<Interpreter?> loadInterpreter(String modelName,
      {InterpreterOptions? options}) async {
    options ??= InterpreterOptions()..threads = 2;

    Interpreter? interpreter;

    // Try loading directly from assets
    try {
      interpreter = await Interpreter.fromAsset('assets/model/$modelName',
          options: options);
      _logger.i('Model loaded from assets: $modelName');
      return interpreter;
    } catch (e) {
      _logger.w('Could not load model from assets: $e');
    }

    // Try loading from app directory
    try {
      final modelFile = await getModelFile(modelName);

      if (await modelFile.exists()) {
        interpreter = Interpreter.fromFile(modelFile, options: options);
        _logger.i('Model loaded from file: ${modelFile.path}');
        return interpreter;
      } else {
        _logger.e('Model file does not exist: ${modelFile.path}');
      }
    } catch (e) {
      _logger.e('Error loading model from file: $e');
    }

    return null;
  }

  /// Get or create model file from assets
  static Future<File> getModelFile(String modelName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDir.path}/$modelName';
    final modelFile = File(modelPath);

    // Copy from assets if needed
    if (!await modelFile.exists()) {
      try {
        final ByteData modelData =
            await rootBundle.load('assets/model/$modelName');
        await modelFile.writeAsBytes(modelData.buffer.asUint8List());
        _logger.i('Model copied to: $modelPath');
      } catch (e) {
        _logger.e('Error copying model from assets: $e');
      }
    }

    return modelFile;
  }

  /// Get details about a TFLite model file
  static Future<Map<String, dynamic>> getModelInfo(String modelName) async {
    try {
      final modelFile = await getModelFile(modelName);
      final exists = await modelFile.exists();
      final size = exists ? await modelFile.length() : 0;

      return {
        'exists': exists,
        'path': modelFile.path,
        'size': size,
        'valid': size > 1000, // Basic check if file is not empty
      };
    } catch (e) {
      _logger.e('Error getting model info: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}
