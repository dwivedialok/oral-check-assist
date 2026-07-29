import 'package:flutter/material.dart';
import '../models/exposure_data.dart';
import '../models/photo_capture.dart';
import '../models/screening_result.dart';
import '../models/screening_session.dart';
import 'app_localizations.dart';

/// Returns a user-friendly sentence for a 5-class label, with the technical label in brackets.
/// Use for results UI so end users see plain language; clinicians still see the label.
///
/// `Unknown` and `Uncertain` are intentionally distinct strings:
///   * `Unknown` → the 5-class model classified the photo as out-of-distribution
///     (likely non-oral image). The photo is excluded from aggregation.
///   * `Uncertain` → the 5-class model could not place > 50% probability on any
///     single class, but the binary screening signal is still trusted. The
///     photo IS used in aggregation; the binary risk badge remains valid.
/// Surfacing them with different wording avoids the "camera quality 100% but
/// image unclear" cognitive dissonance clinicians reported.
String classLabelFriendly(AppLocalizations l10n, String technicalLabel) {
  switch (technicalLabel) {
    case 'Healthy':
      return l10n.classFriendlyHealthy;
    case 'Benign':
      return l10n.classFriendlyBenign;
    case 'OPMD':
      return l10n.classFriendlyOPMD;
    case 'OCA':
      return l10n.classFriendlyOCA;
    case 'Uncertain':
      return l10n.classFriendlyUncertain;
    case 'Unknown':
      return l10n.classFriendlyUnknown;
    default:
      return l10n.classFriendlyUnknown;
  }
}

/// Localized display names for [ScreeningStatus].
extension ScreeningStatusL10n on ScreeningStatus {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ScreeningStatus.notStarted:
        return l10n.statusNotStarted;
      case ScreeningStatus.capturing:
        return l10n.statusCapturing;
      case ScreeningStatus.reviewing:
        return l10n.statusReviewing;
      case ScreeningStatus.analyzing:
        return l10n.statusAnalyzing;
      case ScreeningStatus.completed:
        return l10n.statusCompleted;
      case ScreeningStatus.failed:
        return l10n.statusFailed;
    }
  }
}

/// Localized urgency text for [UrgencyLevel] (replaces hardcoded displayText).
String urgencyDisplayText(AppLocalizations l10n, UrgencyLevel level) {
  switch (level) {
    case UrgencyLevel.routine:
      return l10n.urgencyRoutine;
    case UrgencyLevel.prompt:
      return l10n.urgencyPrompt;
    case UrgencyLevel.urgent:
      return l10n.urgencyUrgent;
    case UrgencyLevel.retake:
      return l10n.urgencyRetakePhotos;
  }
}

extension TobaccoTypeL10n on TobaccoType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
      case TobaccoType.cigarette:
        return l10n.tobaccoTypeCigarette;
      case TobaccoType.beedi:
        return l10n.tobaccoTypeBeedi;
      case TobaccoType.hookah:
        return l10n.tobaccoTypeHookah;
      case TobaccoType.arecaNut:
        return l10n.tobaccoTypeArecaNut;
      case TobaccoType.paanMasala:
        return l10n.tobaccoTypePaanMasala;
      case TobaccoType.gutka:
        return l10n.tobaccoTypeGutka;
      case TobaccoType.surti:
        return l10n.tobaccoTypeSurti;
      case TobaccoType.gul:
        return l10n.tobaccoTypeGul;
      case TobaccoType.other:
        return l10n.tobaccoTypeOther;
    }
  }
}

extension DurationCategoryL10n on DurationCategory {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
      case DurationCategory.lessThan1Year:
        return l10n.durationLessThan1Year;
      case DurationCategory.oneToFiveYears:
        return l10n.duration1To5Years;
      case DurationCategory.fiveToTenYears:
        return l10n.duration5To10Years;
      case DurationCategory.tenToTwentyYears:
        return l10n.duration10To20Years;
      case DurationCategory.moreThan20Years:
        return l10n.durationMoreThan20Years;
    }
  }
}

extension FrequencyCategoryL10n on FrequencyCategory {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
      case FrequencyCategory.occasional:
        return l10n.frequencyOccasional;
      case FrequencyCategory.oneToFivePerDay:
        return l10n.frequency1To5PerDay;
      case FrequencyCategory.fiveToTenPerDay:
        return l10n.frequency5To10PerDay;
      case FrequencyCategory.moreThanTenPerDay:
        return l10n.frequencyMoreThan10PerDay;
    }
  }
}

