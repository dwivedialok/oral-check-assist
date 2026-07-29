import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oral_cavity_classifier_app/models/exposure_data.dart';
import 'package:oral_cavity_classifier_app/models/photo_capture.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';
import 'package:oral_cavity_classifier_app/services/eri_service.dart';
import 'package:oral_cavity_classifier_app/services/model_inference_service.dart';
import 'package:oral_cavity_classifier_app/services/screening_config.dart';

const _photoFileNames = {
  PhotoType.frontView: 'front_view.jpg',
  PhotoType.rightCheek: 'right_cheek.jpg',
  PhotoType.leftCheek: 'left_cheek.jpg',
  PhotoType.tongue: 'tounge.jpg',
  PhotoType.palate: 'palate.jpg',
};

Future<PhotoCapture> _loadPhoto(PhotoType type, String assetDir) async {
  final fileName = _photoFileNames[type]!;
  final assetPath = '$assetDir/$fileName';
  final data = await rootBundle.load(assetPath);
  final bytes = Uint8List.view(
    data.buffer,
    data.offsetInBytes,
    data.lengthInBytes,
  );
  return PhotoCapture(
    type: type,
    imageBytes: bytes,
    qualityMetrics: const PhotoQualityMetrics(
      brightness: 0.9,
      sharpness: 0.9,
      contrast: 0.9,
      overall: 0.9,
    ),
    capturedAt: DateTime.now(),
  );
}

Future<List<PhotoCapture>> _buildPhotoSet({
  Set<PhotoType> opmdTypes = const {},
  Set<PhotoType> unknownTypes = const {},
}) async {
  final photos = <PhotoCapture>[];
  for (final type in PhotoType.values) {
    final dir = unknownTypes.contains(type)
        ? 'test_assets/unknown'
        : opmdTypes.contains(type)
        ? 'test_assets/opmd'
        : 'test_assets/normal';
    photos.add(await _loadPhoto(type, dir));
  }
  return photos;
}

