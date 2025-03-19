import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../models/classification_result.dart';
import '../../utils/constants.dart';

class InstrumentCard extends StatelessWidget {
  final ClassificationResult result;
  final bool isExpanded;
  final VoidCallback onTap;

  const InstrumentCard({
    Key? key,
    required this.result,
    this.isExpanded = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final confidenceColor = AppColors.getConfidenceColor(
      result.confidence,
      result.isUnknown,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with instrument name and confidence
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.1),
                  border: Border(
                    left: BorderSide(
                      color: confidenceColor,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Instrument image or icon
                    CircleAvatar(
                      backgroundColor: confidenceColor.withOpacity(0.2),
                      radius: 24,
                      child: result.isUnknown
                          ? Icon(
                              Icons.help_outline,
                              color: confidenceColor,
                              size: 28,
                            )
                          : Image.asset(
                              result.instrument.imagePath,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.music_note,
                                color: confidenceColor,
                                size: 28,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),

                    // Instrument name and confidence
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.instrument.name,
                            style: AppTextStyles.headline3,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.isUnknown
                                ? 'Unknown sound detected'
                                : '${result.confidenceLabel} certainty',
                            style: AppTextStyles.body2,
                          ),
                        ],
                      ),
                    ),

                    // Confidence indicator
                    CircularPercentIndicator(
                      radius: 24,
                      lineWidth: 4,
                      percent: result.confidence,
                      center: Text(
                        '${(result.confidence * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      progressColor: confidenceColor,
                      backgroundColor: confidenceColor.withOpacity(0.2),
                    ),
                  ],
                ),
              ),

              // Expanded details section
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: AppTextStyles.headline3,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.instrument.description,
                        style: AppTextStyles.body1,
                      ),
                      const SizedBox(height: 16),

                      // Technical details
                      const Text(
                        'Technical Details',
                        style: AppTextStyles.headline3,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Confidence:',
                        value:
                            '${(result.confidence * 100).toStringAsFixed(1)}%',
                      ),
                      _DetailRow(
                        label: 'Entropy:',
                        value: result.entropy.toStringAsFixed(3),
                      ),
                      const SizedBox(height: 16),

                      // Other probabilities
                      const Text(
                        'Other Possibilities',
                        style: AppTextStyles.headline3,
                      ),
                      const SizedBox(height: 8),
                      _buildOtherProbabilities(),

                      const SizedBox(height: 16),
                      Text(
                        'Recorded at: ${_formatDateTime(result.timestamp)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherProbabilities() {
    if (result.allProbabilities.length <= 1) {
      return const Text('No other possibilities detected');
    }

    // Sort probabilities from highest to lowest
    final sortedEntries = result.allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 3 excluding the current one
    final topEntries = sortedEntries
        .take(4)
        .where((entry) => entry.key != result.instrument.name)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topEntries.map((entry) {
        final percent = entry.value * 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: AppTextStyles.body2,
                ),
              ),
              Container(
                width: 150,
                height: 20,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LinearProgressIndicator(
                  value: entry.value,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.body2,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTextStyles.body1,
          ),
        ],
      ),
    );
  }
}