extension ExposureRiskLevelL10n on ExposureRiskLevel {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
      case ExposureRiskLevel.low:
        return l10n.exposureRiskLow;
      case ExposureRiskLevel.moderate:
        return l10n.exposureRiskModerate;
      case ExposureRiskLevel.high:
        return l10n.exposureRiskHigh;
    }
  }
}

/// Localized title for [SubtypeGuidance] (high-risk / specialist messages). Returns empty for [SubtypeGuidance.none].
String subtypeGuidanceTitleL10n(AppLocalizations l10n, SubtypeGuidance g) {
  switch (g) {
    case SubtypeGuidance.none:
      return '';
    case SubtypeGuidance.ocaDominant:
      return l10n.riskSubtypeTitleOcaDominant;
    case SubtypeGuidance.opmdDominant:
      return l10n.riskSubtypeTitleOpmdDominant;
    case SubtypeGuidance.benignDominant:
      return l10n.riskSubtypeTitleBenignDominant;
  }
}

/// Localized message for [SubtypeGuidance]. Returns empty for [SubtypeGuidance.none].
String subtypeGuidanceMessageL10n(AppLocalizations l10n, SubtypeGuidance g) {
  switch (g) {
    case SubtypeGuidance.none:
      return '';
    case SubtypeGuidance.ocaDominant:
      return l10n.riskSubtypeMessageOcaDominant;
    case SubtypeGuidance.opmdDominant:
      return l10n.riskSubtypeMessageOpmdDominant;
    case SubtypeGuidance.benignDominant:
      return l10n.riskSubtypeMessageBenignDominant;
  }
}

/// Localize per-photo summary label. Returns null if [perPhotoSummaryLabel] is null.
String? localizePerPhotoSummaryLabel(AppLocalizations l10n, String? perPhotoSummaryLabel) {
  if (perPhotoSummaryLabel == null) return null;
  switch (perPhotoSummaryLabel) {
    case 'Potential Concern':
      return l10n.perPhotoLabelPotentialConcern;
    case 'Review Recommended':
      return l10n.perPhotoLabelReviewRecommended;
    case 'Healthy':
      return l10n.perPhotoLabelHealthy;
    case 'Retake or further analysis needed':
      return l10n.perPhotoLabelRetakeOrReview;
  }
  return perPhotoSummaryLabel;
}

/// Localize per-photo disagreement note (when binary and 5-class disagree). Returns null if [note] is null.
String? localizePerPhotoDisagreementNote(AppLocalizations l10n, String? note) {
  if (note == null) return null;
  if (note ==
      'Screening detected risk factors. Visual pattern appears healthy, but professional review is recommended.') {
    return l10n.perPhotoNoteHighConflict;
  }
  if (note ==
      'Subtle signs detected. Visual pattern: Healthy. Consider a follow-up.') {
    return l10n.perPhotoNoteModerateConflict;
  }
  if (note ==
      'Screening detected risk factors. Visual pattern appears benign. Professional review is recommended.') {
    return l10n.perPhotoNoteHighConflictBenign;
  }
  if (note ==
      'Subtle signs detected. Visual pattern: Benign. Consider a follow-up.') {
    return l10n.perPhotoNoteModerateConflictBenign;
  }
  return note;
}

/// Localize overall assessment message (results screen).
String localizeAssessmentMessage(AppLocalizations l10n, String message) {
  switch (message) {
    case 'No concerning signs detected in these photos.':
      return l10n.assessmentMessageLowRisk;
    case 'Photos were not clear/consistent enough to give a reliable result. Please retake in good light. If you have symptoms (pain, ulcer >2 weeks, bleeding), consult a clinician.':
      return l10n.assessmentMessageInconclusiveRetake;
    case 'Findings may require urgent professional evaluation. Please consult a dentist/oral specialist within one week.':
      return l10n.assessmentMessageHighRisk;
    case 'Most signs look non-concerning. One check suggested follow-up, so a routine dental review is recommended.':
      return l10n.assessmentMessageModerateReviewSuggested;
    case 'Some changes may need follow-up. Please arrange a dental review within 1–2 weeks.':
      return l10n.assessmentMessageModerateNeedsAttention;
    case 'Some changes may need professional review. Please arrange a review within 1–2 weeks.':
      return l10n.assessmentMessageModerateNeedsReview;
    default:
      return message;
  }
}

