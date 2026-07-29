import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_capture.dart';
import '../models/screening_result.dart';

/// Data model for storing screening history
class ScreeningHistoryItem {
  final String id;
  final DateTime date;
  final String riskLevel;
  final double confidence;
  final int photosAnalyzed;
  final Map<String, dynamic>? aggregatedProbabilities;
  final List<String> recommendations;
  /// Full result JSON for detail view (ScreeningResult.toJson() encoded).
  final String? resultJson;
  /// Photo type name -> absolute path for images persisted for this screening.
  final Map<String, String>? savedPhotoPaths;

  ScreeningHistoryItem({
    required this.id,
    required this.date,
    required this.riskLevel,
    required this.confidence,
    required this.photosAnalyzed,
    this.aggregatedProbabilities,
    required this.recommendations,
    this.resultJson,
    this.savedPhotoPaths,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'riskLevel': riskLevel,
        'confidence': confidence,
        'photosAnalyzed': photosAnalyzed,
        'aggregatedProbabilities': aggregatedProbabilities,
        'recommendations': recommendations,
        'resultJson': resultJson,
        'savedPhotoPaths': savedPhotoPaths,
      };

  factory ScreeningHistoryItem.fromJson(Map<String, dynamic> json) {
    final paths = json['savedPhotoPaths'];
    return ScreeningHistoryItem(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      riskLevel: json['riskLevel'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      photosAnalyzed: json['photosAnalyzed'] as int,
      aggregatedProbabilities: json['aggregatedProbabilities'] as Map<String, dynamic>?,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      resultJson: json['resultJson'] as String?,
      savedPhotoPaths: paths != null
          ? Map<String, String>.from(paths as Map)
          : null,
    );
  }

  factory ScreeningHistoryItem.fromResult(
    ScreeningResult result, {
    String? id,
    Map<String, String>? savedPhotoPaths,
  }) {
    return ScreeningHistoryItem(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: result.analyzedAt,
      // Match detail screen / Risk Summary "Final Recommendation" (ERI may elevate above AI-only risk).
      riskLevel: result.effectiveRisk.name,
      confidence: result.overallConfidence,
      photosAnalyzed: result.analyzedPhotoCount,
      aggregatedProbabilities: result.aggregatedProbabilities.toJson(),
      recommendations: result.recommendations,
      resultJson: jsonEncode(result.toJson()),
      savedPhotoPaths: savedPhotoPaths,
    );
  }

  /// Risk badge for history lists: final recommendation when full [resultJson] exists.
  RiskLevel get resolvedRiskLevel {
    final decoded = decodedResult;
    if (decoded != null) return decoded.effectiveRisk;
    return RiskLevel.values.firstWhere(
      (r) => r.name == riskLevel,
      orElse: () => RiskLevel.low,
    );
  }

  /// Decode stored result to [ScreeningResult], or null if not stored.
  ScreeningResult? get decodedResult {
    if (resultJson == null || resultJson!.isEmpty) return null;
    try {
      return ScreeningResult.fromJson(
        jsonDecode(resultJson!) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Service for managing screening history with Hive
class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const String _boxName = 'screening_history';
  static const String _photosSubdir = 'screening_history_photos';
  Box<String>? _box;
  bool _initialized = false;

  /// Initialize Hive storage
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
      _initialized = true;
      debugPrint('✅ [HistoryService] Initialized');
    } catch (e) {
      debugPrint('❌ [HistoryService] Initialization failed: $e');
    }
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Directory for persisted photos for a given screening id.
  Future<Directory> _photosDirFor(String screeningId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_photosSubdir/$screeningId');
  }

  /// Delete persisted photo directory for a screening id.
  Future<void> _deletePhotosFor(String screeningId) async {
    try {
      final dir = await _photosDirFor(screeningId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('🗑️ [HistoryService] Deleted photos dir: ${dir.path}');
      }
    } catch (e) {
      debugPrint('⚠️ [HistoryService] Failed to delete photos dir: $e');
    }
  }

  /// Save a screening result to history. Optionally copies session photos to app storage.
  Future<void> saveScreening(ScreeningResult result, [List<PhotoCapture>? photos]) async {
    await _ensureInitialized();
    if (_box == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, String>? savedPhotoPaths;

    if (photos != null && photos.isNotEmpty) {
      try {
        final dir = await _photosDirFor(id);
        await dir.create(recursive: true);
        savedPhotoPaths = {};
        for (final capture in photos) {
          if (capture.image != null) {
            final file = capture.image!;
            final name = '${capture.type.name}.jpg';
            final dest = File('${dir.path}/$name');
            await file.copy(dest.path);
            savedPhotoPaths[capture.type.name] = dest.path;
            debugPrint('✅ [HistoryService] Copied photo: $name');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [HistoryService] Failed to copy photos: $e');
      }
    }

    try {
      final item = ScreeningHistoryItem.fromResult(result, id: id, savedPhotoPaths: savedPhotoPaths);
      final jsonStr = jsonEncode(item.toJson());
      await _box!.put(item.id, jsonStr);
      debugPrint('✅ [HistoryService] Saved screening: ${item.id}');
    } catch (e) {
      debugPrint('❌ [HistoryService] Failed to save screening: $e');
      if (savedPhotoPaths != null) await _deletePhotosFor(id);
    }
  }

  /// Get all screenings, sorted by date (newest first)
  Future<List<ScreeningHistoryItem>> getScreenings() async {
    await _ensureInitialized();
    if (_box == null) return [];

    try {
      final items = <ScreeningHistoryItem>[];
      
      for (final key in _box!.keys) {
        final jsonStr = _box!.get(key);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          items.add(ScreeningHistoryItem.fromJson(json));
        }
      }

      // Sort by date, newest first
      items.sort((a, b) => b.date.compareTo(a.date));
      
      debugPrint('📊 [HistoryService] Loaded ${items.length} screenings');
      return items;
    } catch (e) {
      debugPrint('❌ [HistoryService] Failed to load screenings: $e');
      return [];
    }
  }

  /// Get a specific screening by ID
  Future<ScreeningHistoryItem?> getScreening(String id) async {
    await _ensureInitialized();
    if (_box == null) return null;

    try {
      final jsonStr = _box!.get(id);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ScreeningHistoryItem.fromJson(json);
    } catch (e) {
      debugPrint('❌ [HistoryService] Failed to get screening: $e');
      return null;
    }
  }

  /// Delete a specific screening and its persisted photos.
  Future<void> deleteScreening(String id) async {
    await _ensureInitialized();
    if (_box == null) return;

    try {
      await _deletePhotosFor(id);
      await _box!.delete(id);
      debugPrint('🗑️ [HistoryService] Deleted screening: $id');
    } catch (e) {
      debugPrint('❌ [HistoryService] Failed to delete screening: $e');
    }
  }

  /// Clear all history and delete all persisted photo directories.
  Future<void> clearHistory() async {
    await _ensureInitialized();
    if (_box == null) return;

    try {
      for (final key in _box!.keys) {
        await _deletePhotosFor(key.toString());
      }
      await _box!.clear();
      debugPrint('🗑️ [HistoryService] Cleared all history');
    } catch (e) {
      debugPrint('❌ [HistoryService] Failed to clear history: $e');
    }
  }

  /// Get screening count
  Future<int> getScreeningCount() async {
    await _ensureInitialized();
    return _box?.length ?? 0;
  }

  /// Close the Hive box
  Future<void> close() async {
    await _box?.close();
    _initialized = false;
  }
}
