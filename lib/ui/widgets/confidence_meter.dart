import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ConfidenceMeter extends StatelessWidget {
  final double confidence;
  final double entropy;
  final bool isUnknown;

  const ConfidenceMeter({
    Key? key,
    required this.confidence,
    required this.entropy,
    required this.isUnknown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final confidenceColor = AppColors.getConfidenceColor(confidence, isUnknown);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // Confidence gauge
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ConfidenceGaugePainter(
                confidence: confidence,
                color: confidenceColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(confidence * 100).toInt()}%',
                      style: AppTextStyles.headline1.copyWith(
                        color: confidenceColor,
                      ),
                    ),
                    Text(
                      'Confidence',
                      style: AppTextStyles.body2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Classification details
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IndicatorDot(
                color: AppColors.highConfidence,
                isActive: confidence >= 0.9 && !isUnknown,
              ),
              const SizedBox(width: 4),
              Text(
                'High',
                style: AppTextStyles.body2.copyWith(
                  color: confidence >= 0.9 && !isUnknown
                      ? AppColors.highConfidence
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 16),
              _IndicatorDot(
                color: AppColors.mediumConfidence,
                isActive: confidence >= 0.7 && confidence < 0.9 && !isUnknown,
              ),
              const SizedBox(width: 4),
              Text(
                'Medium',
                style: AppTextStyles.body2.copyWith(
                  color: confidence >= 0.7 && confidence < 0.9 && !isUnknown
                      ? AppColors.mediumConfidence
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 16),
              _IndicatorDot(
                color: AppColors.lowConfidence,
                isActive: confidence < 0.7 && !isUnknown,
              ),
              const SizedBox(width: 4),
              Text(
                'Low',
                style: AppTextStyles.body2.copyWith(
                  color: confidence < 0.7 && !isUnknown
                      ? AppColors.lowConfidence
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Entropy indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uncertainty (Entropy)',
                      style: AppTextStyles.body2,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entropy,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        entropy > 0.12
                            ? AppColors.lowConfidence
                            : AppColors.highConfidence,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                entropy.toStringAsFixed(2),
                style: AppTextStyles.body1.copyWith(
                  color: entropy > 0.12
                      ? AppColors.lowConfidence
                      : AppColors.highConfidence,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status message
          Text(
            isUnknown
                ? 'Unknown sound detected'
                : confidence >= 0.9
                    ? 'Strong match detected'
                    : confidence >= 0.7
                        ? 'Possible match detected'
                        : 'Weak match detected',
            style: AppTextStyles.body2.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceGaugePainter extends CustomPainter {
  final double confidence;
  final Color color;

  _ConfidenceGaugePainter({
    required this.confidence,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 1.5, size.height);

    // Paint for the background track
    final trackPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    // Paint for the progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    // Draw the background track (semi-circle)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start at 180 degrees
      pi, // End at 0 degrees (180 + 180 = 360 degrees)
      false,
      trackPaint,
    );

    // Draw the progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start at 180 degrees
      pi * confidence, // End based on confidence
      false,
      progressPaint,
    );

    // Draw tick marks
    final tickPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const tickCount = 10; // Number of ticks
    for (int i = 0; i <= tickCount; i++) {
      final angle = pi + (i / tickCount) * pi;
      final outerPoint = Offset(
        center.dx + (radius + 10) * cos(angle),
        center.dy + (radius + 10) * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - 10) * cos(angle),
        center.dy + (radius - 10) * sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Draw labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i * 10}%',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelPoint = Offset(
        center.dx + (radius + 25) * cos(angle) - textPainter.width / 2,
        center.dy + (radius + 25) * sin(angle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, labelPoint);
    }
  }

  @override
  bool shouldRepaint(_ConfidenceGaugePainter oldDelegate) {
    return oldDelegate.confidence != confidence || oldDelegate.color != color;
  }
}

class _IndicatorDot extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _IndicatorDot({
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.transparent,
        border: Border.all(
          color: isActive ? color : Colors.grey.withOpacity(0.5),
          width: 2,
        ),
        shape: BoxShape.circle,
      ),
    );
  }
}
