import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/models/photo_capture.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/services/model_inference_service.dart';
import 'package:oral_cavity_classifier_app/services/screening_config.dart';

import '../helpers/fake_photo_results.dart';

void main() {
  final service = ModelInferenceService();

  // ===========================================================================
  // Hybrid patient-level binary aggregation rule
  // ===========================================================================
  group('hybrid aggregation rule', () {
    test('single photo >= 0.65 triggers screen positive', () {
      final photos = [
        fakePhoto(
          type: PhotoType.frontView,
          riskLevel: RiskLevel.high,
          cancerProbability: 0.70,
          oca: 0.50,
          opmd: 0.20,
          benign: 0.10,
          healthy: 0.05,
          quality: 0.90,
        ),
        normalPhoto(PhotoType.rightCheek),
        normalPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
    });

    test('avg(top2) >= 0.4735 triggers screen positive', () {
      final photos = [
        fakePhoto(
          type: PhotoType.frontView,
          riskLevel: RiskLevel.moderate,
          cancerProbability: 0.50,
          opmd: 0.40,
          oca: 0.10,
          benign: 0.30,
          healthy: 0.10,
          quality: 0.90,
        ),
        fakePhoto(
          type: PhotoType.rightCheek,
          riskLevel: RiskLevel.moderate,
          cancerProbability: 0.45,
          opmd: 0.35,
          oca: 0.10,
          benign: 0.30,
          healthy: 0.10,
          quality: 0.88,
        ),
        normalPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
    });

    test(
      'single moderate spike with all others low -> NOT screen positive (artifact protection)',
      () {
        final photos = [
          fakePhoto(
            type: PhotoType.frontView,
            riskLevel: RiskLevel.moderate,
            cancerProbability: 0.55,
            opmd: 0.30,
            oca: 0.10,
            benign: 0.30,
            healthy: 0.20,
            quality: 0.90,
          ),
          normalPhoto(PhotoType.rightCheek),
          normalPhoto(PhotoType.leftCheek),
          normalPhoto(PhotoType.tongue),
          normalPhoto(PhotoType.palate),
        ];
        final result = service.aggregateResults(photos);

        // maxScore=0.55, secondScore~0.08 => avg≈0.315 < 0.4735 => not positive
        // and maxScore=0.55 < 0.65 => not positive
        expect(
          result.screeningOutcome,
          isNot(ScreeningOutcome.reviewRecommended),
        );
      },
    );

    test('two moderate photos with avg >= threshold -> screen positive', () {
      final photos = [
        fakePhoto(
          type: PhotoType.frontView,
          riskLevel: RiskLevel.moderate,
          cancerProbability: 0.50,
          opmd: 0.35,
          oca: 0.10,
          benign: 0.30,
          healthy: 0.10,
          quality: 0.90,
        ),
        fakePhoto(
          type: PhotoType.rightCheek,
          riskLevel: RiskLevel.moderate,
          cancerProbability: 0.50,
          opmd: 0.30,
          oca: 0.10,
          benign: 0.30,
          healthy: 0.10,
          quality: 0.88,
        ),
        normalPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      // avg(0.50, 0.50) = 0.50 >= 0.4735 -> screen positive
      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
    });

    test(
      'only 1 usable photo with score < 0.65 -> secondScore = 0, uses score alone',
      () {
        final photos = [
          fakePhoto(
            type: PhotoType.frontView,
            riskLevel: RiskLevel.moderate,
            cancerProbability: 0.50,
            opmd: 0.30,
            oca: 0.10,
            benign: 0.30,
            healthy: 0.20,
            quality: 0.90,
          ),
          unassessablePhoto(PhotoType.rightCheek),
          unassessablePhoto(PhotoType.leftCheek),
          unassessablePhoto(PhotoType.tongue),
          unassessablePhoto(PhotoType.palate),
        ];
        final result = service.aggregateResults(photos);

        // maxScore=0.50, secondScore=0.0 => avg=0.25 < 0.4735
        // maxScore=0.50 < 0.65 => not positive
        // But retake since too few usable photos
        expect(result.screeningOutcome, ScreeningOutcome.retakeSuggested);
      },
    );
  });

  // ===========================================================================
  // V2 flow scenarios
  // ===========================================================================
  group('V2 low risk flow', () {
    test('5 Low-risk benign photos -> lowRisk, routine', () {
      final photos = allPhotoTypes.map(normalPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.lowRisk);
      expect(result.overallRisk, RiskLevel.low);
      expect(result.urgencyLevel, UrgencyLevel.routine);
      expect(result.specialistRequired, false);
      expect(result.overallAssessmentMessage, contains('No concerning signs'));
    });

    test('3 Low-risk photos -> lowRisk, routine', () {
      final photos = [
        normalPhoto(PhotoType.frontView),
        normalPhoto(PhotoType.rightCheek),
        normalPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.lowRisk);
      expect(result.urgencyLevel, UrgencyLevel.routine);
    });

    test('borderline low-risk with p_opmd_plus > 0.35 shows note', () {
      final photos = [
        fakePhoto(
          type: PhotoType.frontView,
          riskLevel: RiskLevel.low,
          cancerProbability: 0.10,
          benign: 0.40,
          healthy: 0.20,
          opmd: 0.25,
          oca: 0.12,
          quality: 0.90,
        ),
        normalPhoto(PhotoType.rightCheek),
        normalPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.lowRisk);
      if (result.aggregatedProbabilities.opmd +
              result.aggregatedProbabilities.oca >
          ScreeningConfig.borderlineMultiClassThreshold) {
        expect(result.overallAssessmentMessage, contains('minor irregular'));
      }
    });
  });

  group('V2 retake suggested flow', () {
    test('all 5 unassessable -> retake, retake message', () {
      final photos = allPhotoTypes.map(unassessablePhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.retakeSuggested);
      expect(result.urgencyLevel, UrgencyLevel.retake);
      expect(result.recommendations.join(' '), contains('retake'));
    });

    test('empty photo list -> retake', () {
      final result = service.aggregateResults([]);
      expect(result.screeningOutcome, ScreeningOutcome.retakeSuggested);
      expect(result.urgencyLevel, UrgencyLevel.retake);
    });
  });

  group('V2 screen positive + subtype guidance', () {
    test('OCA-dominant positive screen -> high risk, urgent', () {
      final photos = allPhotoTypes.map(ocaPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
      expect(result.subtypeGuidance, SubtypeGuidance.ocaDominant);
      expect(result.overallRisk, RiskLevel.high);
      expect(result.urgencyLevel, UrgencyLevel.urgent);
    });

    test('OPMD-dominant positive screen -> moderate risk, prompt', () {
      final photos = allPhotoTypes
          .map(
            (t) => fakePhoto(
              type: t,
              riskLevel: RiskLevel.moderate,
              cancerProbability: 0.55,
              benign: 0.10,
              healthy: 0.05,
              opmd: 0.60,
              oca: 0.10,
              quality: 0.90,
            ),
          )
          .toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
      expect(result.subtypeGuidance, SubtypeGuidance.opmdDominant);
      expect(result.urgencyLevel, UrgencyLevel.prompt);
    });

    test(
      'Benign-dominant positive screen -> suppressed to none (non-concerning label), moderate risk, prompt',
      () {
        final photos = allPhotoTypes
            .map(
              (t) => fakePhoto(
                type: t,
                riskLevel: RiskLevel.high,
                cancerProbability: 0.70,
                benign: 0.50,
                healthy: 0.10,
                opmd: 0.15,
                oca: 0.15,
                quality: 0.90,
              ),
            )
            .toList();
        final result = service.aggregateResults(photos);

        expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
        expect(result.subtypeGuidance, SubtypeGuidance.none);
        expect(result.urgencyLevel, UrgencyLevel.prompt);
      },
    );

    test('screen-negative has SubtypeGuidance.none', () {
      final photos = allPhotoTypes.map(normalPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.subtypeGuidance, SubtypeGuidance.none);
    });
  });

  // ===========================================================================
  // All-suspicious scenarios
  // ===========================================================================
  group('all suspicious photos', () {
    test('5 OPMD photos -> reviewRecommended, specialist required', () {
      final photos = allPhotoTypes.map(opmdPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
      expect(result.specialistRequired, true);
    });

    test('5 OCA photos -> reviewRecommended, urgent', () {
      final photos = allPhotoTypes.map(ocaPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.reviewRecommended);
      expect(result.urgencyLevel, UrgencyLevel.urgent);
    });
  });

  // ===========================================================================
  // photosCaptured parameter
  // ===========================================================================
  group('photosCaptured override', () {
    test('photosCaptured passed correctly', () {
      final photos = allPhotoTypes.map(normalPhoto).toList();
      final result = service.aggregateResults(photos, photosCaptured: 5);

      expect(result.photosCaptured, 5);
      expect(result.photosUsed, greaterThan(0));
    });

    test('defaults to photoResults.length when not provided', () {
      final photos = [
        normalPhoto(PhotoType.frontView),
        normalPhoto(PhotoType.rightCheek),
        normalPhoto(PhotoType.tongue),
      ];
      final result = service.aggregateResults(photos);

      expect(result.photosCaptured, 3);
    });
  });

  // ===========================================================================
  // Recommendation content
  // ===========================================================================
  group('recommendations match risk level', () {
    test('Low risk mentions routine dental checkup', () {
      final photos = allPhotoTypes.map(normalPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(result.recommendations.join(' '), contains('routine'));
    });

    test('High risk mentions urgent specialist', () {
      final photos = allPhotoTypes.map(ocaPhoto).toList();
      final result = service.aggregateResults(photos);

      expect(
        result.recommendations.join(' ').toLowerCase(),
        contains('urgent'),
      );
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================
  group('edge cases', () {
    test('single normal photo -> handles gracefully', () {
      final result = service.aggregateResults([
        normalPhoto(PhotoType.frontView),
      ]);
      expect(result.overallRisk, isNotNull);
    });

    test('mixed valid and invalid photos preserve all in photoResults', () {
      final photos = [
        normalPhoto(PhotoType.frontView),
        unassessablePhoto(PhotoType.rightCheek),
        opmdPhoto(PhotoType.leftCheek),
      ];
      final result = service.aggregateResults(photos);

      expect(result.photoResults.length, 3);
    });

    test('unassessable photos do not influence screening decision', () {
      final photos = [
        normalPhoto(PhotoType.frontView),
        normalPhoto(PhotoType.rightCheek),
        normalPhoto(PhotoType.leftCheek),
        normalPhoto(PhotoType.tongue),
        unassessablePhoto(PhotoType.palate),
      ];
      final result = service.aggregateResults(photos);

      expect(result.screeningOutcome, ScreeningOutcome.lowRisk);
    });
  });

  // ===========================================================================
  // Serialization (V2 format)
  // ===========================================================================
  group('V2 serialization', () {
    test('toJson/fromJson round-trips correctly', () {
      final photos = allPhotoTypes.map(normalPhoto).toList();
      final original = service.aggregateResults(photos);
      final json = original.toJson();
      final restored = ScreeningResult.fromJson(json);

      expect(restored.screeningOutcome, original.screeningOutcome);
      expect(restored.subtypeGuidance, original.subtypeGuidance);
      expect(restored.overallRisk, original.overallRisk);
      expect(restored.urgencyLevel, original.urgencyLevel);
    });

    test('old format (no v:2) throws FormatException', () {
      expect(
        () => ScreeningResult.fromJson({'overallRisk': 'low'}),
        throwsFormatException,
      );
    });
  });
}
