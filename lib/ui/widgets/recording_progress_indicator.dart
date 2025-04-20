import 'dart:math';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../utils/constants.dart';

class RecordingProgressIndicator extends StatelessWidget {
  final double progress;
  final Stream<double> volumeStream;

  const RecordingProgressIndicator({
    Key? key,
    required this.progress,
    required this.volumeStream,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
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
      child: Stack(
        children: [
          // Volume visualization
          StreamBuilder<double>(
            stream: volumeStream,
            builder: (context, snapshot) {
              final volume = snapshot.data ?? 0.0;
              return CustomPaint(
                painter: _VolumePainter(volume: volume),
                child: Container(),
              );
            },
          ),

          // Center content with progress
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularPercentIndicator(
                  radius: 50.0,
                  lineWidth: 8.0,
                  percent: progress,
                  center: Text(
                    "${(progress * 100).toInt()}%",
                    style: AppTextStyles.headline2,
                  ),
                  progressColor: AppColors.accent,
                  backgroundColor: AppColors.accent.withOpacity(0.2),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Recording...",
                  style: AppTextStyles.body1,
                ),
                const SizedBox(height: 4),
                Text(
                  "Please play the instrument",
                  style: AppTextStyles.body2
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumePainter extends CustomPainter {
  final double volume;
  final Random _random = Random();

  _VolumePainter({required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = min(size.width, size.height) * 0.8;

    // Create ripple effect based on volume
    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * (0.5 + (i * 0.15)) * (0.3 + volume * 0.7);

      // Ensure opacity is between 0.0 and 1.0
      final opacity = min(1.0, max(0.0, (0.7 - (i * 0.2)) * volume));

      final paint = Paint()
        ..color = AppColors.accent.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + (volume * 2.0);

      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint,
      );
    }

    // Draw some random bars for visual effect
    final barPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final barCount = 20;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final randomFactor = 0.2 + _random.nextDouble() * 0.8;
      final barHeight = size.height * volume * randomFactor * 0.5;

      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_VolumePainter oldDelegate) {
    return oldDelegate.volume != volume;
  }
}
