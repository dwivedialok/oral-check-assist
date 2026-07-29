import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/exposure_data.dart';
import '../models/screening_result.dart';
import '../presentation/tissue_classification_presentation.dart';
import '../services/photo_quality_service.dart';
import '../services/screening_config.dart';
import '../widgets/risk_badge.dart';

/// User-friendly display for 5-class labels in results (sentence + label in brackets).
String _friendlyLabel(BuildContext context, String technicalLabel) {
  return classLabelFriendly(AppLocalizations.of(context)!, technicalLabel);
}

/// Callback for share/PDF actions; receives [BuildContext] of this screen for SnackBars.
typedef ShareReportCallback = void Function(BuildContext context);

/// Screen showing detailed photo-by-photo analysis results
class DetailedResultsScreen extends StatelessWidget {
  final ScreeningResult result;
  final ShareReportCallback? onShareReport;
  final ShareReportCallback? onDownloadPDF;

  /// When viewing from history: photo type name -> path for persisted images.
  final Map<String, String>? savedPhotoPaths;

  const DetailedResultsScreen({
    super.key,
    required this.result,
    this.onShareReport,
    this.onDownloadPDF,
    this.savedPhotoPaths,
  });

  static bool _isDisagreement(PhotoResult photo) =>
      photo.perPhotoSummaryLabel != null &&
      photo.perPhotoSummaryLabel != 'Healthy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.detailedAnalysis),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (onShareReport != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => onShareReport?.call(context),
              tooltip: AppLocalizations.of(context)!.shareReport,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner for non-oral photos
            if (_hasNonOralPhotos()) _buildNonOralWarningBanner(context),

            // Overall assessment card
            _buildOverallAssessment(context),
            const SizedBox(height: 24),

            // Tobacco exposure summary (ERI)
            _buildRiskSemanticsCard(context),
            const SizedBox(height: 24),

            if (result.exposureData != null) _buildExposureSummaryCard(context),
            if (result.exposureData != null) const SizedBox(height: 24),

            if (showDetailedTissueClassification(result)) ...[
              _buildProbabilitiesCard(context),
              const SizedBox(height: 24),
            ],

