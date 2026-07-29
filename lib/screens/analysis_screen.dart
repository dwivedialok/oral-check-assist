import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/photo_capture.dart';
import '../providers/screening_provider.dart';

/// Screen showing analysis progress while photos are being processed
class AnalysisScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onError;

  const AnalysisScreen({
    super.key,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Delay analysis to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnalysis();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final provider = Provider.of<ScreeningProvider>(context, listen: false);

    // Run actual analysis; progress (P1..P5) is updated by provider via onPhotoProgress
    final result = await provider.analyzePhotos();

    if (result != null) {
      widget.onComplete();
    } else {
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScreeningProvider>(context);
    final session = provider.currentSession;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3 * _pulseController.value),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 50,
                        color: Colors.blue[600],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Title (loading models vs analyzing)
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const SizedBox(height: 40),

              // Photo progress (only when analyzing, not when loading models)
              if (session != null && !provider.isLoadingModels) _buildPhotoProgress(session),
              const SizedBox(height: 32),

              // Current analysis step
              _buildCurrentStep(),
              const SizedBox(height: 40),

              // What we're checking
              _buildCheckingInfo(),

              const Spacer(),

              // Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All analysis happens on your device. Your photos are never uploaded.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final provider = Provider.of<ScreeningProvider>(context);
    return Text(
      provider.isLoadingModels
          ? 'Loading detailed models…'
          : AppLocalizations.of(context)!.analyzingYourPhotos,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitle() {
    final provider = Provider.of<ScreeningProvider>(context);
    return Text(
      provider.isLoadingModels
          ? 'One-time setup for best accuracy. This may take a moment.'
          : 'This will only take a moment',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildPhotoProgress(dynamic session) {
    final provider = Provider.of<ScreeningProvider>(context);
    final photos = session.photos as List<PhotoCapture>;
    final capturedPhotos = photos.where((p) => p.isCaptured).toList();
    final currentIndex = provider.currentAnalyzingPhotoIndex;
    final total = capturedPhotos.length;
    final progressValue = total > 0 ? (currentIndex / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // Progress bar (driven by real per-photo progress)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),

        // Photo indicators P1..P5 (driven by provider.currentAnalyzingPhotoIndex)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: capturedPhotos.asMap().entries.map((entry) {
            final index = entry.key;
            final isProcessed = index < currentIndex;
            final isProcessing = index == currentIndex;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isProcessed
                          ? Colors.green
                          : isProcessing
                              ? Colors.blue
                              : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProcessed
                          ? Icons.check
                          : isProcessing
                              ? Icons.hourglass_empty
                              : Icons.circle,
                      color: Colors.white,
                      size: isProcessed || isProcessing ? 20 : 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isProcessed || isProcessing
                          ? Colors.blue[700]
                          : Colors.grey[500],
                      fontWeight: isProcessing ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    final l10n = AppLocalizations.of(context)!;
    final steps = [l10n.analysisStep1, l10n.analysisStep2, l10n.analysisStep3, l10n.analysisStep4, l10n.analysisStep5];
    final provider = Provider.of<ScreeningProvider>(context);
    if (provider.isLoadingModels) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Preparing analysis…',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    final currentIndex = provider.currentAnalyzingPhotoIndex;
    final stepIndex = currentIndex < steps.length ? currentIndex : steps.length - 1;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(stepIndex),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              steps[stepIndex],
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckingInfo() {
    final items = [
      {'icon': Icons.color_lens_outlined, 'label': 'Color'},
      {'icon': Icons.texture, 'label': 'Texture'},
      {'icon': Icons.pest_control_outlined, 'label': 'Lesions'},
    ];

    return Column(
      children: [
        Text(
          'AI is checking for:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 14,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
