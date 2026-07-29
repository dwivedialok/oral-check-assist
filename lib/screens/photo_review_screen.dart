import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/photo_capture.dart';
import '../models/screening_session.dart';
import '../providers/screening_provider.dart';
import '../widgets/photo_thumbnail.dart';

/// Screen for reviewing all captured photos before analysis
class PhotoReviewScreen extends StatelessWidget {
  /// Opens [PhotoCaptureScreen] for this type, then returns here (retake/replace or first capture).
  final ValueChanged<PhotoType> onRetakePhoto;
  final VoidCallback onAnalyze;

  const PhotoReviewScreen({
    super.key,
    required this.onRetakePhoto,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScreeningProvider>(context);
    final session = provider.currentSession;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.noActiveSession),
        ),
      );
    }

    final photosNeedingRetake = session.photosNeedingRetake;
    final readyToAnalyze = session.readyToAnalyze;
    final allFiveGood = session.allFiveSlotsFilledAndAcceptable;
    final needsQualityAttention = photosNeedingRetake.isNotEmpty;
    final summarySuccess = !needsQualityAttention && readyToAnalyze;
    final summaryNeedMorePhotos =
        !needsQualityAttention &&
        !readyToAnalyze &&
        session.needsMoreAcceptablePhotosForAnalysis;

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewPhotos),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(
                      context,
                      session,
                      summarySuccess: summarySuccess,
                      summaryNeedMorePhotos: summaryNeedMorePhotos,
                      needsQualityAttention: needsQualityAttention,
                      photosNeedingRetake: photosNeedingRetake,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      l10n.yourPhotos,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PhotoThumbnailGrid(
                      photos: session.photos,
                      retakeLabel: l10n.qualityRetake,
                      replaceLabel: l10n.replacePhoto,
                      captureEmptyLabel: l10n.capture,
                      onCaptureEmpty: onRetakePhoto,
                      onRetake: (type) => _handleRetake(context, type),
                    ),

                    if (photosNeedingRetake.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildQualityWarning(context, photosNeedingRetake),
                    ],
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
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
                  if (!readyToAnalyze)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _blockedHint(session, l10n),
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (readyToAnalyze &&
                      session.acceptableCount >= 1 &&
                      !allFiveGood)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.addMoreAngles,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: readyToAnalyze ? onAnalyze : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.analytics_outlined),
                          const SizedBox(width: 8),
                          Text(
                            allFiveGood
                                ? l10n.analyzeAllPhotos
                                : l10n.analyzeNPhotos(session.acceptableCount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  String _blockedHint(ScreeningSession session, AppLocalizations l10n) {
    final front = session.getPhoto(PhotoType.frontView);
    if (front == null || !front.isAcceptable) {
      return l10n.frontViewRequired;
    }
    if (session.photosNeedingRetake.isNotEmpty) {
      return l10n.somePhotosNeedAttention;
    }
    if (session.needsMoreAcceptablePhotosForAnalysis) {
      return l10n.needAtLeastTwoPhotosForAnalysis;
    }
    return l10n.somePhotosNeedAttention;
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ScreeningSession session, {
    required bool summarySuccess,
    required bool summaryNeedMorePhotos,
    required bool needsQualityAttention,
    required List<PhotoCapture> photosNeedingRetake,
  }) {
    final l10n = AppLocalizations.of(context)!;

    late final Color bg;
    late final Color border;
    late final Color iconBg;
    late final IconData iconData;
    late final Color iconColor;
    late final String title;
    late final String subtitle;
    late final Color titleColor;
    late final Color subtitleColor;

    if (needsQualityAttention) {
      bg = Colors.orange[50]!;
      border = Colors.orange;
      iconBg = Colors.orange.withValues(alpha: 0.2);
      iconData = Icons.warning;
      iconColor = Colors.orange;
      title = l10n.somePhotosNeedAttention;
      subtitle = l10n.photosMayNeedRetake(photosNeedingRetake.length);
      titleColor = Colors.orange[800]!;
      subtitleColor = Colors.orange[700]!;
    } else if (summaryNeedMorePhotos) {
      bg = Colors.blue[50]!;
      border = Colors.blue.shade300;
      iconBg = Colors.blue.withValues(alpha: 0.15);
      iconData = Icons.info_outline;
      iconColor = Colors.blue.shade700;
      title = l10n.needAtLeastTwoPhotosTitle;
      subtitle = l10n.needAtLeastTwoPhotosSubtitle;
      titleColor = Colors.blue[900]!;
      subtitleColor = Colors.blue[800]!;
    } else if (summarySuccess) {
      bg = Colors.green[50]!;
      border = Colors.green;
      iconBg = Colors.green.withValues(alpha: 0.2);
      iconData = Icons.check_circle;
      iconColor = Colors.green;
      title = session.allFiveSlotsFilledAndAcceptable
          ? l10n.allPhotosGood
          : l10n.capturedPhotosLookGood;
      subtitle = l10n.photosCapturedGoodQuality(session.capturedCount);
      titleColor = Colors.green[800]!;
      subtitleColor = Colors.green[700]!;
    } else {
      bg = Colors.orange[50]!;
      border = Colors.orange;
      iconBg = Colors.orange.withValues(alpha: 0.2);
      iconData = Icons.warning;
      iconColor = Colors.orange;
      title = l10n.somePhotosNeedAttention;
      subtitle = l10n.photosMayNeedRetake(photosNeedingRetake.length);
      titleColor = Colors.orange[800]!;
      subtitleColor = Colors.orange[700]!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(iconData, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityWarning(
    BuildContext context,
    List<PhotoCapture> photosNeedingRetake,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.yellow[800], size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.tipsForBetterPhotos,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...photosNeedingRetake.map((photo) {
            final feedback = _feedbackMessage(photo.qualityMetrics, l10n);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right, color: Colors.yellow[800], size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.yellow[900],
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${photo.type.localizedName(context)}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: feedback ?? l10n.considerRetaking),
                        ],
                      ),
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

  void _handleRetake(BuildContext context, PhotoType type) {
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    provider.retakePhoto(type);
    onRetakePhoto(type);
  }
}

String? _feedbackMessage(PhotoQualityMetrics metrics, AppLocalizations l10n) {
  if (metrics.isAcceptable) return null;
  final issues = <String>[];
  if (metrics.brightness < 0.6) issues.add(l10n.feedbackMoveCloserToLight);
  if (metrics.sharpness < 0.6) issues.add(l10n.feedbackHoldSteady);
  if (metrics.contrast < 0.6) issues.add(l10n.feedbackEnsureLighting);
  return issues.isNotEmpty ? issues.join('. ') : l10n.feedbackPleaseRetake;
}
