import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/language_picker_sheet.dart';

/// Explains how the screening process works
class HowItWorksScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final void Function(Locale locale)? onLocaleChanged;

  const HowItWorksScreen({
    super.key,
    required this.onContinue,
    this.onLocaleChanged,
  });

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, dynamic>> _getSteps(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'icon': Icons.camera_enhance_outlined,
        'color': Colors.blue,
        'title': l10n.howItWorksTake5Photos,
        'description': l10n.howItWorksTake5PhotosDesc,
      },
      {
        'icon': Icons.auto_awesome_outlined,
        'color': Colors.purple,
        'title': l10n.howItWorksAIAnalysis,
        'description': l10n.howItWorksAIAnalysisDesc,
      },
      {
        'icon': Icons.assignment_outlined,
        'color': Colors.green,
        'title': l10n.howItWorksGetResults,
        'description': l10n.howItWorksGetResultsDesc,
      },
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = _getSteps(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Language + Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (widget.onLocaleChanged != null)
                    IconButton(
                      icon: const Icon(Icons.language),
                      onPressed: () => showAppLanguagePicker(
                        context,
                        widget.onLocaleChanged!,
                      ),
                      tooltip: l10n.language,
                      color: Colors.blue[600],
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onContinue,
                    child: Text(l10n.skip),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return _buildPage(
                    context: context,
                    icon: step['icon'] as IconData,
                    color: step['color'] as Color,
                    title: step['title'] as String,
                    description: step['description'] as String,
                    stepNumber: index + 1,
                    stepsLength: steps.length,
                  );
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.blue[600]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.backButton),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < steps.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          widget.onContinue();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage < steps.length - 1 ? l10n.nextButton : l10n.continueButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required int stepNumber,
    required int stepsLength,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.stepXOfY(stepNumber, stepsLength),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
