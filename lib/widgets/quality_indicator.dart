import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/photo_capture.dart';

/// Widget showing real-time quality indicators during capture
class QualityIndicator extends StatelessWidget {
  final PhotoQualityMetrics metrics;
  final bool showLabels;

  const QualityIndicator({
    super.key,
    required this.metrics,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricRow(context, l10n.brightnessLabel, metrics.brightness, Icons.wb_sunny),
          const SizedBox(height: 8),
          _buildMetricRow(context, l10n.focusLabel, metrics.sharpness, Icons.center_focus_strong),
          const SizedBox(height: 8),
          _buildMetricRow(context, l10n.contrastLabel, metrics.contrast, Icons.contrast),
          const SizedBox(height: 12),
          _buildOverallIndicator(context),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, double value, IconData icon) {
    final color = _getColorForValue(value);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        if (showLabels) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallIndicator(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAcceptable = metrics.isAcceptable;
    final color = isAcceptable ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAcceptable ? Icons.check_circle : Icons.warning,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isAcceptable ? l10n.readyToCapture : l10n.adjustPosition,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(double value) {
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.lightGreen;
    if (value >= 0.4) return Colors.orange;
    return Colors.red;
  }
}

/// Compact quality indicator for thumbnail view
class CompactQualityIndicator extends StatelessWidget {
  final PhotoQualityMetrics metrics;

  const CompactQualityIndicator({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAcceptable = metrics.isAcceptable;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAcceptable 
            ? Colors.green.withOpacity(0.9)
            : Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAcceptable ? Icons.check : Icons.warning,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isAcceptable ? l10n.qualityGood : l10n.qualityRetake,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
