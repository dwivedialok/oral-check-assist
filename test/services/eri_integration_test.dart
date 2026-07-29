import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/models/exposure_data.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/services/eri_service.dart';
import 'package:oral_cavity_classifier_app/services/model_inference_service.dart';

import '../helpers/fake_photo_results.dart';

/// Build a [ScreeningResult] from synthetic photos via [aggregateResults],
/// then optionally apply ERI.
ScreeningResult _buildResult(List<PhotoResult> photos) =>
    ModelInferenceService().aggregateResults(photos);

ExposureData _exposure({
  List<TobaccoType> types = const [],
  DurationCategory? duration,
  FrequencyCategory? frequency,
}) => ERIService().computeExposureData(
  tobaccoTypes: types,
  duration: duration,
  frequency: frequency,
);

void main() {
  final eri = ERIService();

  // ---------------------------------------------------------------------------
  // Low AI risk + varying ERI levels
  // ---------------------------------------------------------------------------
  group('Low AI risk + ERI', () {
    late ScreeningResult lowResult;

    setUp(() {
      lowResult = _buildResult(allPhotoTypes.map(normalPhoto).toList());
      expect(lowResult.overallRisk, RiskLevel.low, reason: 'precondition');
    });

    test('no tobacco -> unchanged Low, no rescreen override', () {
      final exposure = const ExposureData.none();
      final updated = eri.applyToResult(lowResult, exposure);

      expect(updated.overallRisk, RiskLevel.low);
      expect(updated.finalCombinedRisk, RiskLevel.low);
      expect(updated.eriRescreenInterval, isNull);
    });

    test('moderate tobacco -> Low + rescreen 2 months', () {
      final exposure = _exposure(
        types: [TobaccoType.cigarette],
        duration: DurationCategory.fiveToTenYears,
        frequency: FrequencyCategory.oneToFivePerDay,
      );
      // score = 2 + 2 + 1 = 5 -> moderate
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.moderate);

      final updated = eri.applyToResult(lowResult, exposure);

      expect(updated.overallRisk, RiskLevel.low);
      expect(updated.finalCombinedRisk, RiskLevel.low);
      expect(updated.eriRescreenInterval, '2 months');
    });

    test('heavy tobacco (gutka + 20yr + 10/day) -> Low + rescreen 1 month', () {
      final exposure = _exposure(
        types: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
      );
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.high);

      final updated = eri.applyToResult(lowResult, exposure);

      expect(updated.overallRisk, RiskLevel.low);
      expect(updated.finalCombinedRisk, RiskLevel.low);
      expect(updated.eriRescreenInterval, '1 month');
      expect(updated.eriMessage, isNotNull);
      expect(
        updated.recommendations.join(' '),
        contains('Enhanced Monitoring'),
      );
    });

    test('dual tobacco (beedi + gutka) -> high ERI score -> 1 month', () {
      final exposure = _exposure(
        types: [TobaccoType.beedi, TobaccoType.gutka],
        duration: DurationCategory.tenToTwentyYears,
        frequency: FrequencyCategory.fiveToTenPerDay,
      );
      // typeWeight: sum(2+3) + dualUseBonus(1) = 6, capped at 5
      // duration: 3, frequency: 2 -> total = 5+3+2 = 10 -> high
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.high);

      final updated = eri.applyToResult(lowResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.low);
      expect(updated.eriRescreenInterval, '1 month');
    });

    test('multi-oral (paan masala + gul) -> high ERI -> 1 month', () {
      final exposure = _exposure(
        types: [TobaccoType.paanMasala, TobaccoType.gul],
        duration: DurationCategory.tenToTwentyYears,
        frequency: FrequencyCategory.fiveToTenPerDay,
      );
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.high);

      final updated = eri.applyToResult(lowResult, exposure);

      expect(updated.eriRescreenInterval, '1 month');
    });
  });

  // ---------------------------------------------------------------------------
  // Moderate AI risk + varying ERI levels
  // ---------------------------------------------------------------------------
  group('Moderate AI risk + ERI', () {
    late ScreeningResult modResult;

    setUp(() {
      // All 5 moderate photos ensures top-K picks them -> hybrid avg(top2) >= 0.4735 -> moderate
      modResult = _buildResult(allPhotoTypes.map(moderatePhoto).toList());
      expect(
        modResult.overallRisk.index,
        greaterThanOrEqualTo(RiskLevel.moderate.index),
        reason: 'precondition: at least moderate',
      );
    });

    test('no tobacco -> stays Moderate', () {
      final exposure = const ExposureData.none();
      final updated = eri.applyToResult(modResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.moderate);
    });

    test('moderate ERI -> Moderate, strengthened text', () {
      final exposure = _exposure(
        types: [TobaccoType.cigarette],
        duration: DurationCategory.fiveToTenYears,
        frequency: FrequencyCategory.oneToFivePerDay,
      );
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.moderate);

      final updated = eri.applyToResult(modResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.moderate);
      expect(updated.eriMessage, isNotNull);
      expect(
        updated.recommendations.join(' '),
        contains('Tobacco exposure adds to concern'),
      );
    });

    test('high ERI -> elevated to High', () {
      final exposure = _exposure(
        types: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
      );
      expect(exposure.exposureRiskLevel, ExposureRiskLevel.high);

      final updated = eri.applyToResult(modResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.high);
      expect(updated.eriMessage, isNotNull);
      expect(
        updated.recommendations.join(' '),
        contains('Urgent specialist referral'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // High AI risk + varying ERI levels
  // ---------------------------------------------------------------------------
  group('High AI risk + ERI', () {
    late ScreeningResult highResult;

    setUp(() {
      // Use multiple OCA photos to ensure maxScore >= 0.65 -> screen positive + OCA dominant -> High
      highResult = _buildResult(allPhotoTypes.map(ocaPhoto).toList());
      expect(
        highResult.overallRisk.index,
        greaterThanOrEqualTo(RiskLevel.high.index),
        reason: 'precondition: at least high',
      );
    });

    test('high ERI -> stays High (ERI never downgrades)', () {
      final exposure = _exposure(
        types: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
      );
      final updated = eri.applyToResult(highResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.high);
    });

    test('no tobacco -> stays High', () {
      final exposure = const ExposureData.none();
      final updated = eri.applyToResult(highResult, exposure);

      expect(updated.finalCombinedRisk, RiskLevel.high);
    });
  });

  // ---------------------------------------------------------------------------
  // Guidance message
  // ---------------------------------------------------------------------------
  group('guidance message', () {
    test('eriMessage includes exposure history note when guidance changed', () {
      final lowResult = _buildResult(allPhotoTypes.map(normalPhoto).toList());
      final exposure = _exposure(
        types: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
      );

      final updated = eri.applyToResult(lowResult, exposure);

      expect(
        updated.eriMessage,
        contains('Exposure history influenced the final recommendation'),
      );
    });

    test('no exposure note when nothing changed', () {
      final lowResult = _buildResult(allPhotoTypes.map(normalPhoto).toList());
      final exposure = const ExposureData.none();

      final updated = eri.applyToResult(lowResult, exposure);

      // eriMessage should be null or not contain the exposure note
      final msg = updated.eriMessage ?? '';
      expect(msg.contains('Exposure history'), false);
    });
  });
}
