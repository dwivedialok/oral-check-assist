import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/language_picker_sheet.dart';

/// Privacy information screen
class PrivacyScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final void Function(Locale locale)? onLocaleChanged;

  const PrivacyScreen({
    super.key,
    required this.onAccept,
    this.onLocaleChanged,
  });

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _acceptedTerms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onLocaleChanged != null)
                    IconButton(
                      icon: const Icon(Icons.language),
                      onPressed: () => showAppLanguagePicker(
                        context,
                        widget.onLocaleChanged!,
                      ),
                      tooltip: AppLocalizations.of(context)!.language,
                      color: Colors.blue[600],
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.privacy_tip_outlined,
                            color: Colors.blue[600],
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.yourPrivacyMatters,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!.heresHowWeProtectYou,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Privacy points
                    _buildPrivacyPoint(
                      context,
                      Icons.phone_android_outlined,
                      AppLocalizations.of(context)!.onDeviceProcessing,
                      AppLocalizations.of(context)!.onDeviceProcessingDesc,
                      Colors.green,
                    ),
                    const SizedBox(height: 20),

                    _buildPrivacyPoint(
                      context,
                      Icons.cloud_off_outlined,
                      AppLocalizations.of(context)!.noCloudStorage,
                      AppLocalizations.of(context)!.noCloudStorageDesc,
                      Colors.blue,
                    ),
                    const SizedBox(height: 20),

                    _buildPrivacyPoint(
                      context,
                      Icons.visibility_off_outlined,
                      AppLocalizations.of(context)!.noTracking,
                      AppLocalizations.of(context)!.noTrackingDesc,
                      Colors.purple,
                    ),
                    const SizedBox(height: 20),

                    _buildPrivacyPoint(
                      context,
                      Icons.delete_outline,
                      AppLocalizations.of(context)!.yourControl,
                      AppLocalizations.of(context)!.yourControlDesc,
                      Colors.orange,
                    ),
                    const SizedBox(height: 32),

                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber[800],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.medicalDisclaimer,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.disclaimerBody,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber[900],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms checkbox
                    GestureDetector(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _acceptedTerms ? Colors.blue[600] : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _acceptedTerms ? Colors.blue[600]! : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: _acceptedTerms
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.disclaimerCheckbox,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _acceptedTerms ? widget.onAccept : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.acceptContinue,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPoint(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
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
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