/// Localize a recommendation string (results screen suggestions). Handles list-style
/// recommendations by localizing photo type names in "Need clearer photos for: ..." and
/// "Pay special attention to: ...".
String localizeRecommendation(BuildContext context, String rec) {
  final l10n = AppLocalizations.of(context)!;
  const needClearerPrefix = 'Need clearer photos for: ';
  const payAttentionPrefix = 'Pay special attention to: ';
  if (rec.startsWith(needClearerPrefix)) {
    final list = rec.substring(needClearerPrefix.length).split(',').map((s) => s.trim()).toList();
    final localized = list.map((name) {
      PhotoType? type;
      for (final t in PhotoType.values) {
        if (t.displayName == name) {
          type = t;
          break;
        }
      }
      return type != null ? type.localizedName(context) : name;
    }).join(', ');
    return l10n.recNeedClearerPhotosFor(localized);
  }
  if (rec.startsWith(payAttentionPrefix)) {
    final list = rec.substring(payAttentionPrefix.length).split(',').map((s) => s.trim()).toList();
    final localized = list.map((name) {
      PhotoType? type;
      for (final t in PhotoType.values) {
        if (t.displayName == name) {
          type = t;
          break;
        }
      }
      return type != null ? type.localizedName(context) : name;
    }).join(', ');
    return l10n.recPaySpecialAttentionTo(localized);
  }
  switch (rec) {
    case 'No concerning signs detected':
      return l10n.recNoConcerningSigns;
    case 'Continue regular oral hygiene':
      return l10n.recContinueOralHygiene;
    case 'Schedule routine dental checkup':
      return l10n.recScheduleRoutineCheckup;
    case 'Rescreen in 3 months':
      return l10n.recRescreen3Months;
    case 'Some changes detected that need attention':
      return l10n.recSomeChangesNeedAttention;
    case 'Schedule appointment with dentist within 2-4 weeks':
      return l10n.recSchedule2to4Weeks;
    case 'Avoid tobacco and alcohol':
      return l10n.recAvoidTobaccoAlcohol;
    case 'Monitor any changes closely':
      return l10n.recMonitorChangesClosely;
    case 'Concerning changes detected':
      return l10n.recConcerningChangesDetected;
    case 'URGENT: See oral surgeon or oncologist within 1 week':
      return l10n.recUrgentSeeSpecialist;
    case 'Bring this report to your appointment':
      return l10n.recBringReportToAppointment;
    case 'Early detection significantly improves outcomes':
      return l10n.recEarlyDetectionImprovesOutcomes;
    default:
      return localizeEriText(l10n, rec);
  }
}

/// Localize verdict explanation from "How we decided" (detailed results). Matches
/// known English strings and returns translated text; dynamic parts (label, risk, note)
/// are preserved or localized where possible.
String localizeVerdictExplanation(BuildContext context, String text) {
  final l10n = AppLocalizations.of(context)!;
  const lowRisk = 'Both checks suggest low risk. No immediate follow-up needed; routine check-ups are still recommended.';
  if (text == lowRisk) return l10n.verdictBothLowRisk;
  const referralAppro = 'Both checks suggest referral is appropriate. Please see a healthcare provider for further evaluation.';
  if (text == referralAppro) return l10n.verdictReferralAppropriate;
  if (text.startsWith('Both checks suggest some concern (') && text.endsWith('). We recommend follow-up with a healthcare provider.')) {
    final label = text.substring(34, text.length - 49);
    return l10n.verdictBothSomeConcern(classLabelFriendly(l10n, label));
  }
  if (text.startsWith('The two checks gave different signals. We show ') && text.endsWith(' and recommend follow-up so a professional can decide.')) {
    final risk = text.substring(45, text.length - 55);
    final riskLocalized = risk == 'Low Risk' ? l10n.riskLow : (risk == 'Moderate Risk' ? l10n.riskModerate : (risk == 'High Risk' ? l10n.riskHigh : risk));
    return l10n.verdictDifferentSignals(riskLocalized);
  }
  if (text.startsWith('This photo could not be assessed. ')) {
    final note = text.substring(34);
    final noteLocalized = note == 'Please retake.' ? l10n.verdictPleaseRetake : note;
    return l10n.verdictCouldNotAssess(noteLocalized);
  }
  return text;
}

