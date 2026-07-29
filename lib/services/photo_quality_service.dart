import 'dart:io' if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/photo_capture.dart';

/// Service for assessing photo quality before model inference
/// 
/// Evaluates brightness, sharpness, and contrast to ensure
/// photos are suitable for accurate AI analysis.
class PhotoQualityService {
  static final PhotoQualityService _instance = PhotoQualityService._internal();
  factory PhotoQualityService() => _instance;
  PhotoQualityService._internal();

  /// Minimum acceptable quality score (0-1)
  static const double minAcceptableQuality = 0.6;

  /// Target brightness range (0-255 scale)
  static const double minBrightness = 80.0;
  static const double maxBrightness = 200.0;

  /// Minimum sharpness (Laplacian variance threshold)
  static const double minSharpness = 100.0;

  /// Minimum contrast (standard deviation threshold)
  static const double minContrast = 50.0;

  /// Assess quality of an image file
  Future<PhotoQualityMetrics> assessQuality(io.File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await compute(_assessQualityFromBytes, bytes);
    } catch (e) {
      debugPrint('❌ [PhotoQualityService] Error assessing quality: $e');
      return PhotoQualityMetrics.empty;
    }
  }

  /// Assess quality from raw bytes (for camera preview frames)
  Future<PhotoQualityMetrics> assessQualityFromBytes(Uint8List bytes) async {
    try {
      return await compute(_assessQualityFromBytes, bytes);
    } catch (e) {
      debugPrint('❌ [PhotoQualityService] Error assessing quality from bytes: $e');
      return PhotoQualityMetrics.empty;
    }
  }

  /// Internal function for quality assessment (runs in isolate)
  static PhotoQualityMetrics _assessQualityFromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return PhotoQualityMetrics.empty;
    }

    // Resize for faster processing (quality assessment doesn't need full resolution)
    final resized = img.copyResize(decoded, width: 224, height: 224);

    // Convert to grayscale for sharpness and contrast calculations
    final grayscale = img.grayscale(resized);

    // Calculate metrics
    final brightnessScore = _calculateBrightnessScore(resized);
    final sharpnessScore = _calculateSharpnessScore(grayscale);
    final contrastScore = _calculateContrastScore(grayscale);

    // Weighted overall score
    // Sharpness is most important (40%), then brightness (30%), then contrast (30%)
    final overallScore = 0.3 * brightnessScore + 0.4 * sharpnessScore + 0.3 * contrastScore;

    return PhotoQualityMetrics(
      brightness: brightnessScore,
      sharpness: sharpnessScore,
      contrast: contrastScore,
      overall: overallScore,
    );
  }

  /// Calculate brightness score (0-1)
  /// Penalizes images that are too dark or too bright
  static double _calculateBrightnessScore(img.Image image) {
    double totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Calculate luminance using standard formula
        final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        totalBrightness += luminance;
        pixelCount++;
      }
    }

    final averageBrightness = totalBrightness / pixelCount;

    // Score based on how close to ideal range (80-200)
    if (averageBrightness < minBrightness) {
      // Too dark - score decreases as it gets darker
      return math.max(0.0, averageBrightness / minBrightness);
    } else if (averageBrightness > maxBrightness) {
      // Too bright - score decreases as it gets brighter
      return math.max(0.0, 1.0 - (averageBrightness - maxBrightness) / (255 - maxBrightness));
    } else {
      // In ideal range
      return 1.0;
    }
  }

  /// Calculate sharpness score using Laplacian variance
  /// Higher variance indicates sharper image
  static double _calculateSharpnessScore(img.Image grayscale) {
    // Laplacian kernel for edge detection
    const kernel = [0, 1, 0, 1, -4, 1, 0, 1, 0];

    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    // Apply Laplacian and calculate variance
    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        double laplacian = 0;

        // Apply 3x3 kernel
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = grayscale.getPixel(x + kx, y + ky);
            final intensity = pixel.r.toDouble(); // Grayscale, so R=G=B
            final kernelIndex = (ky + 1) * 3 + (kx + 1);
            laplacian += intensity * kernel[kernelIndex];
          }
        }

        sum += laplacian;
        sumSquared += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0.0;

    // Calculate variance
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);

    // Normalize variance to 0-1 score
    // Variance of 100+ is considered sharp
    return math.min(1.0, variance / minSharpness);
  }

  /// Calculate contrast score based on standard deviation of pixel intensities
  static double _calculateContrastScore(img.Image grayscale) {
    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        final intensity = pixel.r.toDouble();
        sum += intensity;
        sumSquared += intensity * intensity;
        count++;
      }
    }

    if (count == 0) return 0.0;

    // Calculate standard deviation
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    final stdDev = math.sqrt(variance);

    // Normalize to 0-1 score
    // Standard deviation of 50+ is considered good contrast
    return math.min(1.0, stdDev / minContrast);
  }

  /// Get real-time feedback for camera preview
  /// Returns a map of issue types and feedback messages
  Map<String, String> getFeedback(PhotoQualityMetrics metrics) {
    final feedback = <String, String>{};

    if (metrics.brightness < 0.6) {
      if (metrics.brightness < 0.3) {
        feedback['brightness'] = 'Too dark - find better lighting';
      } else {
        feedback['brightness'] = 'Low light - move closer to light source';
      }
    }

    if (metrics.sharpness < 0.6) {
      if (metrics.sharpness < 0.3) {
        feedback['sharpness'] = 'Very blurry - hold phone steady';
      } else {
        feedback['sharpness'] = 'Slightly blurry - hold still';
      }
    }

    if (metrics.contrast < 0.6) {
      feedback['contrast'] = 'Low contrast - adjust lighting';
    }

    return feedback;
  }

  /// Check if metrics indicate the photo is ready to capture
  bool isReadyToCapture(PhotoQualityMetrics metrics) {
    return metrics.overall >= minAcceptableQuality;
  }
}
