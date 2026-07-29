// Conditional dart:html import is intentional for web PDF download.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:io'
    if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart'
    as io;
import 'dart:html'
    if (dart.library.io) 'package:oral_cavity_classifier_app/html_stub.dart'
    as html;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../l10n/l10n_extensions.dart';
import '../models/exposure_data.dart';
import '../models/photo_capture.dart';
import '../models/screening_result.dart';
import '../presentation/tissue_classification_presentation.dart';

/// Service for generating and sharing PDF reports
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  /// Generate a PDF report from screening results. PDF content is always in English (for doctors / PWA font simplicity).
  /// On web, this method should not be called (use downloadPDFInBrowser instead).
  /// On mobile, saves to temporary directory and returns File.
  Future<io.File> generatePDFReport(
    ScreeningResult result, [
    AppLocalizations? l10n,
  ]) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'generatePDFReport is not supported on web. Use downloadPDFInBrowser instead.',
      );
    }

    final pdfBytes = await generatePDFBytes(result);

    // Save to file system (mobile only)
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/oral_screening_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = io.File(filePath);
    await file.writeAsBytes(pdfBytes);
    debugPrint('📄 [ReportService] PDF generated: $filePath');
    return file;
  }

  /// Generate PDF bytes (web-safe). Content is always in English (for doctors / PWA).
  Future<Uint8List> generatePDFBytes(ScreeningResult result) async {
    final resolvedL10n = AppLocalizationsEn();
    final pdf = pw.Document();

    // Add report content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(resolvedL10n),
            pw.SizedBox(height: 20),
            _buildOverallResult(resolvedL10n, result),
            pw.SizedBox(height: 20),
            if (result.exposureData != null) ...[
              _buildTobaccoExposureSection(resolvedL10n, result.exposureData!),
              pw.SizedBox(height: 20),
            ],
            if (showDetailedTissueClassification(result)) ...[
              _buildProbabilitiesSection(resolvedL10n, result),
              pw.SizedBox(height: 20),
            ],
            _buildRecommendationsSection(resolvedL10n, result),
            pw.SizedBox(height: 20),
            _buildPhotoResultsSection(resolvedL10n, result),
            pw.SizedBox(height: 30),
            _buildDisclaimer(resolvedL10n),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  /// Download PDF directly in browser (web-only). PDF is always in English.
  Future<void> downloadPDFInBrowser(ScreeningResult result) async {
    if (!kIsWeb) {
      throw UnsupportedError('downloadPDFInBrowser is only supported on web');
    }
    final pdfBytes = await generatePDFBytes(result);
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'oral_screening_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
    debugPrint('📄 [ReportService] PDF downloaded in browser');
  }

  pw.Widget _buildHeader(AppLocalizations l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.oralCavityScreeningReport,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          l10n.generatedOn(_formatDate(DateTime.now())),
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildOverallResult(AppLocalizations l10n, ScreeningResult result) {
    final isRetake = result.isUnassessableSession;
    final finalRisk = result.finalCombinedRisk ?? result.overallRisk;
    final riskColor = isRetake ? PdfColors.grey : _getRiskColor(finalRisk);
    final riskName = isRetake ? l10n.retake : _riskDisplayName(l10n, finalRisk);
    final urgencyText = isRetake
        ? l10n.retake
        : urgencyDisplayText(l10n, result.urgencyLevel);
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: riskColor, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.overallAssessment,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                l10n.riskLevelLabel,
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: riskColor.shade(0.2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  riskName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${l10n.eriAiImageRisk}:',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                _riskDisplayName(l10n, result.overallRisk).toUpperCase(),
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${l10n.reportPhotosAnalyzedLabel}:',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                '${result.analyzedPhotoCount}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${l10n.urgencyLabel}:',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                _pdfSafe(urgencyText).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          if (result.isFinalRiskElevatedAboveImageRisk) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              _pdfSafe(l10n.eriFinalRecommendationElevatedNote),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  String _riskDisplayName(AppLocalizations l10n, RiskLevel r) {
    switch (r) {
      case RiskLevel.low:
        return l10n.riskLow;
      case RiskLevel.moderate:
        return l10n.riskModerate;
      case RiskLevel.high:
        return l10n.riskHigh;
    }
  }

  String _photoTypeDisplayName(AppLocalizations l10n, PhotoType t) {
    switch (t) {
      case PhotoType.frontView:
        return l10n.photoFrontView;
      case PhotoType.rightCheek:
        return l10n.photoRightCheek;
      case PhotoType.leftCheek:
        return l10n.photoLeftCheek;
      case PhotoType.tongue:
        return l10n.photoTongue;
      case PhotoType.palate:
        return l10n.photoPalate;
    }
  }

  /// Resolves the "Photo Type" column value for a single PDF row.
  ///
  /// Order of precedence:
  /// 1. Trimmed custom text when [PhotoResult.photoLabel] is
  ///    [OralPhotoLabel.custom] and the text is non-empty.
  /// 2. Localized preset name for any other user-selected [OralPhotoLabel].
  /// 3. Legacy fallback: localized slot name derived from [PhotoResult.photoType]
  ///    (AC7 — pre-upgrade history items have no label field).
  String _photoLabelDisplay(AppLocalizations l10n, PhotoResult photo) {
    final label = photo.photoLabel;
    if (label == null) {
      return _photoTypeDisplayName(l10n, photo.photoType);
    }
    if (label == OralPhotoLabel.custom) {
      final text = photo.customLabelText?.trim();
      if (text != null && text.isNotEmpty) return _pdfSafe(text);
      return _photoTypeDisplayName(l10n, photo.photoType);
    }
    return label.localizedNameL10n(l10n);
  }

  pw.Widget _buildTobaccoExposureSection(
    AppLocalizations l10n,
    ExposureData exposure,
  ) {
    final riskColor = exposure.exposureRiskLevel == ExposureRiskLevel.high
        ? PdfColors.red
        : exposure.exposureRiskLevel == ExposureRiskLevel.moderate
        ? PdfColors.orange
        : PdfColors.green;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _tableCell(l10n.eriReportField, isHeader: true),
          _tableCell(l10n.eriReportValue, isHeader: true),
        ],
      ),
      pw.TableRow(
        children: [
          _tableCell(l10n.eriTypeLabel),
          _tableCell(
            exposure.tobaccoTypes.isNotEmpty
                ? exposure.tobaccoTypes
                      .map((t) => t.localizedNameL10n(l10n))
                      .join(', ')
                : l10n.eriNoReportedTobaccoUse,
          ),
        ],
      ),
    ];

    if (exposure.otherDescription != null &&
        exposure.otherDescription!.trim().isNotEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(l10n.eriOtherSpecifiedLabel),
            _tableCell(exposure.otherDescription!.trim()),
          ],
        ),
      );
    }

    if (exposure.duration != null) {
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(l10n.eriDurationLabel),
            _tableCell(exposure.duration!.localizedNameL10n(l10n)),
          ],
        ),
      );
    }

    if (exposure.frequency != null) {
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(l10n.eriFrequencyLabel),
            _tableCell(exposure.frequency!.localizedNameL10n(l10n)),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          _tableCell(l10n.eriExposureRiskLevelLabel),
          _tableCell(exposure.exposureRiskLevel.localizedNameL10n(l10n)),
        ],
      ),
    );

    rows.add(
      pw.TableRow(
        children: [
          _tableCell(l10n.eriExposureScoreLabel),
          _tableCell('${exposure.exposureScore}'),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.eriTobaccoExposureSummary,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: rows,
        ),
        if (exposure.exposureRiskLevel == ExposureRiskLevel.high) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: riskColor),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              l10n.eriMsgLongTermExposure,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          l10n.eriDisclaimer,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildProbabilitiesSection(
    AppLocalizations l10n,
    ScreeningResult result,
  ) {
    final probs = result.aggregatedProbabilities;
    final interpretation = tissueInterpretationParagraph(l10n, result);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.detailedTissueClassificationTitle,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          l10n.aiTissueClassificationSummarySubtitle,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _pdfSafe(interpretation),
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.2),
        ),
        pw.SizedBox(height: 12),
        _buildProbabilityBar(
          classLabelFriendly(l10n, 'Healthy'),
          probs.healthy,
          PdfColors.green,
        ),
        _buildProbabilityBar(
          classLabelFriendly(l10n, 'Benign'),
          probs.benign,
          PdfColors.blue,
        ),
        _buildProbabilityBar(
          classLabelFriendly(l10n, 'OPMD'),
          probs.opmd,
          PdfColors.orange,
        ),
        _buildProbabilityBar(
          classLabelFriendly(l10n, 'OCA'),
          probs.oca,
          PdfColors.red,
        ),
        _buildProbabilityBar(
          classLabelFriendly(l10n, 'Unknown'),
          probs.unknown,
          PdfColors.purple,
        ),
      ],
    );
  }

  pw.Widget _buildProbabilityBar(String label, double value, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
              pw.Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 8,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: value * 400, // Adjust based on page width
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPhotoResultsSection(
    AppLocalizations l10n,
    ScreeningResult result,
  ) {
    final hasDualEnsemble = result.photoResults.any(
      (p) => p.displayLabel != null,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.photoByPhotoAnalysis,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Photo Type', isHeader: true),
                _tableCell('Risk', isHeader: true),
                _tableCell(l10n.photoTableDetailPeakHeader, isHeader: true),
                _tableCell('Quality', isHeader: true),
                if (hasDualEnsemble) _tableCell('Label', isHeader: true),
                if (hasDualEnsemble)
                  _tableCell('Screening Risk Score', isHeader: true),
              ],
            ),
            ...result.photoResults.map((photo) {
              return pw.TableRow(
                children: [
                  _tableCell(_photoLabelDisplay(l10n, photo)),
                  _tableCell(
                    photo.riskLevel != null
                        ? _riskDisplayName(l10n, photo.riskLevel!)
                        : 'N/A',
                  ),
                  _tableCell('${(photo.confidence * 100).toStringAsFixed(1)}%'),
                  _tableCell(
                    '${(photo.qualityScore * 100).toStringAsFixed(0)}%',
                  ),
                  if (hasDualEnsemble)
                    _tableCell(
                      photo.displayLabel != null
                          ? (photo.perPhotoSummaryLabel != null &&
                                    photo.perPhotoSummaryLabel != 'Healthy'
                                ? 'Retake or further analysis needed'
                                : _pdfSafe(
                                    classLabelFriendly(
                                      l10n,
                                      photo.displayLabel!,
                                    ),
                                  ))
                          : '-',
                    ),
                  if (hasDualEnsemble)
                    _tableCell(
                      photo.cancerProbability != null
                          ? '${(photo.cancerProbability! * 100).toStringAsFixed(1)}%'
                          : '-',
                    ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Replace Unicode chars that default PDF Helvetica cannot render (avoids font errors on iOS).
  static String _pdfSafe(String s) {
    return s
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2014', '-') // em dash
        .replaceAll('\u2713', 'Y') // check mark
        .replaceAll('\u2714', 'Y')
        .replaceAll('\u2022', '*'); // bullet
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        _pdfSafe(text),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildRecommendationsSection(
    AppLocalizations l10n,
    ScreeningResult result,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.recommendations,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        ...result.recommendations.map((rec) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 16,
                  height: 16,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Y',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    _pdfSafe(localizeEriText(l10n, rec)),
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildDisclaimer(AppLocalizations l10n) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.importantDisclaimer,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.amber900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            l10n.reportDisclaimerBody,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.amber900),
          ),
        ],
      ),
    );
  }

  PdfColor _getRiskColor(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return PdfColors.green;
      case RiskLevel.moderate:
        return PdfColors.orange;
      case RiskLevel.high:
        return PdfColors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Share the report as PDF. PDF content is always in English. [l10n] is used only for share sheet labels (e.g. subject).
  /// On web, tries Web Share API and falls back to download; on mobile, uses the share sheet.
  Future<void> shareReport(
    ScreeningResult result, [
    AppLocalizations? l10n,
  ]) async {
    l10n ??= AppLocalizationsEn();
    final riskName = _riskDisplayName(
      l10n,
      result.finalCombinedRisk ?? result.overallRisk,
    );
    final shareText = _doctorShareMessage(riskName);

    if (kIsWeb) {
      // On web/PWA, try Web Share API with file; share_plus falls back to download if unavailable.
      final pdfBytes = await generatePDFBytes(result);
      final filename =
          'oral_screening_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final xFile = XFile.fromData(
        pdfBytes,
        name: filename,
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles(
        [xFile],
        subject: l10n.shareReportSubject,
        text: shareText,
        fileNameOverrides: [filename],
      );
      debugPrint('📤 [ReportService] Web/PWA share attempted');
      return;
    }

    // On mobile, use share sheet
    final file = await generatePDFReport(result);
    if (!kIsWeb && !await file.exists()) {
      throw Exception('PDF file was not created: ${file.path}');
    }
    final xFile = XFile(
      file.path,
      name: 'oral_screening_report.pdf',
      mimeType: 'application/pdf',
    );
    // iOS requires a non-zero sharePositionOrigin for the share sheet (e.g. iPad popover).
    const shareOrigin = Rect.fromLTWH(0, 0, 100, 100);
    await Share.shareXFiles(
      [xFile],
      subject: l10n.shareReportSubject,
      text: shareText,
      sharePositionOrigin: shareOrigin,
    );
    debugPrint('📤 [ReportService] Report shared successfully');
  }

  String _doctorShareMessage(String riskName) {
    return 'Dear Doctor,\n'
        'Sharing an AI-assisted oral check report generated from patient images for your review.\n'
        'Generated using Oral Check Assist (https://oralcheck.3amwave.com).\n'
        'This tool supports early referral decisions and does not replace clinical examination.\n\n'
        'Reported AI risk level: $riskName.';
  }

  /// Save report to downloads (optional). PDF is always in English.
  /// On web, this is not supported (use downloadPDFInBrowser instead).
  Future<String> saveReportToDownloads(ScreeningResult result) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'saveReportToDownloads is not supported on web. Use downloadPDFInBrowser instead.',
      );
    }
    final file = await generatePDFReport(result);

    // On Android, we could use the Downloads folder
    // For now, just return the temp path
    return file.path;
  }
}
