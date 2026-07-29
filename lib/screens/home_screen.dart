import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/photo_capture.dart';
import '../models/screening_result.dart';
import '../providers/screening_provider.dart';
import '../services/app_build_info.dart';
import '../services/eri_service.dart';
import '../services/history_service.dart';
import '../services/report_service.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/risk_badge.dart';
import 'preparation_screen.dart';
import 'photo_capture_screen.dart';
import 'photo_review_screen.dart';
import 'analysis_screen.dart';
import 'exposure_questionnaire_screen.dart';
import 'results_screen.dart';
import 'detailed_results_screen.dart';
import 'history_screen.dart';

/// Main home screen for the oral screening app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onLocaleChanged});

  final void Function(Locale locale)? onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ScreeningHistoryItem>> _screeningsFuture;

  @override
  void initState() {
    super.initState();
    _screeningsFuture = HistoryService().getScreenings();
  }

  void _refreshRecentChecks() {
    if (mounted) {
      setState(() {
        _screeningsFuture = HistoryService().getScreenings();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.oralHealthCheck,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 1,
                          ),
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                                final style = TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.normal,
                                );
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text('…', style: style);
                                }
                                String versionText = '—';
                                if (snapshot.hasError) {
                                  debugPrint(
                                    'Failed to load package info: ${snapshot.error}',
                                  );
                                } else if (snapshot.hasData) {
                                  final info = snapshot.data!;
                                  final token = runningVersionToken(
                                    packageVersion: info.version,
                                    packageBuildNumber: info.buildNumber,
                                  );
                                  if (token.isNotEmpty) {
                                    versionText = 'v$token';
                                  }
                                }
                                return Text(versionText, style: style);
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.health_and_safety,
                          color: Colors.blue[600],
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main action card
              _buildMainActionCard(context),
              const SizedBox(height: 24),

              // Why 5 photos section
              _buildWhyFivePhotos(context),
              const SizedBox(height: 24),

              // How it works
              _buildHowItWorks(context),
              const SizedBox(height: 24),

              // History preview (placeholder)
              _buildHistoryPreview(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.startNewCheck,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.takeFivePhotosDesc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _startScreening(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.beginCheck,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.fullCheckDuration,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.fullCheckHelperNote,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.quickCheckDurationLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.lock_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.fullyPrivate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyFivePhotos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.whyFivePhotos,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_outlined,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.ninetyTwoPercentMoreAccurate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.multipleAnglesDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      {
        'icon': Icons.checklist,
        'title': l10n.stepPrepare,
        'desc': l10n.stepPrepareDesc,
      },
      {
        'icon': Icons.camera_alt,
        'title': l10n.stepCapture,
        'desc': l10n.stepCaptureDesc,
      },
      {
        'icon': Icons.analytics,
        'title': l10n.stepAnalyze,
        'desc': l10n.stepAnalyzeDesc,
      },
      {
        'icon': Icons.assignment,
        'title': l10n.stepResults,
        'desc': l10n.stepResultsDesc,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.howItWorks,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: Colors.grey[300],
                          ),
                        ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step['icon'] as IconData,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: Colors.grey[300],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    step['desc'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
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

  Widget _buildHistoryPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.recentChecks,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ).then((_) => _refreshRecentChecks());
              },
              child: Text(AppLocalizations.of(context)!.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<ScreeningHistoryItem>>(
          future: _screeningsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildHistoryPreviewEmpty(context);
            }
            final list = snapshot.data!;
            final recent = list.take(3).toList();
            return Column(
              children: recent
                  .map((screening) => _buildHistoryPreviewCard(context, screening))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryPreviewEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            color: Colors.grey[400],
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noChecksYet,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.startFirstCheckDesc,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPreviewCard(
      BuildContext context, ScreeningHistoryItem screening) {
    final riskLevel = screening.resolvedRiskLevel;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          final result = screening.decodedResult;
          if (result == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(l10n.detailedHistoryComingSoon)),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailedResultsScreen(
                result: result,
                savedPhotoPaths: screening.savedPhotoPaths,
                onShareReport: (BuildContext screenContext) => _shareOrDownloadReport(screenContext, result, l10n, share: true),
                onDownloadPDF: (BuildContext screenContext) => _shareOrDownloadReport(screenContext, result, l10n, share: false),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(riskLevel.colorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _historyPreviewRiskIcon(riskLevel),
                  color: Color(riskLevel.colorValue),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiskBadge(riskLevel: riskLevel),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateShort(context, screening.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      l10n.photosAnalyzedCount(screening.photosAnalyzed),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _historyPreviewRiskIcon(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.moderate:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }

  String _formatDateShort(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return l10n.todayAt(
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}');
    } else if (diff.inDays == 1) {
      return l10n.yesterday;
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      return l10n.dateFormat(date.day, date.month, date.year);
    }
  }

  Future<void> _shareOrDownloadReport(
    BuildContext screenContext,
    ScreeningResult result,
    AppLocalizations l10n, {
    required bool share,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(screenContext);
    try {
      if (screenContext.mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Generating PDF…'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await ReportService().shareReport(result, l10n);
      if (screenContext.mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(share
                ? '${l10n.shareReport} – share sheet opened.'
                : 'PDF ready – use the share sheet to save or share.'),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Report error: $e\n$stack');
      if (screenContext.mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _startScreening(BuildContext context) {
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    provider.startNewSession();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScreeningFlowScreen(),
      ),
    ).then((_) => _refreshRecentChecks());
  }

}

/// Manages the screening flow navigation
class ScreeningFlowScreen extends StatefulWidget {
  const ScreeningFlowScreen({super.key});

  @override
  State<ScreeningFlowScreen> createState() => _ScreeningFlowScreenState();
}

class _ScreeningFlowScreenState extends State<ScreeningFlowScreen> {
  // Steps: 0 prep, 1-5 capture, 6 review, 7 questionnaire (analysis in bg),
  //        8 analysis fallback, 9 results, 10 detailed results
  int _currentStep = 0;
  PhotoType? _retakePhotoType;
  bool _questionnaireComplete = false;
  bool _analysisStarted = false;

  /// Apply ERI combined matrix to the analysis result, save to history, and
  /// advance to the results step.
  Future<void> _applyEriAndProceed(ScreeningProvider provider) async {
    final session = provider.currentSession;
    if (session?.result == null) return;

    var result = session!.result!;
    final exposure = session.exposureData;
    if (exposure != null) {
      result = ERIService().applyToResult(result, exposure);
      provider.updateResult(result);
    }

    await HistoryService().saveScreening(result, session.photos);
    if (!mounted) return;
    setState(() => _currentStep = 9);
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector for step 7 (questionnaire) so we only rebuild when analysis
    // completes (isCompleted/result), not on every photo progress update.
    // This keeps the Yes/No buttons responsive during parallel analysis.
    return Selector<ScreeningProvider, Object>(
      selector: (_, p) {
        if (_currentStep == 7) {
          return (p.isCompleted, p.currentSession?.result);
        }
        return (
          p.currentSession,
          p.isAnalyzing,
          p.isLoadingModels,
          p.currentAnalyzingPhotoIndex,
          p.errorMessage,
        );
      },
      builder: (context, _, __) {
        final provider = Provider.of<ScreeningProvider>(context, listen: false);
        if (_currentStep == 0) {
          return PreparationScreen(
            onReady: () => setState(() => _currentStep = 1),
          );
        }

        if (_currentStep >= 1 && _currentStep <= 5) {
          final photoTypes = PhotoType.values;
          final photoIndex = _retakePhotoType != null
              ? photoTypes.indexOf(_retakePhotoType!)
              : _currentStep - 1;
          final isOptional = photoIndex > 0;

          return PhotoCaptureScreen(
            photoType: photoTypes[photoIndex],
            onPhotoCaptured: () {
              if (_retakePhotoType != null) {
                _retakePhotoType = null;
                setState(() => _currentStep = 6);
              } else if (_currentStep < 5) {
                setState(() => _currentStep++);
              } else {
                setState(() => _currentStep = 6);
              }
            },
            onSkip: isOptional
                ? () {
                    if (_currentStep < 5) {
                      setState(() => _currentStep++);
                    } else {
                      setState(() => _currentStep = 6);
                    }
                  }
                : null,
          );
        }

        // Step 6: Photo review — "Analyze" fires off analysis in background
        // and immediately moves to the questionnaire.
        if (_currentStep == 6) {
          return PhotoReviewScreen(
            onRetakePhoto: (type) {
              _retakePhotoType = type;
              setState(() => _currentStep = 1);
            },
            onAnalyze: () {
              if (!_analysisStarted) {
                _analysisStarted = true;
                setState(() => _currentStep = 7);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  provider.startAnalysisInBackground();
                });
                return;
              }
              setState(() => _currentStep = 7);
            },
          );
        }

        // Step 7: Exposure questionnaire (AI analysis running concurrently)
        if (_currentStep == 7) {
          return ExposureQuestionnaireScreen(
            onComplete: () {
              _questionnaireComplete = true;
              if (provider.isCompleted &&
                  provider.currentSession?.result != null) {
                _applyEriAndProceed(provider);
              } else {
                setState(() => _currentStep = 8);
              }
            },
          );
        }

        // Step 8: Analysis fallback screen (shown only when user finished
        // the questionnaire before AI analysis completed)
        if (_currentStep == 8) {
          return AnalysisScreen(
            onComplete: () => _applyEriAndProceed(provider),
            onError: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.errorMessage ??
                      AppLocalizations.of(context)!.analysisFailed),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            },
          );
        }

        // Step 9: Results
        if (_currentStep == 9 && provider.currentSession?.result != null) {
          return ResultsScreen(
            result: provider.currentSession!.result!,
            onViewDetails: () => setState(() => _currentStep = 10),
            onDone: () {
              provider.clearSession();
              Navigator.pop(context);
            },
            onSetReminder: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(AppLocalizations.of(context)!
                        .reminderComingSoon)),
              );
            },
            onFindSpecialist: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(AppLocalizations.of(context)!
                        .findSpecialistComingSoon)),
              );
            },
          );
        }

        // Step 10: Detailed results
        if (_currentStep == 10 && provider.currentSession?.result != null) {
          final result = provider.currentSession!.result!;
          final l10n = AppLocalizations.of(context)!;
          return DetailedResultsScreen(
            result: result,
            onShareReport: (BuildContext screenContext) async {
              final messenger = ScaffoldMessenger.maybeOf(screenContext);
              final mounted = screenContext.mounted;
              try {
                if (mounted && messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Generating PDF…'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                await ReportService().shareReport(result, l10n);
                if (screenContext.mounted && messenger != null) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            '${l10n.shareReport} – share sheet opened.')),
                  );
                }
              } catch (e, stack) {
                debugPrint('Share report error: $e\n$stack');
                if (screenContext.mounted && messenger != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Failed to share: ${e.toString().split('\n').first}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            onDownloadPDF: (BuildContext screenContext) async {
              final messenger = ScaffoldMessenger.maybeOf(screenContext);
              try {
                if (screenContext.mounted && messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Generating PDF…'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                if (kIsWeb) {
                  await ReportService().downloadPDFInBrowser(result);
                  if (screenContext.mounted && messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('PDF downloaded'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  await ReportService().shareReport(result, l10n);
                  if (screenContext.mounted && messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'PDF ready – use the share sheet to save or share.'),
                      ),
                    );
                  }
                }
              } catch (e, stack) {
                debugPrint('Download PDF error: $e\n$stack');
                if (screenContext.mounted && messenger != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Failed to create PDF: ${e.toString().split('\n').first}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          );
        }

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
