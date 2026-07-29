import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/exposure_data.dart';
import '../models/screening_result.dart';
import '../widgets/risk_badge.dart';

/// Screen showing the screening results with risk level and recommendations
class ResultsScreen extends StatelessWidget {
  final ScreeningResult result;
  final VoidCallback onViewDetails;
  final VoidCallback onDone;
  final VoidCallback? onSetReminder;
  final VoidCallback? onFindSpecialist;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.onViewDetails,
    required this.onDone,
    this.onSetReminder,
    this.onFindSpecialist,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context),
                    if (_hasNonOralPhotos()) _buildNonOralWarning(context),
                    _buildRiskIndicator(context),
                    _buildRiskBreakdown(context),
                    _buildMessage(context),
                    _buildRecommendations(context),
                    if (result.exposureData != null) _buildEriCard(context),
                    if (result.eriRescreenInterval != null)
                      _buildRescreenInterval(context),
                    if (result.photosNeedingAttention.isNotEmpty)
                      _buildConcerningAreas(context),
                  ],
                ),
              ),
            ),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    Color color;
    switch (result.screeningOutcome) {
      case ScreeningOutcome.lowRisk:
        color = const Color(0xFF4CAF50);
        break;
      case ScreeningOutcome.retakeSuggested:
        color = Colors.amber.shade700;
        break;
      case ScreeningOutcome.reviewRecommended:
        color = Color(result.overallRisk.colorValue);
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1)),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.checkComplete,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.subtypeGuidance != SubtypeGuidance.none
                ? subtypeGuidanceTitleL10n(
                    AppLocalizations.of(context)!,
                    result.subtypeGuidance,
                  )
                : result.overallAssessmentTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicator(BuildContext context) {
    if (result.screeningOutcome == ScreeningOutcome.retakeSuggested) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade700, width: 3),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                color: Colors.amber.shade700,
                size: 50,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.retake,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: RiskIndicator(
        riskLevel: result.finalCombinedRisk ?? result.overallRisk,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  result.subtypeGuidance != SubtypeGuidance.none
                      ? subtypeGuidanceMessageL10n(
                          AppLocalizations.of(context)!,
                          result.subtypeGuidance,
                        )
                      : localizeAssessmentMessage(
                          AppLocalizations.of(context)!,
                          result.overallAssessmentMessage,
                        ),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if ((result.finalCombinedRisk ?? result.overallRisk)
                        .specialistRequired &&
                    result.screeningOutcome !=
                        ScreeningOutcome.retakeSuggested) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(result.overallRisk.colorValue),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.medical_services,
                          color: Color(result.overallRisk.colorValue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            urgencyDisplayText(
                              AppLocalizations.of(context)!,
                              result.urgencyLevel,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(result.overallRisk.colorValue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (result.screeningOutcome == ScreeningOutcome.reviewRecommended &&
              result.subtypeGuidance != SubtypeGuidance.none)
            _buildSubtypeGuidanceCard(context),
        ],
      ),
    );
  }

  Widget _buildSubtypeGuidanceCard(BuildContext context) {
    final guidance = result.subtypeGuidance;
    Color cardColor;
    IconData cardIcon;
    switch (guidance) {
      case SubtypeGuidance.ocaDominant:
        cardColor = Colors.red;
        cardIcon = Icons.error_outline;
        break;
      case SubtypeGuidance.opmdDominant:
        cardColor = Colors.orange;
        cardIcon = Icons.warning_amber_outlined;
        break;
      case SubtypeGuidance.benignDominant:
        cardColor = Colors.blue;
        cardIcon = Icons.info_outline;
        break;
      case SubtypeGuidance.none:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cardIcon, color: cardColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guidance.displayTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guidance.displayMessage,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: cardColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.recommendations,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...result.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizeRecommendation(context, rec),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBreakdown(BuildContext context) {
    final aiRisk = result.overallRisk;
    final finalRisk = result.finalCombinedRisk ?? result.overallRisk;
    final exposure = result.exposureData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            _riskRow(
              AppLocalizations.of(context)!.eriAiImageRisk,
              aiRisk.localizedName(context),
              Color(aiRisk.colorValue),
            ),
            const SizedBox(height: 8),
            _riskRow(
              AppLocalizations.of(context)!.eriExposureRisk,
              exposure != null
                  ? exposure.exposureRiskLevel.localizedName(context)
                  : AppLocalizations.of(context)!.eriNotReported,
              exposure == null
                  ? Colors.grey
                  : exposure.exposureRiskLevel == ExposureRiskLevel.high
                  ? Colors.red
                  : exposure.exposureRiskLevel == ExposureRiskLevel.moderate
                  ? Colors.orange
                  : Colors.green,
            ),
            const SizedBox(height: 8),
            _riskRow(
              AppLocalizations.of(context)!.eriFinalRecommendation,
              finalRisk.localizedName(context),
              Color(finalRisk.colorValue),
            ),
            if (result.isFinalRiskElevatedAboveImageRisk) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.eriFinalRecommendationElevatedNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _riskRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEriCard(BuildContext context) {
    final exposure = result.exposureData!;
    final isHigh = exposure.exposureRiskLevel == ExposureRiskLevel.high;
    final noTobacco = exposure.tobaccoTypes.isEmpty;
    final color = noTobacco
        ? Colors.green
        : (isHigh ? Colors.red : Colors.orange);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smoke_free, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  noTobacco
                      ? AppLocalizations.of(context)!.eriNoReportedTobaccoUse
                      : AppLocalizations.of(
                          context,
                        )!.eriTobaccoExposureWithLevel(
                          exposure.exposureRiskLevel.localizedName(context),
                        ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (!noTobacco && result.eriMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                localizeEriText(
                  AppLocalizations.of(context)!,
                  result.eriMessage!,
                ),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.eriDisclaimer,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescreenInterval(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue[700], size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(
                  context,
                )!.eriRecommendedRescreenInterval(result.eriRescreenInterval!),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcerningAreas(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.areasNeedingAttention,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.photosNeedingAttention.map((photo) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    photoResultEffectiveLabelText(
                      AppLocalizations.of(context)!,
                      photo,
                    ),
                    style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Primary action based on risk level
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  (result.finalCombinedRisk ?? result.overallRisk)
                          .specialistRequired &&
                      onFindSpecialist != null
                  ? onFindSpecialist
                  : (onSetReminder ?? onDone),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(
                  (result.finalCombinedRisk ?? result.overallRisk).colorValue,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getPrimaryButtonText(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.viewDetails),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.done),
                ),
              ),
            ],
          ),

          // Disclaimer
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.disclaimerResults,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getPrimaryButtonText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (result.screeningOutcome) {
      case ScreeningOutcome.lowRisk:
        return l10n.setReminderForNextCheck;
      case ScreeningOutcome.retakeSuggested:
        return l10n.retake;
      case ScreeningOutcome.reviewRecommended:
        if (result.subtypeGuidance == SubtypeGuidance.ocaDominant) {
          return l10n.findSpecialistNow;
        }
        return l10n.findDentistNearMe;
    }
  }

  bool _hasNonOralPhotos() {
    return result.photoResults.any((photo) => !photo.isValidOralPhoto);
  }

  int _nonOralPhotoCount() {
    return result.photoResults.where((photo) => !photo.isValidOralPhoto).length;
  }

  Widget _buildNonOralWarning(BuildContext context) {
    final count = _nonOralPhotoCount();
    final total = result.photoResults.length;
    final allNonOral = count == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.purple,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allNonOral
                      ? AppLocalizations.of(context)!.unableToAnalyzePhotos
                      : AppLocalizations.of(context)!.nPhotosSkipped(count),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allNonOral
                      ? AppLocalizations.of(context)!.photosDontAppearMouth
                      : AppLocalizations.of(context)!.somePhotosExcluded,
                  style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
