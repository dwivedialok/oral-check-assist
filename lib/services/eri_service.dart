import '../models/exposure_data.dart';
import '../models/screening_result.dart';

class CombinedMatrixResult {
  final RiskLevel finalRisk;
  final List<String> adjustedRecommendations;
  final String? eriMessage;
  final String? rescreenInterval;

  const CombinedMatrixResult({
    required this.finalRisk,
    required this.adjustedRecommendations,
    this.eriMessage,
    this.rescreenInterval,
  });
}

class ERIService {
  static final ERIService _instance = ERIService._internal();
  factory ERIService() => _instance;
  ERIService._internal();

  // ---------------------------------------------------------------------------
  // Weight tables
  // ---------------------------------------------------------------------------

  static int typeWeight(List<TobaccoType> types) {
    if (types.isEmpty) return 0;

    final unique = types.toSet();

    bool isSmoking(TobaccoType t) =>
        t == TobaccoType.cigarette ||
        t == TobaccoType.beedi ||
        t == TobaccoType.hookah;

    bool isOral(TobaccoType t) =>
        t == TobaccoType.arecaNut ||
        t == TobaccoType.paanMasala ||
        t == TobaccoType.gutka ||
        t == TobaccoType.surti ||
        t == TobaccoType.gul;

    int baseWeight(TobaccoType t) {
      switch (t) {
        case TobaccoType.cigarette:
        case TobaccoType.beedi:
        case TobaccoType.hookah:
          return 2;

        case TobaccoType.arecaNut:
        case TobaccoType.paanMasala:
        case TobaccoType.gutka:
        case TobaccoType.surti:
        case TobaccoType.gul:
          return 3;

        case TobaccoType.other:
          return 2;
      }
    }

    final sumWeights = unique.fold<int>(0, (sum, t) => sum + baseWeight(t));

    final hasSmoking = unique.any(isSmoking);
    final hasOral = unique.any(isOral);
    final oralCount = unique.where(isOral).length;

    final dualUseBonus = (hasSmoking && hasOral) ? 1 : 0;
    final multiOralBonus = (oralCount >= 2) ? 1 : 0;

    const int typeCap = 5;

    return (sumWeights + dualUseBonus + multiOralBonus).clamp(0, typeCap);
  }

  static int durationWeight(DurationCategory d) {
    switch (d) {
      case DurationCategory.lessThan1Year:
        return 0;
      case DurationCategory.oneToFiveYears:
        return 1;
      case DurationCategory.fiveToTenYears:
        return 2;
      case DurationCategory.tenToTwentyYears:
        return 3;
      case DurationCategory.moreThan20Years:
        return 4;
    }
  }

  static int frequencyWeight(FrequencyCategory f) {
    switch (f) {
      case FrequencyCategory.occasional:
        return 0;
      case FrequencyCategory.oneToFivePerDay:
        return 1;
      case FrequencyCategory.fiveToTenPerDay:
        return 2;
      case FrequencyCategory.moreThanTenPerDay:
        return 3;
    }
  }

  // ---------------------------------------------------------------------------
  // Score & classification
  // ---------------------------------------------------------------------------

  int calculateScore(ExposureData data) {
    if (data.tobaccoTypes.isEmpty) return 0;
    return typeWeight(data.tobaccoTypes) +
        (data.duration != null ? durationWeight(data.duration!) : 0) +
        (data.frequency != null ? frequencyWeight(data.frequency!) : 0);
  }

  ExposureRiskLevel classify(int score) {
    if (score <= 2) return ExposureRiskLevel.low;
    if (score <= 6) return ExposureRiskLevel.moderate;
    return ExposureRiskLevel.high;
  }

  /// Convenience: compute score and classify from raw inputs.
  ExposureData computeExposureData({
    required List<TobaccoType> tobaccoTypes,
    required DurationCategory? duration,
    required FrequencyCategory? frequency,
    String? otherDescription,
  }) {
    final data = ExposureData(
      tobaccoTypes: tobaccoTypes,
      otherDescription: otherDescription,
      duration: duration,
      frequency: frequency,
      exposureScore: 0,
      exposureRiskLevel: ExposureRiskLevel.low,
    );
    final score = calculateScore(data);
    final level = classify(score);
    return ExposureData(
      tobaccoTypes: tobaccoTypes,
      otherDescription: otherDescription,
      duration: duration,
      frequency: frequency,
      exposureScore: score,
      exposureRiskLevel: level,
    );
  }