String localizeEriText(AppLocalizations l10n, String text) {
  switch (text) {
    case 'Tobacco exposure significantly elevates risk. Urgent specialist referral recommended.':
      return l10n.eriRecHighUrgentReferral;
    case 'Based on reported long-term tobacco exposure, regular clinical evaluation is strongly recommended even if current image findings are not highly suspicious.':
      return l10n.eriMsgLongTermExposure;
    case 'Tobacco exposure adds to concern. Follow-up dental visit strongly advised.':
      return l10n.eriRecModerateConcern;
    case 'Moderate tobacco exposure noted. Combined with image findings, timely clinical follow-up is recommended.':
      return l10n.eriMsgModerateExposure;
    case 'Enhanced Monitoring Recommended':
      return l10n.eriRecEnhancedMonitoring;
    case 'Due to high tobacco exposure, rescreen in 1 month instead of 3.':
      return l10n.eriRecRescreen1Month;
    case 'Due to moderate tobacco exposure, consider rescreening in 2 months.':
      return l10n.eriRecRescreen2Months;
    case 'Final recommendation elevated due to reported high exposure.':
    case 'The final recommendation combines findings from the analyzed images with your reported tobacco exposure.':
      return l10n.eriFinalRecommendationElevatedNote;
    default:
      return text;
  }
}

/// Localized display names for [RiskLevel].
extension RiskLevelL10n on RiskLevel {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case RiskLevel.low:
        return l10n.riskLow;
      case RiskLevel.moderate:
        return l10n.riskModerate;
      case RiskLevel.high:
        return l10n.riskHigh;
    }
  }
}

/// Localized display names for the user-selectable [OralPhotoLabel].
///
/// Purely presentational. Used by the capture/review UI and the PDF report
/// helper; never consumed by inference or risk aggregation.
extension OralPhotoLabelL10n on OralPhotoLabel {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
      case OralPhotoLabel.frontView:
        return l10n.photoFrontView;
      case OralPhotoLabel.rightCheek:
        return l10n.photoRightCheek;
      case OralPhotoLabel.leftCheek:
        return l10n.photoLeftCheek;
      case OralPhotoLabel.tongue:
        return l10n.photoTongue;
      case OralPhotoLabel.palate:
        return l10n.photoPalate;
      case OralPhotoLabel.custom:
        return l10n.photoLabelCustom;
    }
  }
}

/// Resolved localized display string for a captured photo's effective label.
///
/// For [OralPhotoLabel.custom], returns the trimmed custom text when
/// non-empty; otherwise falls back to the localized slot name so legacy
/// sessions and edge cases still render sensibly.
String photoCaptureEffectiveLabelText(
  AppLocalizations l10n,
  PhotoCapture photo,
) {
  final label = photo.effectiveLabel;
  if (label == OralPhotoLabel.custom) {
    final text = photo.customLabelText?.trim();
    if (text != null && text.isNotEmpty) return text;
    // Fallback to the slot default (localized) if custom text is missing.
    return photo.type.localizedNameL10n(l10n);
  }
  return label.localizedNameL10n(l10n);
}

/// Resolved localized display string for a [PhotoResult]'s effective label.
///
/// Mirrors [photoCaptureEffectiveLabelText]; this variant is used by the
/// results/review UI and the PDF row helper so overrides set at capture
/// time flow through to every display surface (review cards, "Areas
/// needing attention" chips, detailed photo-by-photo list, PDF).
///
/// Order of precedence:
/// 1. Trimmed custom text when [PhotoResult.photoLabel] is
///    [OralPhotoLabel.custom] and text is non-empty.
/// 2. Localized preset name for any other user-selected label.
/// 3. Legacy fallback: localized slot name from [PhotoResult.photoType].
String photoResultEffectiveLabelText(
  AppLocalizations l10n,
  PhotoResult photo,
) {
  final label = photo.photoLabel;
  if (label == null) {
    return photo.photoType.localizedNameL10n(l10n);
  }
  if (label == OralPhotoLabel.custom) {
    final text = photo.customLabelText?.trim();
    if (text != null && text.isNotEmpty) return text;
    return photo.photoType.localizedNameL10n(l10n);
  }
  return label.localizedNameL10n(l10n);
}

/// Localized display names for [PhotoType].
extension PhotoTypeL10n on PhotoType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return localizedNameL10n(l10n);
  }

  String localizedNameL10n(AppLocalizations l10n) {
    switch (this) {
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

  /// Localized capture instruction for this photo type.
  String instruction(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PhotoType.frontView:
        return l10n.instructionFrontView;
      case PhotoType.rightCheek:
        return l10n.instructionRightCheek;
      case PhotoType.leftCheek:
        return l10n.instructionLeftCheek;
      case PhotoType.tongue:
        return l10n.instructionTongue;
      case PhotoType.palate:
        return l10n.instructionPalate;
    }
  }
}
