import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF3949AB);
  static const Color primaryDark = Color(0xFF00227B);
  static const Color primaryLight = Color(0xFF6F74DD);

  // Accent colors
  static const Color accent = Color(0xFFFFB300);
  static const Color accentDark = Color(0xFFC68400);
  static const Color accentLight = Color(0xFFFFE54C);

  // Neutral colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFB00020);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);

  // Instrument confidence indicator colors
  static const Color highConfidence = Color(0xFF4CAF50);
  static const Color mediumConfidence = Color(0xFFFFC107);
  static const Color lowConfidence = Color(0xFFFF5722);
  static const Color unknown = Color(0xFF9E9E9E);

  // Get color based on confidence
  static Color getConfidenceColor(double confidence, bool isUnknown) {
    if (isUnknown) return unknown;
    if (confidence >= 0.9) return highConfidence;
    if (confidence >= 0.7) return mediumConfidence;
    return lowConfidence;
  }
}

class AppConstants {
  // App name
  static const String appName = 'Lao Instrument Classifier';

  // Screen titles
  static const String homeScreenTitle = 'Lao Instrument Classifier';
  static const String resultScreenTitle = 'Classification Results';
  static const String settingsScreenTitle = 'Settings';

  // Button texts
  static const String startButtonText = 'Start Recording';
  static const String stopButtonText = 'Stop Recording';
  static const String saveButtonText = 'Save Audio';
  static const String resetButtonText = 'Reset';

  // Messages
  static const String permissionDeniedMessage =
      'Microphone permission is required for this app to work.';
  static const String initializingMessage =
      'Initializing classifier, please wait...';
  static const String errorMessage =
      'An error occurred. Please restart the app.';
  static const String noResultMessage =
      'No results yet. Tap the mic button to start recording.';
  static const String processingMessage = 'Analyzing the sound...';
  static const String recordingMessage = 'Recording Lao instrument...';
  static const String tapToStartMessage =
      'Tap the microphone to detect instrument';
  static const String processingCompleteMessage = 'Processing complete!';

  // Shazam-like messages
  static const String recordingInstructionMessage =
      'Hold still and play the instrument clearly';
  static const String listeningMessage = 'Listening...';
  static const String identifyingMessage = 'Identifying instrument...';
  static const String foundResultMessage = 'Found a match!';
  static const String noMatchMessage =
      'Could not identify this instrument. Try again?';

  // Instrument info
  static const String unknownInstrumentMessage =
      'This sound doesn\'t match any known Lao musical instrument.';
  static const String confidenceLabel = 'Confidence: ';
  static const String entropyLabel = 'Entropy: ';
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textHint,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
}