            // Photo-by-photo results
            Text(
              AppLocalizations.of(context)!.photoByPhotoAnalysis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...result.photoResults.map(
              (photo) => _buildPhotoResultCard(context, photo),
            ),

            const SizedBox(height: 24),

            // Analysis info
            _buildAnalysisInfo(context),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(context),

            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.importantDisclaimer,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.disclaimerDetailed,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
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

  Widget _buildOverallAssessment(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRetake =
        result.screeningOutcome == ScreeningOutcome.retakeSuggested;
    Color cardColor;
    if (isRetake) {
      cardColor = Colors.amber.shade700;
    } else {
      cardColor = Color(
        (result.finalCombinedRisk ?? result.overallRisk).colorValue,
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardColor, width: 1),
          ),
          child: Column(
            children: [
              Text(
                l10n.overallAssessment,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (isRetake)
                _buildRetakeBadge(context, l10n.retake)
              else
                RiskBadge(
                  riskLevel: result.finalCombinedRisk ?? result.overallRisk,
                  large: true,
                ),
              const SizedBox(height: 12),
              Text(
                result.subtypeGuidance != SubtypeGuidance.none
                    ? subtypeGuidanceTitleL10n(l10n, result.subtypeGuidance)
                    : result.overallAssessmentTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                result.subtypeGuidance != SubtypeGuidance.none
                    ? subtypeGuidanceMessageL10n(l10n, result.subtypeGuidance)
                    : localizeAssessmentMessage(
                        l10n,
                        result.overallAssessmentMessage,
                      ),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem(
                      l10n.photosStatLabel,
                      '${result.photosUsed}/${result.photosCaptured}',
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    _buildStatItem(
                      l10n.urgencyLabel,
                      isRetake
                          ? l10n.urgencyRetakePhotos.toUpperCase()
                          : urgencyDisplayText(l10n, result.urgencyLevel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (result.screeningOutcome == ScreeningOutcome.reviewRecommended &&
            result.subtypeGuidance != SubtypeGuidance.none)
          _buildSubtypeExplanationCard(context),
      ],
    );
  }

  Widget _buildSubtypeExplanationCard(BuildContext context) {
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
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.3)),
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
                    color: cardColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetakeBadge(BuildContext context, String label) {
    const color = Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRiskSemanticsCard(BuildContext context) {
    final aiRisk = result.overallRisk;
    final finalRisk = result.finalCombinedRisk ?? result.overallRisk;
    final exposure = result.exposureData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.eriRiskSummary,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _exposureRow(
              AppLocalizations.of(context)!.eriAiImageRisk,
              aiRisk.localizedName(context),
              valueColor: Color(aiRisk.colorValue),
            ),
            _exposureRow(
              AppLocalizations.of(context)!.eriExposureRisk,
              exposure != null
                  ? exposure.exposureRiskLevel.localizedName(context)
                  : AppLocalizations.of(context)!.eriNotReported,
              valueColor: exposure == null
                  ? Colors.grey
                  : exposure.exposureRiskLevel == ExposureRiskLevel.high
                  ? Colors.red
                  : exposure.exposureRiskLevel == ExposureRiskLevel.moderate
                  ? Colors.orange
                  : Colors.green,
            ),
            _exposureRow(
              AppLocalizations.of(context)!.eriFinalRecommendation,
              finalRisk.localizedName(context),
              valueColor: Color(finalRisk.colorValue),
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

  Widget _buildExposureSummaryCard(BuildContext context) {
    final exposure = result.exposureData!;
    final riskColor = exposure.exposureRiskLevel == ExposureRiskLevel.high
        ? Colors.red
        : exposure.exposureRiskLevel == ExposureRiskLevel.moderate
        ? Colors.orange
        : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smoke_free, color: riskColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.eriTobaccoExposureSummary,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _exposureRow(
              AppLocalizations.of(context)!.eriTypeLabel,
              exposure.tobaccoTypes.isEmpty
                  ? AppLocalizations.of(context)!.eriNoReportedTobaccoUse
                  : exposure.tobaccoTypes
                        .map((t) => t.localizedName(context))
                        .join(', '),
            ),
            if (exposure.otherDescription != null &&
                exposure.otherDescription!.trim().isNotEmpty)
              _exposureRow(
                AppLocalizations.of(context)!.eriOtherSpecifiedLabel,
                exposure.otherDescription!.trim(),
              ),
            if (exposure.duration != null)
              _exposureRow(
                AppLocalizations.of(context)!.eriDurationLabel,
                exposure.duration!.localizedName(context),
              ),
            if (exposure.frequency != null)
              _exposureRow(
                AppLocalizations.of(context)!.eriFrequencyLabel,
                exposure.frequency!.localizedName(context),
              ),
            _exposureRow(
              AppLocalizations.of(context)!.eriExposureRiskLevelLabel,
              exposure.exposureRiskLevel.localizedName(context),
              valueColor: riskColor,
            ),
            _exposureRow(
              AppLocalizations.of(context)!.eriExposureScoreLabel,
              '${exposure.exposureScore}',
            ),
            if (result.eriRescreenInterval != null) ...[
              const SizedBox(height: 4),
              _exposureRow(
                AppLocalizations.of(context)!.eriRescreenIntervalLabel,
                result.eriRescreenInterval!,
                valueColor: Colors.blue[700],
              ),
            ],
            if (result.eriMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  localizeEriText(
                    AppLocalizations.of(context)!,
                    result.eriMessage!,
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.eriDisclaimer,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exposureRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilitiesCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final probs = result.aggregatedProbabilities;
    final interpretation = tissueInterpretationParagraph(l10n, result);
    final probList = [
      {'name': 'Healthy', 'value': probs.healthy, 'color': Colors.green},
      {'name': 'Benign', 'value': probs.benign, 'color': Colors.blue},
      {'name': 'OPMD', 'value': probs.opmd, 'color': Colors.orange},
      {'name': 'OCA', 'value': probs.oca, 'color': Colors.red},
      {'name': 'Unknown', 'value': probs.unknown, 'color': Colors.purple},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailedTissueClassificationTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiTissueClassificationSummarySubtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            interpretation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ...probList.map((item) {
            final value = item['value'] as double;
            final color = item['color'] as Color;
            final technicalName = item['name'] as String;
            final displayText = _friendlyLabel(context, technicalName);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayText,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${(value * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhotoResultCard(BuildContext context, PhotoResult photo) {
    final hasAnalysis = photo.isAnalyzed && photo.classProbabilities != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hasAnalysis
                ? Color(
                    photo.riskLevel?.colorValue ?? 0xFF9E9E9E,
                  ).withOpacity(0.2)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getIconForPhotoType(photo.photoType),
            color: hasAnalysis
                ? Color(photo.riskLevel?.colorValue ?? 0xFF9E9E9E)
                : Colors.grey,
          ),
        ),
        title: Text(
          photoResultEffectiveLabelText(AppLocalizations.of(context)!, photo),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhotoStatusChip(
                  riskLevel: photo.riskLevel,
                  isAnalyzed: photo.isAnalyzed,
                  isValidOralPhoto: photo.isValidOralPhoto,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quality: ${(photo.qualityScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            if (photo.displayLabel != null ||
                photo.cancerProbability != null) ...[
              const SizedBox(height: 4),
              if (photo.cancerProbability != null)
                Text(
                  'Screening Risk Score: ${(photo.cancerProbability! * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        photo.cancerProbability! >=
                            ScreeningConfig.binaryScreeningThreshold
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                ),
              if (photo.displayLabel != null) ...[
                Text(
                  localizePerPhotoSummaryLabel(
                        AppLocalizations.of(context)!,
                        photo.perPhotoSummaryLabel,
                      ) ??
                      _friendlyLabel(context, photo.displayLabel!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                if (photo.cancerProbability != null && !_isDisagreement(photo))
                  Text(
                    AppLocalizations.of(context)!.perPhotoVisualDetailMostly(
                      _friendlyLabel(context, photo.displayLabel!),
                      (photo.confidence * 100).toStringAsFixed(0),
                    ),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ],
          ],
        ),
        children: [
          if (savedPhotoPaths != null) _buildPhotoThumbnail(photo),
          if (hasAnalysis)
            _buildPhotoDetails(context, photo)
          else
            Text(
              photo.isValidOralPhoto
                  ? (photo.qualityScore <
                            PhotoQualityService.minAcceptableQuality
                        ? 'Could not analyze - quality too low'
                        : 'Could not analyze - processing failed')
                  : 'Not recognized as oral cavity photo',
              style: TextStyle(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(PhotoResult photo) {
    final path = savedPhotoPaths?[photo.photoType.name];
    if (path == null) return const SizedBox.shrink();
    final file = File(path);
    if (!file.existsSync()) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Text(
              'Photo not available',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPhotoDetails(BuildContext context, PhotoResult photo) {
    final probs = photo.classProbabilities!;
    final probList = [
      {'name': 'Healthy', 'value': probs.healthy},
      {'name': 'Benign', 'value': probs.benign},
      {'name': 'OPMD', 'value': probs.opmd},
      {'name': 'OCA', 'value': probs.oca},
      {'name': 'Unknown', 'value': probs.unknown},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo.displayLabel != null && photo.cancerProbability != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 20,
                      color: Colors.blue[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${localizePerPhotoSummaryLabel(AppLocalizations.of(context)!, photo.perPhotoSummaryLabel) ?? _friendlyLabel(context, photo.displayLabel!)} \u2022 '
                        'Screening Risk Score: ${(photo.cancerProbability! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
                if (!_isDisagreement(photo)) ...[
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.perPhotoVisualDetailMostly(
                      _friendlyLabel(context, photo.displayLabel!),
                      (photo.confidence * 100).toStringAsFixed(0),
                    ),
                    style: TextStyle(fontSize: 11, color: Colors.blue[800]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Probabilities:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...probList.map((item) {
          final value = item['value'] as double;
          final technicalName = item['name'] as String;
          final displayText = _friendlyLabel(context, technicalName);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    displayText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getColorForClass(technicalName),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(value * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.detailModelPeakPercent(
            (photo.confidence * 100).toStringAsFixed(1),
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildAnalysisInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.analysisDetails,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Analyzed at', _formatDateTime(result.analyzedAt)),
          _buildInfoRow('Model', 'Multi-photo Ensemble'),
          _buildInfoRow('Aggregation', 'Weighted average (max-risk)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.blue[800])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (onDownloadPDF != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onDownloadPDF?.call(context),
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(AppLocalizations.of(context)!.downloadPdf),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (onDownloadPDF != null && onShareReport != null)
          const SizedBox(width: 12),
        if (onShareReport != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => onShareReport?.call(context),
              icon: const Icon(Icons.share),
              label: Text(AppLocalizations.of(context)!.shareWithDoctor),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _hasNonOralPhotos() {
    return result.photoResults.any((photo) => !photo.isValidOralPhoto);
  }

  int _nonOralPhotoCount() {
    return result.photoResults.where((photo) => !photo.isValidOralPhoto).length;
  }

  Widget _buildNonOralWarningBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = _nonOralPhotoCount();
    final total = result.photoResults.length;
    final allNonOral = count == total;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_off, color: Colors.purple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allNonOral
                      ? l10n.photosNotRecognized
                      : l10n.nOfMPhotosNotRecognized(count, total),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allNonOral
                      ? l10n.retakeScreeningAll
                      : l10n.retakeScreeningSome,
                  style: TextStyle(fontSize: 13, color: Colors.purple[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForPhotoType(dynamic photoType) {
    final name = photoType.toString().split('.').last;
    switch (name) {
      case 'frontView':
        return Icons.face;
      case 'rightCheek':
        return Icons.chevron_right;
      case 'leftCheek':
        return Icons.chevron_left;
      case 'tongue':
        return Icons.sentiment_satisfied;
      case 'palate':
        return Icons.keyboard_arrow_up;
      default:
        return Icons.image;
    }
  }

  Color _getColorForClass(String className) {
    switch (className) {
      case 'Healthy':
        return Colors.green;
      case 'Benign':
        return Colors.blue;
      case 'OPMD':
        return Colors.orange;
      case 'OCA':
        return Colors.red;
      case 'Unknown':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