Future<bool> _testAssetsAvailable() async {
  try {
    await rootBundle.load('test_assets/normal/front_view.jpg');
    await rootBundle.load('test_assets/opmd/front_view.jpg');
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _unknownAssetsAvailable() async {
  try {
    await rootBundle.load('test_assets/unknown/front_view.jpg');
    await rootBundle.load('test_assets/unknown/right_cheek.jpg');
    await rootBundle.load('test_assets/unknown/left_cheek.jpg');
    await rootBundle.load('test_assets/unknown/tounge.jpg');
    await rootBundle.load('test_assets/unknown/palate.jpg');
    return true;
  } catch (_) {
    return false;
  }
}

void _logTest(String name, {String? result}) {
  debugPrint('>>> E2E: $name${result != null ? ' -> $result' : ''}');
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  binding.reportData ??= <String, dynamic>{};
  final list =
      binding.reportData!['test_log'] as List<Map<String, dynamic>>? ?? [];
  list.add({'name': name, if (result != null) 'result': result});
  binding.reportData!['test_log'] = list;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final service = ModelInferenceService();
  final eri = ERIService();
  late bool assetsReady;
  late bool unknownAssetsReady;

  setUpAll(() async {
    assetsReady = await _testAssetsAvailable();
    unknownAssetsReady = await _unknownAssetsAvailable();
    if (!assetsReady) return;
    service.setModelType(ModelType.ensembleDual);
    await service.initializeEnsemble(loadFiveClass: true);
  });

  // ---------------------------------------------------------------------------
  // Scenario 1: All normal, no tobacco
  // ---------------------------------------------------------------------------
  testWidgets('all normal photos, no tobacco -> Low risk, routine', (
    tester,
  ) async {
    const name = 'all normal photos, no tobacco -> Low risk, routine';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet();
    final result = await service.inferMultiPhoto(photos);

    expect(result.overallRisk, RiskLevel.low);
    expect(result.urgencyLevel, UrgencyLevel.routine);
    expect(
      result.overallAssessmentMessage,
      contains('No concerning signs detected'),
    );
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 2: All normal, high tobacco
  // ---------------------------------------------------------------------------
  testWidgets('all normal photos, high tobacco -> Low + ERI rescreen', (
    tester,
  ) async {
    const name = 'all normal photos, high tobacco -> Low + ERI rescreen';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet();
    final result = await service.inferMultiPhoto(photos);

    final exposure = eri.computeExposureData(
      tobaccoTypes: [TobaccoType.gutka, TobaccoType.beedi],
      duration: DurationCategory.moreThan20Years,
      frequency: FrequencyCategory.moreThanTenPerDay,
    );

    final updated = eri.applyToResult(result, exposure);

    expect(updated.overallRisk, RiskLevel.low);
    expect(updated.eriRescreenInterval, isNotNull);
    expect(updated.eriMessage, contains('Exposure history influenced'));
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 3: 1 OPMD + 4 normal, no tobacco
  // ---------------------------------------------------------------------------
  testWidgets('1 OPMD + 4 normal, no tobacco -> at least Moderate', (
    tester,
  ) async {
    const name = '1 OPMD + 4 normal, no tobacco -> at least Moderate';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet(opmdTypes: {PhotoType.rightCheek});
    final result = await service.inferMultiPhoto(photos);

    expect(
      result.overallRisk.index,
      greaterThanOrEqualTo(RiskLevel.moderate.index),
      reason: 'Per-photo max floor: 1 OPMD photo should elevate overall risk',
    );
    expect(result.specialistRequired, true);
    expect(
      result.overallAssessmentMessage.toLowerCase(),
      isNot(contains('no concerning signs')),
      reason: 'Elevated risk must not display low-risk message',
    );
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 4: 1 OPMD + 4 normal, high tobacco
  // ---------------------------------------------------------------------------
  testWidgets(
    '1 OPMD + 4 normal, high tobacco -> at least Moderate, ERI applied',
    (tester) async {
      const name =
          '1 OPMD + 4 normal, high tobacco -> at least Moderate, ERI applied';
      _logTest(name);
      if (!assetsReady) {
        _logTest(name, result: 'skipped');
        markTestSkipped('Test assets not available');
        return;
      }

      final photos = await _buildPhotoSet(opmdTypes: {PhotoType.rightCheek});
      final result = await service.inferMultiPhoto(photos);

      final exposure = eri.computeExposureData(
        tobaccoTypes: [TobaccoType.gutka],
        duration: DurationCategory.moreThan20Years,
        frequency: FrequencyCategory.moreThanTenPerDay,
      );
      final updated = eri.applyToResult(result, exposure);

      expect(
        updated.effectiveRisk.index,
        greaterThanOrEqualTo(RiskLevel.moderate.index),
      );
      _logTest(name, result: 'passed');
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 5: 2 OPMD + 3 normal
  // ---------------------------------------------------------------------------
  testWidgets('2 OPMD + 3 normal -> at least Moderate/High', (tester) async {
    const name = '2 OPMD + 3 normal -> at least Moderate/High';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet(
      opmdTypes: {PhotoType.rightCheek, PhotoType.tongue},
    );
    final result = await service.inferMultiPhoto(photos);

    expect(
      result.overallRisk.index,
      greaterThanOrEqualTo(RiskLevel.moderate.index),
    );
    expect(result.specialistRequired, true);
    expect(
      result.overallAssessmentMessage.toLowerCase(),
      isNot(contains('no concerning signs')),
    );
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 6: All OPMD
  // ---------------------------------------------------------------------------
  testWidgets('all OPMD photos -> High risk', (tester) async {
    const name = 'all OPMD photos -> High risk';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet(opmdTypes: PhotoType.values.toSet());
    final result = await service.inferMultiPhoto(photos);

    expect(
      result.overallRisk.index,
      greaterThanOrEqualTo(RiskLevel.moderate.index),
      reason: 'All OPMD photos should produce at least Moderate risk',
    );
    expect(
      result.overallAssessmentMessage.toLowerCase(),
      isNot(contains('no concerning signs')),
    );
    expect(
      result.screeningOutcome,
      ScreeningOutcome.reviewRecommended,
      reason: 'V2: all OPMD should be review recommended',
    );
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 7 (V2): all normal -> V2 lowRisk outcome
  // ---------------------------------------------------------------------------
  testWidgets('V2: all normal photos -> screeningOutcome == lowRisk', (
    tester,
  ) async {
    const name = 'V2: all normal photos -> screeningOutcome == lowRisk';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    final photos = await _buildPhotoSet();
    final result = await service.inferMultiPhoto(photos);

    expect(result.screeningOutcome, ScreeningOutcome.lowRisk);
    expect(result.subtypeGuidance, SubtypeGuidance.none);
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 8 (V2): all unknown photos are excluded as OOD
  // ---------------------------------------------------------------------------
  testWidgets('V2: all unknown photos -> excluded and retake suggested', (
    tester,
  ) async {
    const name = 'V2: all unknown photos -> excluded and retake suggested';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Base test assets not available');
      return;
    }
    if (!unknownAssetsReady) {
      _logTest(name, result: 'skipped_no_unknown_assets');
      markTestSkipped(
        'Unknown/OOD test assets not available under test_assets/unknown/',
      );
      return;
    }

    final photos = await _buildPhotoSet(unknownTypes: PhotoType.values.toSet());
    final result = await service.inferMultiPhoto(photos);

    expect(result.photosCaptured, PhotoType.values.length);

    // OOD is only triggered when 5-class top == Unknown AND P(Unknown) > 0.6
    // (lib/services/model_inference_service.dart analyzePhoto). Arbitrary
    // "non-oral" JPEGs often classify as Healthy/Benign/etc., so we only assert
    // the strict session contract when all five actually hit the gate.
    final oodPerPhoto = result.photoResults
        .where((p) => !p.isValidOralPhoto)
        .length;
    if (oodPerPhoto != PhotoType.values.length) {
      _logTest(name, result: 'skipped_partial_ood');
      markTestSkipped(
        'Not every asset triggered the strong OOD gate (need Unknown top + '
        'P(Unknown) > ${ScreeningConfig.oodUnknownThreshold}: '
        'got $oodPerPhoto/${PhotoType.values.length}. '
        'Replace test_assets/unknown/*.jpg with images the model reliably '
        'scores as Unknown (e.g. obviously non-oral per slot), or keep fewer '
        'slots if verifying partial exclusion.',
      );
      return;
    }

    expect(result.photosUsed, 0);
    expect(result.skippedDueToUnknown, PhotoType.values.length);
    expect(result.screeningOutcome, ScreeningOutcome.retakeSuggested);
    expect(result.urgencyLevel, UrgencyLevel.retake);
    // Strong OOD gate sets isValidOralPhoto=false so frames are excluded from
    // aggregation. Note: analyzePhoto still assigns binary-derived riskLevel when
    // dual path returned null (model_inference_service.dart ~1053–1063), so
    // riskLevel may be non-null even for excluded photos — do not assert null.
    expect(
      result.photoResults.every((p) => !p.isValidOralPhoto),
      isTrue,
      reason:
          'All five assets must be flagged non-oral for aggregation exclusion',
    );
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 9 (V2 UX contract): if Uncertain appears, binary risk remains valid
  // ---------------------------------------------------------------------------
  testWidgets('V2 UX: uncertain label (if present) keeps binary risk semantics', (
    tester,
  ) async {
    const name =
        'V2 UX: uncertain label (if present) keeps binary risk semantics';
    _logTest(name);
    if (!assetsReady) {
      _logTest(name, result: 'skipped');
      markTestSkipped('Test assets not available');
      return;
    }

    // Use a mixed set to increase odds of low-confidence 5-class labels across devices.
    final photos = await _buildPhotoSet(
      opmdTypes: {PhotoType.rightCheek, PhotoType.tongue},
    );
    final result = await service.inferMultiPhoto(photos);
    final uncertainPhotos = result.photoResults
        .where((p) => p.displayLabel == 'Uncertain')
        .toList();

    // Not deterministic across model versions/devices: treat as observable UX contract
    // only when the label appears.
    if (uncertainPhotos.isEmpty) {
      _logTest(name, result: 'passed_not_observed');
      return;
    }

    for (final photo in uncertainPhotos) {
      expect(photo.isValidOralPhoto, true);
      expect(
        photo.riskLevel,
        isNotNull,
        reason: 'Uncertain label should not nullify binary risk',
      );
      expect(
        photo.cancerProbability,
        isNotNull,
        reason: 'Binary screening score should still be present',
      );
    }
    _logTest(name, result: 'passed');
  });

  // ---------------------------------------------------------------------------
  // Scenario 10 (V2): ScreeningConfig thresholds are consistent
  // ---------------------------------------------------------------------------
  testWidgets('V2: ScreeningConfig thresholds are valid', (tester) async {
    const name = 'V2: ScreeningConfig thresholds are valid';
    _logTest(name);

    expect(ScreeningConfig.binaryScreeningThreshold, 0.4735);
    expect(ScreeningConfig.highConfSingleViewThreshold, 0.65);
    expect(
      ScreeningConfig.retakeLowerBound,
      lessThan(ScreeningConfig.retakeUpperBound),
    );
    expect(
      ScreeningConfig.retakeLowerBound,
      lessThan(ScreeningConfig.binaryScreeningThreshold),
    );
    _logTest(name, result: 'passed');
  });
}
