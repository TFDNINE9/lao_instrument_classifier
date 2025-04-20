import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../utils/constants.dart';

class ProcessingAnimation extends StatelessWidget {
  const ProcessingAnimation({Key? key}) : super(key: key);

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wave animation
          const SpinKitWave(
            color: AppColors.accent,
            size: 40.0,
          ),
          const SizedBox(height: 16),

          // Processing text
          const Text(
            AppConstants.identifyingMessage,
            style: AppTextStyles.body1,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Analyzing audio pattern...',
            style: AppTextStyles.body2.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
