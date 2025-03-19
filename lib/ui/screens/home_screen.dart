import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../../providers/classifier_provider.dart';
import '../../utils/constants.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/confidence_meter.dart';
import '../widgets/instrument_card.dart';
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
    final isRecording = provider.state == ClassifierState.recording ||
        provider.state == ClassifierState.processing;

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
      floatingActionButton: _buildRecordButton(provider, isRecording),
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
    final isRecording = provider.state == ClassifierState.recording ||
        provider.state == ClassifierState.processing;
    final isProcessing = provider.state == ClassifierState.processing;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Audio visualizer
          AudioVisualizer(
            volumeStream: provider.volumeStream,
            isRecording: isRecording,
          ),
          const SizedBox(height: 16),

          // Status text
          Center(
            child: Text(
              isProcessing
                  ? AppConstants.processingMessage
                  : isRecording
                      ? 'Recording... Tap the button to stop'
                      : 'Tap the microphone button to start recording',
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

  Widget _buildRecordButton(ClassifierProvider provider, bool isRecording) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: () {
            if (isRecording) {
              provider.stopClassification();
            } else {
              provider.startClassification();
            }
          },
          backgroundColor: isRecording ? AppColors.accent : AppColors.primary,
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            size: 32,
          ),
        ),
      ),
    );
  }
}