  // ---------------------------------------------------------------------------
  // Combined AI + ERI decision matrix
  // ---------------------------------------------------------------------------

  CombinedMatrixResult applyCombinedMatrix(
    RiskLevel aiRisk,
    ExposureRiskLevel eriLevel,
    List<String> existingRecommendations,
  ) {
    final recs = List<String>.from(existingRecommendations);

    switch (aiRisk) {
      // Rule 1: AI High — final = High, ERI included in report but ignored for decision
      case RiskLevel.high:
        return CombinedMatrixResult(
          finalRisk: RiskLevel.high,
          adjustedRecommendations: recs,
        );

      // Rule 2: AI Moderate
      case RiskLevel.moderate:
        switch (eriLevel) {
          case ExposureRiskLevel.high:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.high,
              adjustedRecommendations: [
                ...recs,
                'Tobacco exposure significantly elevates risk. Urgent specialist referral recommended.',
              ],
              eriMessage:
                  'Based on reported long-term tobacco exposure, regular clinical evaluation is strongly recommended even if current image findings are not highly suspicious.',
            );
          case ExposureRiskLevel.moderate:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.moderate,
              adjustedRecommendations: [
                ...recs,
                'Tobacco exposure adds to concern. Follow-up dental visit strongly advised.',
              ],
              eriMessage:
                  'Moderate tobacco exposure noted. Combined with image findings, timely clinical follow-up is recommended.',
            );
          case ExposureRiskLevel.low:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.moderate,
              adjustedRecommendations: recs,
            );
        }

      // Rule 3: AI Low
      case RiskLevel.low:
        switch (eriLevel) {
          case ExposureRiskLevel.high:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.low,
              adjustedRecommendations: [
                ...recs,
                'Enhanced Monitoring Recommended',
                'Due to high tobacco exposure, rescreen in 1 month instead of 3.',
              ],
              eriMessage:
                  'Based on reported long-term tobacco exposure, regular clinical evaluation is strongly recommended even if current image findings are not highly suspicious.',
              rescreenInterval: '1 month',
            );
          case ExposureRiskLevel.moderate:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.low,
              adjustedRecommendations: [
                ...recs,
                'Due to moderate tobacco exposure, consider rescreening in 2 months.',
              ],
              rescreenInterval: '2 months',
            );
          case ExposureRiskLevel.low:
            return CombinedMatrixResult(
              finalRisk: RiskLevel.low,
              adjustedRecommendations: recs,
            );
        }
    }
  }

  /// Apply ERI to a [ScreeningResult] and return a new result with ERI fields populated.
  ScreeningResult applyToResult(ScreeningResult result, ExposureData exposure) {
    final matrix = applyCombinedMatrix(
      result.overallRisk,
      exposure.exposureRiskLevel,
      result.recommendations,
    );

    final riskElevated = matrix.finalRisk != result.overallRisk;
    final note = riskElevated
        ? 'The final recommendation combines findings from the analyzed images with your reported tobacco exposure.'
        : null;

    final recommendations = riskElevated
        ? [
            ...matrix.adjustedRecommendations,
            if (!matrix.adjustedRecommendations.contains(note)) note!,
          ]
        : matrix.adjustedRecommendations;

    final guidanceChanged =
        matrix.finalRisk != result.overallRisk ||
        matrix.rescreenInterval != null ||
        matrix.adjustedRecommendations.length > result.recommendations.length;

    var eriMessage = matrix.eriMessage;
    if (guidanceChanged) {
      eriMessage =
          '${eriMessage != null && eriMessage.isNotEmpty ? '$eriMessage\n\n' : ''}Exposure history influenced the final recommendation.';
    }

    return result.copyWith(
      exposureData: exposure,
      finalCombinedRisk: matrix.finalRisk,
      recommendations: recommendations,
      eriMessage: eriMessage,
      eriRescreenInterval: matrix.rescreenInterval,
    );
  }
}
