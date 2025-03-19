import 'package:lao_instrument_classifier/models/instrument.dart';

class ClassificationResult {
  final Instrument instrument;
  final double confidence;
  final double entropy;
  final bool isUnknown;
  final Map<String, double> allProbabilities;
  final DateTime timestamp;

  ClassificationResult({
    required this.instrument,
    required this.confidence,
    required this.entropy,
    required this.isUnknown,
    required this.allProbabilities,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Create a result for an unknown sound
  factory ClassificationResult.unknown({
    required double confidence,
    required double entropy,
    required Map<String, double> allProbabilities,
  }) {
    return ClassificationResult(
      instrument: Instrument.unknown(),
      confidence: confidence,
      entropy: entropy,
      isUnknown: true,
      allProbabilities: allProbabilities,
    );
  }

  // Check if this result has high certainty
  bool get hasHighCertainty => confidence >= 0.9 && entropy <= 0.12;

  // Get a descriptive label of the confidence level
  String get confidenceLabel {
    if (confidence >= 0.95) return 'Very High';
    if (confidence >= 0.85) return 'High';
    if (confidence >= 0.7) return 'Moderate';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  // Find the second most probable instrument
  MapEntry<String, double>? get secondHighestProbability {
    if (allProbabilities.length <= 1) return null;

    final sorted = allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.length > 1 ? sorted[1] : null;
  }
}
