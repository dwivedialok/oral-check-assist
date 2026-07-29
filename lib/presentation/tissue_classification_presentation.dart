import '../models/screening_result.dart';
import '../services/screening_config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';

/// Whether the session has aggregated 5-class detail to show (usable photos only).
/// When [photosUsed] is 0 (e.g. all frames excluded as non-oral), skip the section per product spec.
bool showDetailedTissueClassification(ScreeningResult result) => result.photosUsed > 0;

/// Explanatory copy for the aggregate tissue-pattern distribution (wording only; no inference).
String tissueInterpretationParagraph(AppLocalizations l10n, ScreeningResult result) {
  final peak = result.aggregatedProbabilities.confidence;
  final dominantTechnical = result.aggregatedProbabilities.predictedClass;
  final dominantFriendly = classLabelFriendly(l10n, dominantTechnical);
  if (peak >= ScreeningConfig.subtypeConfidenceThreshold) {
    return l10n.tissueInterpretationDominant(dominantFriendly);
  }
  return l10n.tissueInterpretationMixed;
}
