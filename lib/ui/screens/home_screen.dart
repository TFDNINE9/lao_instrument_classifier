import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../providers/classifier_provider.dart';
import '../../utils/constants.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/confidence_meter.dart';
import '../widgets/instrument_card.dart';
import '../widgets/processing_animation.dart';
import '../widgets/recording_progress_indicator.dart';
import '../widgets/result_reveal_animation.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for record button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Selected result for expanded view
  int? _expandedResultIndex;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize classifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClassifierProvider>(context, listen: false);
      provider.initialize();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClassifierProvider>(context);
    final isRecording = provider.state == ClassifierState.recording;
    final isProcessing = provider.state == ClassifierState.processing;
    final isRevealing = provider.state == ClassifierState.revealingResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.homeScreenTitle),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
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
          child: Column(
            children: [
              // Main content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _buildContent(provider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Floating action button for recording
      floatingActionButton:
          _buildRecordButton(provider, isRecording, isProcessing),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContent(ClassifierProvider provider) {
    switch (provider.state) {
      case ClassifierState.uninitialized:
      case ClassifierState.initializing:
        return _buildLoadingState();

      case ClassifierState.permissionDenied:
        return _buildPermissionDeniedState();

      case ClassifierState.error:
        return _buildErrorState(provider.errorMessage);

      case ClassifierState.ready:
      case ClassifierState.recording:
      case ClassifierState.processing:
      case ClassifierState.revealingResult:
        return _buildReadyState(provider);

      default:
        return const Center(
          child: Text('Unknown state'),
        );
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitWave(
            color: AppColors.primary,
            size: 50.0,
          ),
          SizedBox(height: 24),
          Text(
            AppConstants.initializingMessage,
            style: AppTextStyles.body1,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mic_off,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.permissionDeniedMessage,
              style: AppTextStyles.body1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final provider = Provider.of<ClassifierProvider>(
                  context,
                  listen: false,
                );
                provider.initialize();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              errorMessage ?? AppConstants.errorMessage,
              style: AppTextStyles.body1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final provider = Provider.of<ClassifierProvider>(
                  context,
                  listen: false,
                );
                provider.initialize();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState(ClassifierProvider provider) {
    final isRecording = provider.state == ClassifierState.recording;
    final isProcessing = provider.state == ClassifierState.processing;
    final isRevealing = provider.state == ClassifierState.revealingResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Audio visualizer/recording indicator/processing animation/result reveal
          if (isRevealing && provider.currentResult != null)
            ResultRevealAnimation(
              result: provider.currentResult!,
              onComplete: () {
                // This will be called when the animation completes
                // You can add extra behavior here if needed
              },
            )
          else if (isProcessing)
            const ProcessingAnimation()
          else if (isRecording)
            RecordingProgressIndicator(
              progress: provider.recordingProgress,
              volumeStream: provider.volumeStream,
            )
          else
            AudioVisualizer(
              volumeStream: provider.volumeStream,
              isRecording: isRecording,
            ),
          const SizedBox(height: 16),

          // Status text
          Center(
            child: Text(
              isRevealing
                  ? provider.currentResult != null &&
                          !provider.currentResult!.isUnknown
                      ? "It's a ${provider.currentResult!.instrument.name}!"
                      : AppConstants.noMatchMessage
                  : isProcessing
                      ? AppConstants.identifyingMessage
                      : isRecording
                          ? AppConstants.recordingInstructionMessage
                          : AppConstants.tapToStartMessage,
              style: AppTextStyles.body2,
            ),
          ),
          const SizedBox(height: 24),

          // Current result
          if (provider.currentResult != null) ...[
            const Text(
              'Current Result',
              style: AppTextStyles.headline2,
            ),
            const SizedBox(height: 8),
            InstrumentCard(
              result: provider.currentResult!,
              isExpanded: true,
              onTap: () {
                if (provider.currentResult != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        result: provider.currentResult!,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            ConfidenceMeter(
              confidence: provider.currentResult!.confidence,
              entropy: provider.currentResult!.entropy,
              isUnknown: provider.currentResult!.isUnknown,
            ),
            const SizedBox(height: 24),
          ],

          // Recent results
          if (provider.recentResults.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Results',
                  style: AppTextStyles.headline2,
                ),
                TextButton(
                  onPressed: provider.recentResults.isNotEmpty
                      ? () => provider.clearRecentResults()
                      : null,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...provider.recentResults
                .asMap()
                .entries
                .map((entry) => InstrumentCard(
                      result: entry.value,
                      isExpanded: _expandedResultIndex == entry.key,
                      onTap: () {
                        setState(() {
                          if (_expandedResultIndex == entry.key) {
                            _expandedResultIndex = null;
                          } else {
                            _expandedResultIndex = entry.key;
                          }
                        });
                      },
                    ))
                .toList(),
          ],

          // No results message
          if (provider.currentResult == null && provider.recentResults.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 64,
                      color: AppColors.primaryLight,
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppConstants.noResultMessage,
                      style: AppTextStyles.body1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordButton(
      ClassifierProvider provider, bool isRecording, bool isProcessing) {
    final isRevealing = provider.state == ClassifierState.revealingResult;

    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: isProcessing || isRevealing
              ? null // Disable button during processing or revealing
              : () {
                  if (isRecording) {
                    provider.stopClassification();
                  } else {
                    provider.startClassification();
                  }
                },
          backgroundColor: isProcessing || isRevealing
              ? Colors.grey
              : isRecording
                  ? AppColors.accent
                  : AppColors.primary,
          child: Icon(
            isProcessing
                ? Icons.hourglass_top
                : isRevealing
                    ? Icons.music_note
                    : isRecording
                        ? Icons.stop
                        : Icons.mic,
            size: 32,
          ),
        ),
      ),
    );
  }
}
