import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/services/model_inference_service.dart';

void main() {
  final service = ModelInferenceService();

  group('V2 assessment message generation', () {
    test('lowRisk outcome produces Low Risk title', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.lowRisk,
        guidance: SubtypeGuidance.none,
        photosUsed: 3,
        photosCaptured: 5,
      );
      expect(msg.title, 'Low Risk');
      expect(msg.message, contains('No concerning signs'));
    });

    test('lowRisk with borderline p_opmd_plus adds minor pattern note', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.lowRisk,
        guidance: SubtypeGuidance.none,
        photosUsed: 3,
        photosCaptured: 5,
        borderlineOpmdPlus: 0.40,
      );
      expect(msg.message, contains('minor irregular patterns'));
    });

    test('lowRisk with p_opmd_plus below threshold has no note', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.lowRisk,
        guidance: SubtypeGuidance.none,
        photosUsed: 3,
        photosCaptured: 5,
        borderlineOpmdPlus: 0.20,
      );
      expect(msg.message, isNot(contains('minor irregular patterns')));
    });

    test('retakeSuggested produces Retake Suggested title', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.retakeSuggested,
        guidance: SubtypeGuidance.none,
        photosUsed: 1,
        photosCaptured: 3,
      );
      expect(msg.title, 'Retake Suggested');
      expect(msg.message, contains('decision boundary'));
    });

    test('reviewRecommended + OCA dominant', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.ocaDominant,
        photosUsed: 3,
        photosCaptured: 5,
      );
      expect(msg.title, contains('Urgent Clinical Review'));
      expect(msg.message, contains('serious changes'));
    });

    test('reviewRecommended + OPMD dominant', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.opmdDominant,
        photosUsed: 3,
        photosCaptured: 5,
      );
      expect(msg.title, contains('Specialist Review'));
      expect(msg.message, contains('Early changes'));
    });

    test('reviewRecommended + benign dominant', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.benignDominant,
        photosUsed: 3,
        photosCaptured: 5,
      );
      expect(msg.title, contains('Clinical Evaluation'));
      expect(msg.message, contains('non-threatening'));
    });

    test('reviewRecommended + none guidance falls back to generic', () {
      final msg = service.buildV2AssessmentMessage(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.none,
        photosUsed: 3,
        photosCaptured: 5,
      );
      expect(msg.title, 'Review Recommended');
      expect(msg.message, contains('professional review'));
    });
  });

  group('V2 subtype guidance derivation', () {
    test('OCA dominant when oca >= subtypeConfidenceThreshold', () {
      const probs = ClassProbabilities(
        healthy: 0.05,
        benign: 0.10,
        opmd: 0.15,
        oca: 0.60,
        unknown: 0.10,
      );
      expect(service.deriveSubtypeGuidance(probs), SubtypeGuidance.ocaDominant);
    });

    test('OPMD dominant when opmd is highest above threshold', () {
      const probs = ClassProbabilities(
        healthy: 0.05,
        benign: 0.10,
        opmd: 0.55,
        oca: 0.20,
        unknown: 0.10,
      );
      expect(
        service.deriveSubtypeGuidance(probs),
        SubtypeGuidance.opmdDominant,
      );
    });

    test('benign dominant', () {
      const probs = ClassProbabilities(
        healthy: 0.10,
        benign: 0.50,
        opmd: 0.20,
        oca: 0.10,
        unknown: 0.10,
      );
      expect(
        service.deriveSubtypeGuidance(probs),
        SubtypeGuidance.benignDominant,
      );
    });

    test('none when all subtypes below threshold', () {
      const probs = ClassProbabilities(
        healthy: 0.40,
        benign: 0.30,
        opmd: 0.15,
        oca: 0.10,
        unknown: 0.05,
      );
      expect(service.deriveSubtypeGuidance(probs), SubtypeGuidance.none);
    });
  });

  group('V2 outcome to risk/urgency mapping', () {
    test('lowRisk -> RiskLevel.low, routine', () {
      expect(
        service.outcomeToRiskLevel(
          ScreeningOutcome.lowRisk,
          SubtypeGuidance.none,
        ),
        RiskLevel.low,
      );
      expect(
        service.outcomeToUrgency(
          ScreeningOutcome.lowRisk,
          SubtypeGuidance.none,
        ),
        UrgencyLevel.routine,
      );
    });

    test('retakeSuggested -> RiskLevel.moderate, retake', () {
      expect(
        service.outcomeToRiskLevel(
          ScreeningOutcome.retakeSuggested,
          SubtypeGuidance.none,
        ),
        RiskLevel.moderate,
      );
      expect(
        service.outcomeToUrgency(
          ScreeningOutcome.retakeSuggested,
          SubtypeGuidance.none,
        ),
        UrgencyLevel.retake,
      );
    });

    test('reviewRecommended + OCA -> high, urgent', () {
      expect(
        service.outcomeToRiskLevel(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.ocaDominant,
        ),
        RiskLevel.high,
      );
      expect(
        service.outcomeToUrgency(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.ocaDominant,
        ),
        UrgencyLevel.urgent,
      );
    });

    test('reviewRecommended + OPMD -> moderate, prompt', () {
      expect(
        service.outcomeToRiskLevel(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.opmdDominant,
        ),
        RiskLevel.moderate,
      );
      expect(
        service.outcomeToUrgency(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.opmdDominant,
        ),
        UrgencyLevel.prompt,
      );
    });

    test('reviewRecommended + benign -> moderate, prompt', () {
      expect(
        service.outcomeToRiskLevel(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.benignDominant,
        ),
        RiskLevel.moderate,
      );
      expect(
        service.outcomeToUrgency(
          ScreeningOutcome.reviewRecommended,
          SubtypeGuidance.benignDominant,
        ),
        UrgencyLevel.prompt,
      );
    });
  });
}
