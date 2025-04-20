import 'package:flutter/material.dart';
import '../../models/classification_result.dart';
import '../../utils/constants.dart';

class ResultRevealAnimation extends StatefulWidget {
  final ClassificationResult result;
  final VoidCallback onComplete;

  const ResultRevealAnimation({
    Key? key,
    required this.result,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<ResultRevealAnimation> createState() => _ResultRevealAnimationState();
}

class _ResultRevealAnimationState extends State<ResultRevealAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2).chain(
          CurveTween(curve: Curves.easeOutQuad),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Start animation and call onComplete when done
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color confidenceColor = AppColors.getConfidenceColor(
      widget.result.confidence,
      widget.result.isUnknown,
    );

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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Found match text
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Text(
                    widget.result.isUnknown
                        ? AppConstants.noMatchMessage
                        : AppConstants.foundResultMessage,
                    style: AppTextStyles.headline3.copyWith(
                      color: confidenceColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Instrument icon with scale animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: confidenceColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: confidenceColor,
                        width: 2,
                      ),
                    ),
                    child: widget.result.isUnknown
                        ? Icon(
                            Icons.help_outline,
                            color: confidenceColor,
                            size: 40,
                          )
                        : ClipOval(
                            child: Image.asset(
                              widget.result.instrument.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.music_note,
                                color: confidenceColor,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
