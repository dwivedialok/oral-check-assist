import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_cavity_classifier_app/models/photo_capture.dart';
import 'package:oral_cavity_classifier_app/models/screening_session.dart';
import 'package:oral_cavity_classifier_app/services/screening_config.dart';

void main() {
  final dummyFile = File('placeholder');

  const good = PhotoQualityMetrics(
    brightness: 0.8,
    sharpness: 0.8,
    contrast: 0.8,
    overall: 0.8,
  );

  group('ScreeningSession review / analyze gates', () {
    test('readyToAnalyze is false with only one acceptable photo', () {
      var s = ScreeningSession.create();
      s = s.updatePhoto(PhotoCapture(
        type: PhotoType.frontView,
        image: dummyFile,
        qualityMetrics: good,
      ));
      expect(s.readyToAnalyze, false);
      expect(s.needsMoreAcceptablePhotosForAnalysis, true);
      expect(s.acceptableCount, 1);
      expect(ScreeningConfig.minUsedPhotos, 2);
    });

    test('readyToAnalyze is true with two acceptable photos', () {
      var s = ScreeningSession.create();
      s = s.updatePhoto(PhotoCapture(
        type: PhotoType.frontView,
        image: dummyFile,
        qualityMetrics: good,
      ));
      s = s.updatePhoto(PhotoCapture(
        type: PhotoType.rightCheek,
        image: dummyFile,
        qualityMetrics: good,
      ));
      expect(s.readyToAnalyze, true);
      expect(s.needsMoreAcceptablePhotosForAnalysis, false);
    });

    test('allFiveSlotsFilledAndAcceptable requires five acceptable captures', () {
      var s = ScreeningSession.create();
      for (final t in PhotoType.values) {
        s = s.updatePhoto(PhotoCapture(
          type: t,
          image: dummyFile,
          qualityMetrics: good,
        ));
      }
      expect(s.allFiveSlotsFilledAndAcceptable, true);
      expect(s.allAcceptable, true);
    });

    test('allCapturedPhotosAcceptable true when partial capture all good', () {
      var s = ScreeningSession.create();
      s = s.updatePhoto(PhotoCapture(
        type: PhotoType.frontView,
        image: dummyFile,
        qualityMetrics: good,
      ));
      s = s.updatePhoto(PhotoCapture(
        type: PhotoType.rightCheek,
        image: dummyFile,
        qualityMetrics: good,
      ));
      expect(s.allCapturedPhotosAcceptable, true);
      expect(s.allFiveSlotsFilledAndAcceptable, false);
    });
  });
}
