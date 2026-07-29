import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/l10n/app_localizations.dart';
import 'package:oral_cavity_classifier_app/models/photo_capture.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/screens/detailed_results_screen.dart';
import 'package:oral_cavity_classifier_app/screens/results_screen.dart';

ScreeningResult _buildResult({
  required ScreeningOutcome outcome,
  SubtypeGuidance guidance = SubtypeGuidance.none,
  RiskLevel? overallRisk,
  UrgencyLevel? urgency,
  String? title,
  String? message,
}) {
  final effectiveRisk =
      overallRisk ??
      (outcome == ScreeningOutcome.lowRisk
          ? RiskLevel.low
          : (guidance == SubtypeGuidance.ocaDominant
                ? RiskLevel.high
                : RiskLevel.moderate));
  final effectiveUrgency =
      urgency ??
      (outcome == ScreeningOutcome.lowRisk
          ? UrgencyLevel.routine
          : (outcome == ScreeningOutcome.retakeSuggested
                ? UrgencyLevel.retake
                : (guidance == SubtypeGuidance.ocaDominant
                      ? UrgencyLevel.urgent
                      : UrgencyLevel.prompt)));

  const probs = ClassProbabilities(
    healthy: 0.1,
    benign: 0.8,
    opmd: 0.05,
    oca: 0.03,
    unknown: 0.02,
  );
  final photo = PhotoResult(
    photoType: PhotoType.frontView,
    classProbabilities: probs,
    confidence: 0.8,
    qualityScore: 0.9,
    riskLevel: effectiveRisk == RiskLevel.low ? RiskLevel.low : null,
    isValidOralPhoto: true,
    cancerProbability: 0.10,
  );
  return ScreeningResult(
    overallRisk: effectiveRisk,
    overallConfidence: 0.8,
    photoResults: [photo],
    recommendations: const ['No concerning signs detected'],
    specialistRequired: effectiveRisk.specialistRequired,
    urgencyLevel: effectiveUrgency,
    urgencyText: effectiveUrgency.displayText,
    aggregatedProbabilities: probs,
    analyzedAt: DateTime.now(),
    overallAssessmentTitle: title ?? outcome.displayName,
    overallAssessmentMessage:
        message ?? 'No concerning signs detected in these photos.',
    labelConfidence: 0.8,
    screeningOutcome: outcome,
    subtypeGuidance: guidance,
    photosCaptured: 1,
    photosUsed: 1,
  );
}

Widget _wrapWithLocalizations(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  group('DetailedResultsScreen V2 states', () {
    testWidgets('lowRisk shows assessment title and message', (tester) async {
      final result = _buildResult(outcome: ScreeningOutcome.lowRisk);

      await tester.pumpWidget(
        _wrapWithLocalizations(DetailedResultsScreen(result: result)),
      );

      expect(find.text('Low Risk'), findsWidgets);
    });

    testWidgets('retakeSuggested shows amber retake badge', (tester) async {
      final result = _buildResult(
        outcome: ScreeningOutcome.retakeSuggested,
        title: 'Retake Suggested',
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(DetailedResultsScreen(result: result)),
      );

      expect(find.text('Retake Suggested'), findsWidgets);
    });

    testWidgets('reviewRecommended + OCA shows subtype explanation card', (
      tester,
    ) async {
      final result = _buildResult(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.ocaDominant,
        title: SubtypeGuidance.ocaDominant.displayTitle,
        message: SubtypeGuidance.ocaDominant.displayMessage,
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(DetailedResultsScreen(result: result)),
      );

      expect(find.textContaining('Urgent Clinical Review'), findsWidgets);
    });

    testWidgets('lowRisk does NOT show subtype explanation card', (
      tester,
    ) async {
      final result = _buildResult(outcome: ScreeningOutcome.lowRisk);

      await tester.pumpWidget(
        _wrapWithLocalizations(DetailedResultsScreen(result: result)),
      );

      expect(find.textContaining('Urgent Clinical Review'), findsNothing);
      expect(find.textContaining('Specialist Review'), findsNothing);
      expect(find.textContaining('Clinical Evaluation'), findsNothing);
    });

    testWidgets('no disagreement banners rendered', (tester) async {
      final result = _buildResult(outcome: ScreeningOutcome.lowRisk);

      await tester.pumpWidget(
        _wrapWithLocalizations(DetailedResultsScreen(result: result)),
      );

      expect(find.textContaining('checks disagreed'), findsNothing);
      expect(find.textContaining('Type A:'), findsNothing);
      expect(find.textContaining('Type B:'), findsNothing);
      expect(find.textContaining('Type C:'), findsNothing);
    });
  });

  group('ResultsScreen V2 states', () {
    testWidgets('lowRisk header uses green color', (tester) async {
      final result = _buildResult(outcome: ScreeningOutcome.lowRisk);

      await tester.pumpWidget(
        _wrapWithLocalizations(
          ResultsScreen(result: result, onViewDetails: () {}, onDone: () {}),
        ),
      );

      expect(find.text('Low Risk'), findsWidgets);
    });

    testWidgets('retakeSuggested shows amber camera icon', (tester) async {
      final result = _buildResult(
        outcome: ScreeningOutcome.retakeSuggested,
        title: 'Retake Suggested',
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(
          ResultsScreen(result: result, onViewDetails: () {}, onDone: () {}),
        ),
      );

      expect(find.text('Retake Suggested'), findsWidgets);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('reviewRecommended + OCA shows subtype guidance card', (
      tester,
    ) async {
      final result = _buildResult(
        outcome: ScreeningOutcome.reviewRecommended,
        guidance: SubtypeGuidance.ocaDominant,
        title: SubtypeGuidance.ocaDominant.displayTitle,
        message: SubtypeGuidance.ocaDominant.displayMessage,
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(
          ResultsScreen(result: result, onViewDetails: () {}, onDone: () {}),
        ),
      );

      expect(find.textContaining('Urgent Clinical Review'), findsWidgets);
    });
  });
}
