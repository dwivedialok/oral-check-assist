import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/models/exposure_data.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/services/eri_service.dart';

void main() {
  final eri = ERIService();

  // ---------------------------------------------------------------------------
  // Type weight
  // ---------------------------------------------------------------------------
  group('typeWeight', () {
    test('single smoking type = 2', () {
      expect(ERIService.typeWeight([TobaccoType.cigarette]), 2);
      expect(ERIService.typeWeight([TobaccoType.beedi]), 2);
      expect(ERIService.typeWeight([TobaccoType.hookah]), 2);
      expect(ERIService.typeWeight([TobaccoType.other]), 2);
    });

    test('single chewing types = 3 (including areca nut)', () {
      expect(ERIService.typeWeight([TobaccoType.paanMasala]), 3);
      expect(ERIService.typeWeight([TobaccoType.gutka]), 3);
      expect(ERIService.typeWeight([TobaccoType.surti]), 3);
      expect(ERIService.typeWeight([TobaccoType.gul]), 3);
      expect(ERIService.typeWeight([TobaccoType.arecaNut]), 3);
    });

    test('poly-use sums and caps at 5 with dual/multi-oral bonuses', () {
      // Dual use (smoking + oral): base 2+3 + dualUseBonus 1 = 6, clamp to 5
      expect(
        ERIService.typeWeight([TobaccoType.cigarette, TobaccoType.gutka]),
        5,
      );
      // Multi-oral (2+ oral types): base 3+3 + multiOralBonus 1 = 7, clamp to 5
      expect(ERIService.typeWeight([TobaccoType.gutka, TobaccoType.surti]), 5);
    });

    test('recognizes dual use (smoking + oral) with +1 bonus', () {
      expect(
        ERIService.typeWeight([TobaccoType.beedi, TobaccoType.arecaNut]),
        5,
      );
    });

    test('recognizes multi-oral (2+ oral) with +1 bonus', () {
      expect(
        ERIService.typeWeight([TobaccoType.paanMasala, TobaccoType.gul]),
        5,
      );
    });

    test('duplicate selections are ignored', () {
      expect(ERIService.typeWeight([TobaccoType.gutka, TobaccoType.gutka]), 3);
    });

    test('empty list returns 0', () {
      expect(ERIService.typeWeight([]), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Duration weight
  // ---------------------------------------------------------------------------
  group('durationWeight', () {
    test('maps correctly', () {
      expect(ERIService.durationWeight(DurationCategory.lessThan1Year), 0);
      expect(ERIService.durationWeight(DurationCategory.oneToFiveYears), 1);
      expect(ERIService.durationWeight(DurationCategory.fiveToTenYears), 2);
      expect(ERIService.durationWeight(DurationCategory.tenToTwentyYears), 3);
      expect(ERIService.durationWeight(DurationCategory.moreThan20Years), 4);
    });
  });

  // ---------------------------------------------------------------------------
  // Frequency weight
  // ---------------------------------------------------------------------------
  group('frequencyWeight', () {
    test('maps correctly', () {
      expect(ERIService.frequencyWeight(FrequencyCategory.occasional), 0);
      expect(ERIService.frequencyWeight(FrequencyCategory.oneToFivePerDay), 1);
      expect(ERIService.frequencyWeight(FrequencyCategory.fiveToTenPerDay), 2);
      expect(
        ERIService.frequencyWeight(FrequencyCategory.moreThanTenPerDay),
        3,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Score calculation
  // ---------------------------------------------------------------------------
  group('calculateScore', () {
    test('no tobacco returns 0', () {
      const data = ExposureData.none();
      expect(eri.calculateScore(data), 0);
    });

    test('cigarette + <1yr + occasional = 2+0+0 = 2', () {
      final data = ExposureData(
        tobaccoTypes: [TobaccoType.cigarette],
        duration: DurationCategory.lessThan1Year,
        frequency: FrequencyCategory.occasional,
        exposureScore: 0,
        exposureRiskLevel: ExposureRiskLevel.low,
      );
      expect(eri.calculateScore(data), 2);
    });

    test('gutka + >20yr + >10/day = 3+4+3 = 10', () {
      final data = ExposureData(
        tobaccoTypes: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
        exposureScore: 0,
        exposureRiskLevel: ExposureRiskLevel.low,
      );
      expect(eri.calculateScore(data), 10);
    });

    test('cigarette + 5-10yr + 5-10/day = 2+2+2 = 6', () {
      final data = ExposureData(
        tobaccoTypes: [TobaccoType.cigarette],
        duration: DurationCategory.fiveToTenYears,
        frequency: FrequencyCategory.fiveToTenPerDay,
        exposureScore: 0,
        exposureRiskLevel: ExposureRiskLevel.low,
      );
      expect(eri.calculateScore(data), 6);
    });
  });

  // ---------------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------------
  group('classify', () {
    test('0-2 = Low', () {
      expect(eri.classify(0), ExposureRiskLevel.low);
      expect(eri.classify(1), ExposureRiskLevel.low);
      expect(eri.classify(2), ExposureRiskLevel.low);
    });

    test('3-6 = Moderate', () {
      expect(eri.classify(3), ExposureRiskLevel.moderate);
      expect(eri.classify(4), ExposureRiskLevel.moderate);
      expect(eri.classify(5), ExposureRiskLevel.moderate);
      expect(eri.classify(6), ExposureRiskLevel.moderate);
    });

    test('7+ = High', () {
      expect(eri.classify(7), ExposureRiskLevel.high);
      expect(eri.classify(8), ExposureRiskLevel.high);
      expect(eri.classify(10), ExposureRiskLevel.high);
    });
  });

  // ---------------------------------------------------------------------------
  // computeExposureData convenience
  // ---------------------------------------------------------------------------
  group('computeExposureData', () {
    test('computes score and classifies', () {
      final data = eri.computeExposureData(
        tobaccoTypes: [TobaccoType.paanMasala],
        duration: DurationCategory.tenToTwentyYears,
        frequency: FrequencyCategory.fiveToTenPerDay,
      );
      // 3 + 3 + 2 = 8 -> High
      expect(data.exposureScore, 8);
      expect(data.exposureRiskLevel, ExposureRiskLevel.high);
    });
  });

  // ---------------------------------------------------------------------------
  // Combined decision matrix
  // ---------------------------------------------------------------------------
  group('applyCombinedMatrix', () {
    const baseRecs = ['Base recommendation'];

    test('Rule 1: AI High -> always High, ERI ignored for decision', () {
      for (final eriLevel in ExposureRiskLevel.values) {
        final result = eri.applyCombinedMatrix(
          RiskLevel.high,
          eriLevel,
          baseRecs,
        );
        expect(result.finalRisk, RiskLevel.high);
      }
    });

    test('Rule 2a: AI Moderate + ERI High -> elevate to High', () {
      final result = eri.applyCombinedMatrix(
        RiskLevel.moderate,
        ExposureRiskLevel.high,
        baseRecs,
      );
      expect(result.finalRisk, RiskLevel.high);
      expect(result.eriMessage, isNotNull);
      expect(
        result.adjustedRecommendations.length,
        greaterThan(baseRecs.length),
      );
    });

    test(
      'Rule 2b: AI Moderate + ERI Moderate -> keep Moderate, strengthen text',
      () {
        final result = eri.applyCombinedMatrix(
          RiskLevel.moderate,
          ExposureRiskLevel.moderate,
          baseRecs,
        );
        expect(result.finalRisk, RiskLevel.moderate);
        expect(result.eriMessage, isNotNull);
        expect(
          result.adjustedRecommendations.length,
          greaterThan(baseRecs.length),
        );
      },
    );

    test('Rule 2c: AI Moderate + ERI Low -> keep Moderate, no extra recs', () {
      final result = eri.applyCombinedMatrix(
        RiskLevel.moderate,
        ExposureRiskLevel.low,
        baseRecs,
      );
      expect(result.finalRisk, RiskLevel.moderate);
      expect(result.eriMessage, isNull);
      expect(result.adjustedRecommendations, baseRecs);
    });

    test(
      'Rule 3a: AI Low + ERI High -> keep Low, enhanced monitoring, 1 month',
      () {
        final result = eri.applyCombinedMatrix(
          RiskLevel.low,
          ExposureRiskLevel.high,
          baseRecs,
        );
        expect(result.finalRisk, RiskLevel.low);
        expect(result.rescreenInterval, '1 month');
        expect(result.eriMessage, isNotNull);
        expect(
          result.adjustedRecommendations,
          contains('Enhanced Monitoring Recommended'),
        );
      },
    );

    test('Rule 3b: AI Low + ERI Moderate -> keep Low, 2 months', () {
      final result = eri.applyCombinedMatrix(
        RiskLevel.low,
        ExposureRiskLevel.moderate,
        baseRecs,
      );
      expect(result.finalRisk, RiskLevel.low);
      expect(result.rescreenInterval, '2 months');
    });

    test('Rule 3c: AI Low + ERI Low -> no change', () {
      final result = eri.applyCombinedMatrix(
        RiskLevel.low,
        ExposureRiskLevel.low,
        baseRecs,
      );
      expect(result.finalRisk, RiskLevel.low);
      expect(result.rescreenInterval, isNull);
      expect(result.eriMessage, isNull);
      expect(result.adjustedRecommendations, baseRecs);
    });

    test('ERI never downgrades AI risk', () {
      // AI Moderate + ERI Low should not become Low
      final r1 = eri.applyCombinedMatrix(
        RiskLevel.moderate,
        ExposureRiskLevel.low,
        baseRecs,
      );
      expect(r1.finalRisk, RiskLevel.moderate);

      // AI High + ERI Low should not become anything less than High
      final r2 = eri.applyCombinedMatrix(
        RiskLevel.high,
        ExposureRiskLevel.low,
        baseRecs,
      );
      expect(r2.finalRisk, RiskLevel.high);
    });
  });

  group('applyToResult', () {
    ScreeningResult baseResult({required RiskLevel overallRisk}) =>
        ScreeningResult(
          overallRisk: overallRisk,
          overallConfidence: 0.8,
          photoResults: const [],
          recommendations: const ['Base recommendation'],
          specialistRequired: overallRisk.specialistRequired,
          urgencyLevel: UrgencyLevel.routine,
          urgencyText: UrgencyLevel.routine.displayText,
          aggregatedProbabilities: const ClassProbabilities(
            healthy: 0.8,
            benign: 0.1,
            opmd: 0.05,
            oca: 0.05,
          ),
          analyzedAt: DateTime(2025),
          overallAssessmentTitle: 'Assessment',
          overallAssessmentMessage: 'Message',
          labelConfidence: 0.8,
          screeningOutcome: ScreeningOutcome.lowRisk,
          subtypeGuidance: SubtypeGuidance.none,
          photosCaptured: 1,
          photosUsed: 1,
        );

    test(
      'preserves overallRisk and updates finalCombinedRisk when elevated',
      () {
        final result = baseResult(overallRisk: RiskLevel.moderate);
        final exposure = eri.computeExposureData(
          tobaccoTypes: const [TobaccoType.gutka],
          duration: DurationCategory.moreThan20Years,
          frequency: FrequencyCategory.moreThanTenPerDay,
        );

        final updated = eri.applyToResult(result, exposure);
        expect(updated.overallRisk, RiskLevel.moderate);
        expect(updated.finalCombinedRisk, RiskLevel.high);
        expect(
          updated.recommendations.join(' '),
          contains('combines findings from the analyzed images'),
        );
      },
    );

    test('sets finalCombinedRisk even when not elevated', () {
      final result = baseResult(overallRisk: RiskLevel.low);
      final exposure = const ExposureData.none();
      final updated = eri.applyToResult(result, exposure);
      expect(updated.overallRisk, RiskLevel.low);
      expect(updated.finalCombinedRisk, RiskLevel.low);
    });
  });

  group('ScreeningResult V2 serialization', () {
    test('fromJson defaults finalCombinedRisk to overallRisk when missing', () {
      final json = {
        'v': 2,
        'overallRisk': 'moderate',
        'overallConfidence': 0.5,
        'photoResults': <dynamic>[],
        'recommendations': <dynamic>[],
        'specialistRequired': true,
        'urgencyLevel': 'routine',
        'urgencyText': 'Routine (2\u20134 weeks)',
        'aggregatedProbabilities': {
          'healthy': 0.0,
          'benign': 0.0,
          'opmd': 0.0,
          'oca': 0.0,
        },
        'analyzedAt': DateTime(2025).toIso8601String(),
        'overallAssessmentTitle': 'Moderate Risk',
        'overallAssessmentMessage': 'Message',
        'labelConfidence': 0.5,
        'screeningOutcome': 'reviewRecommended',
        'subtypeGuidance': 'none',
        'photosCaptured': 1,
        'photosUsed': 1,
      };

      final result = ScreeningResult.fromJson(json);
      expect(result.finalCombinedRisk, RiskLevel.moderate);
    });

    test('old format (without v:2) throws FormatException', () {
      final json = {
        'overallRisk': 'moderate',
        'overallConfidence': 0.5,
        'photoResults': <dynamic>[],
        'recommendations': <dynamic>[],
        'specialistRequired': true,
        'urgencyLevel': 'routine',
        'urgencyText': 'Routine',
        'aggregatedProbabilities': {
          'healthy': 0.0,
          'benign': 0.0,
          'opmd': 0.0,
          'oca': 0.0,
        },
        'analyzedAt': DateTime(2025).toIso8601String(),
        'overallAssessmentTitle': 'Moderate Risk',
        'overallAssessmentMessage': 'Message',
        'labelConfidence': 0.5,
        'actionConfidence': 'moderate',
        'disagreementType': 'none',
        'howWeDecidedBullets': <dynamic>[],
        'photosCaptured': 1,
        'photosUsed': 1,
      };

      expect(() => ScreeningResult.fromJson(json), throwsFormatException);
    });
  });

  // ---------------------------------------------------------------------------
  // ExposureData serialization
  // ---------------------------------------------------------------------------
  group('ExposureData serialization', () {
    test('round-trip toJson/fromJson', () {
      final original = ExposureData(
        tobaccoTypes: [TobaccoType.cigarette, TobaccoType.arecaNut],
        otherDescription: 'Herbal mix',
        duration: DurationCategory.fiveToTenYears,
        frequency: FrequencyCategory.oneToFivePerDay,
        exposureScore: 5,
        exposureRiskLevel: ExposureRiskLevel.moderate,
      );
      final json = original.toJson();
      final restored = ExposureData.fromJson(json);

      expect(restored.tobaccoTypes, original.tobaccoTypes);
      expect(restored.otherDescription, original.otherDescription);
      expect(restored.duration, original.duration);
      expect(restored.frequency, original.frequency);
      expect(restored.exposureScore, original.exposureScore);
      expect(restored.exposureRiskLevel, original.exposureRiskLevel);
    });

    test('none() round-trip', () {
      const original = ExposureData.none();
      final json = original.toJson();
      final restored = ExposureData.fromJson(json);

      expect(restored.tobaccoTypes, isEmpty);
      expect(restored.duration, isNull);
      expect(restored.frequency, isNull);
      expect(restored.exposureScore, 0);
      expect(restored.exposureRiskLevel, ExposureRiskLevel.low);
    });
  });
}
