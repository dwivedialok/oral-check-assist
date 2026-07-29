import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/screening_result.dart';

/// Badge showing risk level with appropriate color
class RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;
  final bool large;

  const RiskBadge({super.key, required this.riskLevel, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = Color(riskLevel.colorValue);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(large ? 24 : 16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), color: color, size: large ? 20 : 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              riskLevel.localizedName(context),
              style: TextStyle(
                color: color,
                fontSize: large ? 16 : 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.moderate:
        return Icons.warning;
      case RiskLevel.high:
        return Icons.error;
    }
  }
}

/// Large risk indicator for results screen
class RiskIndicator extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskIndicator({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final color = Color(riskLevel.colorValue);

    return Column(
      children: [
        // Large icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(_getIcon(), color: color, size: 50),
        ),
        const SizedBox(height: 16),

        // Risk level text
        Text(
          riskLevel.localizedName(context).toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  IconData _getIcon() {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.moderate:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }
}

/// Status chip for photo results
class PhotoStatusChip extends StatelessWidget {
  final RiskLevel? riskLevel;
  final bool isAnalyzed;
  final bool isValidOralPhoto;

  const PhotoStatusChip({
    super.key,
    this.riskLevel,
    required this.isAnalyzed,
    this.isValidOralPhoto = true,
  });

  @override
  Widget build(BuildContext context) {
    // Check for non-oral photo FIRST - this is the most important status
    if (!isValidOralPhoto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off, color: Colors.purple, size: 14),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.notOral,
              style: const TextStyle(
                color: Colors.purple,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (!isAnalyzed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.grey, size: 14),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.notAnalyzed,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (riskLevel == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.qualityIssue,
              style: const TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final color = Color(riskLevel!.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            riskLevel!.localizedName(context),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (riskLevel!) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.moderate:
        return Icons.warning;
      case RiskLevel.high:
        return Icons.error;
    }
  }
}
