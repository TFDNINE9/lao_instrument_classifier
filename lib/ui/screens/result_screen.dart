import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../models/classification_result.dart';
import '../../utils/constants.dart';
import '../widgets/confidence_meter.dart';

class ResultScreen extends StatelessWidget {
  final ClassificationResult result;

  const ResultScreen({
    Key? key,
    required this.result,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final confidenceColor = AppColors.getConfidenceColor(
      result.confidence,
      result.isUnknown,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(result.instrument.name),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryLight],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instrument header card
                  _buildHeaderCard(confidenceColor, context),
                  const SizedBox(height: 16),

                  // Confidence meter
                  ConfidenceMeter(
                    confidence: result.confidence,
                    entropy: result.entropy,
                    isUnknown: result.isUnknown,
                  ),
                  const SizedBox(height: 24),

                  // Description section
                  _buildSection(
                    title: 'Description',
                    content: result.instrument.description,
                  ),
                  const SizedBox(height: 16),

                  // All probabilities
                  _buildProbabilitiesSection(),
                  const SizedBox(height: 16),

                  // Technical details
                  _buildTechnicalDetailsSection(),
                  const SizedBox(height: 24),

                  // Learn more button (if not unknown)
                  if (!result.isUnknown)
                    OutlinedButton(
                      onPressed: () {
                        // Open web page or additional info about the instrument
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Learn More About This Instrument'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color confidenceColor, BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Instrument icon/image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: confidenceColor,
                  width: 2,
                ),
              ),
              child: result.isUnknown
                  ? Icon(
                      Icons.help_outline,
                      color: confidenceColor,
                      size: 64,
                    )
                  : ClipOval(
                      child: Image.asset(
                        result.instrument.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note,
                          color: confidenceColor,
                          size: 64,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Instrument name
            Text(
              result.instrument.name,
              style: AppTextStyles.headline1,
              textAlign: TextAlign.center,
            ),

            // Subtitle
            Text(
              result.isUnknown ? 'Unknown Sound' : 'Lao Musical Instrument',
              style: AppTextStyles.body1.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Confidence indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularPercentIndicator(
                  radius: 28,
                  lineWidth: 5,
                  percent: result.confidence,
                  center: Text(
                    '${(result.confidence * 100).toInt()}%',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  progressColor: confidenceColor,
                  backgroundColor: confidenceColor.withOpacity(0.2),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.confidenceLabel,
                      style: AppTextStyles.headline3.copyWith(
                        color: confidenceColor,
                      ),
                    ),
                    const Text(
                      'Confidence Level',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headline3,
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: AppTextStyles.body1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbabilitiesSection() {
    // Sort probabilities from highest to lowest
    final sortedEntries = result.allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Classification Probabilities',
              style: AppTextStyles.headline3,
            ),
            const SizedBox(height: 16),
            ...sortedEntries.map((entry) {
              final percent = entry.value * 100;
              final isHighestProbability = entry.key == result.instrument.name;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (isHighestProbability)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.highConfidence,
                        size: 16,
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: isHighestProbability
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isHighestProbability
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: LinearProgressIndicator(
                        value: entry.value,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isHighestProbability
                              ? AppColors.primary
                              : AppColors.primaryLight,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: isHighestProbability
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Technical Details',
              style: AppTextStyles.headline3,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              label: 'Confidence:',
              value: '${(result.confidence * 100).toStringAsFixed(2)}%',
            ),
            _buildDetailRow(
              label: 'Entropy:',
              value: result.entropy.toStringAsFixed(3),
            ),
            _buildDetailRow(
              label: 'Classification:',
              value: result.isUnknown ? 'Unknown' : 'Known',
            ),
            _buildDetailRow(
              label: 'Timestamp:',
              value: _formatDateTime(result.timestamp),
            ),
            if (result.secondHighestProbability != null)
              _buildDetailRow(
                label: 'Second choice:',
                value:
                    '${result.secondHighestProbability!.key} (${(result.secondHighestProbability!.value * 100).toStringAsFixed(1)}%)',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
