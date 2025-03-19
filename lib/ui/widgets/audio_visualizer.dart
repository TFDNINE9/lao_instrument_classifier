import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class AudioVisualizer extends StatelessWidget {
  final Stream<double> volumeStream;
  final bool isRecording;

  const AudioVisualizer({
    Key? key,
    required this.volumeStream,
    required this.isRecording,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
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
      child: isRecording
          ? StreamBuilder<double>(
              stream: volumeStream,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? 0.0;
                return CustomPaint(
                  painter: _AudioVisualizerPainter(
                    volume: volume,
                    isRecording: isRecording,
                  ),
                  child: const Center(
                    child: Text(
                      'Listening...',
                      style: AppTextStyles.body2,
                    ),
                  ),
                );
              },
            )
          : const Center(
              child: Text(
                'Tap the microphone button to start',
                style: AppTextStyles.body2,
              ),
            ),
    );
  }
}

class _AudioVisualizerPainter extends CustomPainter {
  final double volume;
  final bool isRecording;
  final List<double> _bars = [];
  final Random _random = Random();

  _AudioVisualizerPainter({
    required this.volume,
    required this.isRecording,
  }) {
    // Generate random bars for visualization
    if (isRecording) {
      const barCount = 60;
      _bars.clear();

      for (int i = 0; i < barCount; i++) {
        double height;

        // Make bars near the center taller based on volume
        final distance = (i - barCount / 2).abs() / (barCount / 2);
        final volumeFactor = 1 - distance;

        // Add some randomness with volume influence
        height =
            volume * volumeFactor * 0.8 + _random.nextDouble() * 0.2 * volume;

        // Ensure minimum height
        height = max(0.05, height);

        _bars.add(height);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRecording) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final barWidth = size.width / _bars.length;
    final maxBarHeight = size.height * 0.8;

    for (int i = 0; i < _bars.length; i++) {
      final barHeight = _bars[i] * maxBarHeight;
      final centerY = size.height / 2;

      // Draw bar from center
      final rect = Rect.fromLTWH(
        i * barWidth,
        centerY - barHeight / 2,
        barWidth * 0.8, // Slight gap between bars
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioVisualizerPainter oldDelegate) {
    return oldDelegate.volume != volume ||
        oldDelegate.isRecording != isRecording;
  }
}
