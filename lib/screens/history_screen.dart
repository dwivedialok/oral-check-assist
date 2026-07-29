import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/screening_result.dart';
import '../widgets/risk_badge.dart';
import '../services/history_service.dart';
import '../services/report_service.dart';
import 'detailed_results_screen.dart';

/// Screen showing history of past screenings
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<ScreeningHistoryItem> _screenings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScreenings();
  }

  Future<void> _loadScreenings() async {
    setState(() => _isLoading = true);
    try {
      final screenings = await _historyService.getScreenings();
      setState(() {
        _screenings = screenings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.checkHistory),
        centerTitle: true,
        actions: [
          if (_screenings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showClearConfirmation,
              tooltip: AppLocalizations.of(context)!.clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screenings.isEmpty
          ? _buildEmptyState()
          : _buildScreeningList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noChecksYet,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.completeFirstCheck,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreeningList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _screenings.length,
      itemBuilder: (context, index) {
        final screening = _screenings[index];
        return _buildScreeningCard(screening, index);
      },
    );
  }

  Widget _buildScreeningCard(ScreeningHistoryItem screening, int index) {
    final riskLevel = screening.resolvedRiskLevel;

    // Show trend if not the first screening
    String? trend;
    if (index < _screenings.length - 1) {
      final prevRisk = _screenings[index + 1].resolvedRiskLevel;
      if (riskLevel.index > prevRisk.index) {
        trend = 'increased';
      } else if (riskLevel.index < prevRisk.index) {
        trend = 'improved';
      } else {
        trend = 'stable';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final result = screening.decodedResult;
          if (result == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This report uses an older format that is no longer supported.',
                ),
              ),
            );
            return;
          }
          final l10n = AppLocalizations.of(context)!;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailedResultsScreen(
                result: result,
                savedPhotoPaths: screening.savedPhotoPaths,
                onShareReport: (BuildContext screenContext) =>
                    _shareOrDownloadReport(
                      screenContext,
                      result,
                      l10n,
                      share: true,
                    ),
                onDownloadPDF: (BuildContext screenContext) =>
                    _shareOrDownloadReport(
                      screenContext,
                      result,
                      l10n,
                      share: false,
                    ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Risk indicator
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(riskLevel.colorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForRisk(riskLevel),
                  color: Color(riskLevel.colorValue),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: RiskBadge(riskLevel: riskLevel)),
                        const SizedBox(width: 8),
                        if (trend != null)
                          Flexible(child: _buildTrendIndicator(context, trend)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(context, screening.date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.photosAnalyzedCount(screening.photosAnalyzed),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context, String trend) {
    Color color;
    IconData icon;
    String label;

    switch (trend) {
      case 'improved':
        color = Colors.green;
        icon = Icons.trending_down;
        label = AppLocalizations.of(context)!.trendImproved;
        break;
      case 'increased':
        color = Colors.orange;
        icon = Icons.trending_up;
        label = AppLocalizations.of(context)!.trendIncreased;
        break;
      default:
        color = Colors.blue;
        icon = Icons.trending_flat;
        label = AppLocalizations.of(context)!.trendStable;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForRisk(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.moderate:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return l10n.todayAt(
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      );
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
            content: Text(
              share
                  ? '${l10n.shareReport} – share sheet opened.'
                  : 'PDF ready – use the share sheet to save or share.',
            ),
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

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.clearHistoryConfirmTitle),
        content: Text(AppLocalizations.of(context)!.clearHistoryConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _historyService.clearHistory();
              _loadScreenings();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.clearAll),
          ),
        ],
      ),
    );
  }
}
