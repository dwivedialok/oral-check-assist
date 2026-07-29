import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/language_picker_sheet.dart';

/// Welcome screen for first-time users
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final void Function(Locale locale)? onLocaleChanged;

  const WelcomeScreen({
    super.key,
    required this.onContinue,
    this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onLocaleChanged != null)
                    IconButton(
                      icon: const Icon(Icons.language),
                      onPressed: () =>
                          showAppLanguagePicker(context, onLocaleChanged!),
                      tooltip: AppLocalizations.of(context)!.language,
                      color: Colors.blue[600],
                    ),
                ],
              ),
              const Spacer(),

              // Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.health_and_safety,
                  size: 60,
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(height: 40),

              // Title
              Text(
                AppLocalizations.of(context)!.welcomeOralCavityCheck,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                AppLocalizations.of(context)!.welcomeSubtitle,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Features
              _buildFeatureRow(
                context,
                Icons.camera_alt_outlined,
                AppLocalizations.of(context)!.fivePhotoCheck,
                AppLocalizations.of(context)!.fivePhotoCheckDesc,
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                context,
                Icons.psychology_outlined,
                AppLocalizations.of(context)!.aiPoweredAnalysis,
                AppLocalizations.of(context)!.aiPoweredAnalysisDesc,
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                context,
                Icons.lock_outlined,
                AppLocalizations.of(context)!.hundredPercentPrivate,
                AppLocalizations.of(context)!.hundredPercentPrivateDesc,
              ),

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.getStarted,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[600]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
