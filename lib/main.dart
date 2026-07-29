import 'dart:io' if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart' as io;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_extensions.dart';
import 'models/photo_capture.dart';
import 'models/screening_result.dart';
import 'services/model_inference_service.dart';
import 'services/screening_config.dart';
import 'services/history_service.dart';
import 'services/app_build_info.dart';
import 'providers/screening_provider.dart';
import 'screens/home_screen.dart';
import 'screens/detailed_results_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/risk_badge.dart';
import 'services/web_update_probe_stub.dart'
    if (dart.library.html) 'services/web_update_probe_web.dart' as webUpdateProbe;
import 'web_plugin_registration_stub.dart'
    if (dart.library.js_interop) 'web_plugin_registration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureWebPackageInfoPluginRegistered();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  runApp(const MyApp());
}

const String _localeKey = 'locale';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code != null && code.isNotEmpty) {
      setState(() => _locale = Locale(code));
    }
  }

  void setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScreeningProvider()),
      ],
      child: MaterialApp(
        title: 'Oral Cavity Check',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _locale,
        localeResolutionCallback: (locale, supported) {
          for (final supportedLocale in supported) {
            if (supportedLocale.languageCode == locale?.languageCode) {
              return supportedLocale;
            }
          }
          return supported.first;
        },
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: AppInitializer(onLocaleChanged: setLocale),
      ),
    );
  }
}

/// Initializes the app and decides whether to show onboarding or home screen
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key, this.onLocaleChanged});

  final void Function(Locale locale)? onLocaleChanged;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _showOnboarding = false;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if onboarding is complete
      final onboardingComplete = await isOnboardingComplete();
      
      // Initialize models
      final inferenceService = ModelInferenceService();
      
      // Load labels
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      await inferenceService.loadLabels(labelsData);

      // Lazy loading: load binary models first (~36 MB), 5-class load on first screening
      await inferenceService.initializeEnsemble(loadFiveClass: false);
      // Prefer dual ensemble (binary + 5-class); 5-class will load on first inference
      if (inferenceService.dualEnsembleReady) {
        inferenceService.setModelType(ModelType.ensembleDual);
      } else if (inferenceService.binaryEnsembleReady) {
        inferenceService.setModelType(ModelType.ensembleDual);
      } else {
        inferenceService.setModelType(ModelType.ensemble);
      }

      // Initialize history service
      await HistoryService().initialize();

      setState(() {
        _isLoading = false;
        _showOnboarding = !onboardingComplete;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.appTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.loadingModels),
            ],
          ),
        ),
      );
    }

    if (_loadingError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.failedToInitialize,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadingError = null;
                    });
                    _initializeApp();
                  },
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingFlow(
        onLocaleChanged: widget.onLocaleChanged,
        onComplete: () {
          setState(() => _showOnboarding = false);
        },
      );
    }

    return MainNavigator(onLocaleChanged: widget.onLocaleChanged);
  }
}

/// Main navigator with bottom navigation
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key, this.onLocaleChanged});

  final void Function(Locale locale)? onLocaleChanged;

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _versionPollTimer;
  String? _installedVersionToken;
  String? _latestVersionToken;
  bool _updateReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startWebUpdateMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _versionPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForWebUpdate();
    }
  }

  Future<void> _startWebUpdateMonitoring() async {
    if (!kIsWeb) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersionToken = runningVersionToken(
        packageVersion: info.version,
        packageBuildNumber: info.buildNumber,
      );
      if (kEmbeddedAppVersionToken.trim().isEmpty) {
        debugPrint(
          '⚠️ [WebUpdate] APP_VERSION_TOKEN is not embedded. '
          'Web update checks may miss cached old bundles.',
        );
      }
    } catch (_) {
      _installedVersionToken = null;
    }

    await _checkForWebUpdate();
    _versionPollTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _checkForWebUpdate();
    });
  }

  Future<void> _checkForWebUpdate() async {
    if (!mounted || !kIsWeb || _updateReady) return;
    final installed = _installedVersionToken;
    if (installed == null || installed.isEmpty) return;

    final latest = await webUpdateProbe.fetchWebVersionToken();
    if (!mounted || latest == null || latest.isEmpty) return;
    if (latest == installed) return;

    setState(() {
      _latestVersionToken = latest;
      _updateReady = true;
    });
  }

  Future<void> _applyUpdateNow() async {
    if (!kIsWeb) return;
    await webUpdateProbe.reloadWebPage();
  }

  Widget _buildUpdateBanner({required bool isScreeningInProgress}) {
    final details = _latestVersionToken == null ? '' : ' (new: $_latestVersionToken)';
    final message = isScreeningInProgress
        ? 'A new app update is ready$details. Finish the current screening before applying.'
        : 'A new app update is ready$details. Apply now to use the latest improvements.';

    return MaterialBanner(
      content: Text(message),
      leading: const Icon(Icons.system_update_alt),
      backgroundColor: Colors.amber.shade50,
      actions: [
        TextButton(
          onPressed: () => setState(() => _updateReady = false),
          child: const Text('Later'),
        ),
        if (!isScreeningInProgress)
          FilledButton(
            onPressed: _applyUpdateNow,
            child: const Text('Apply update'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningProvider = context.watch<ScreeningProvider>();
    final isScreeningInProgress =
        screeningProvider.isAnalyzing ||
        screeningProvider.isLoadingModels ||
        (screeningProvider.hasActiveSession && !screeningProvider.isCompleted);

    return Scaffold(
      body: Column(
        children: [
          if (_updateReady)
            _buildUpdateBanner(isScreeningInProgress: isScreeningInProgress),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomeScreen(onLocaleChanged: widget.onLocaleChanged),
                QuickCheckScreen(onLocaleChanged: widget.onLocaleChanged),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt),
            label: AppLocalizations.of(context)!.navQuickCheck,
          ),
        ],
      ),
    );
  }
}

/// Quick check: single-image flow (pick → Analyze → result → Explain result).
class QuickCheckScreen extends StatefulWidget {
  const QuickCheckScreen({super.key, this.onLocaleChanged});

  final void Function(Locale locale)? onLocaleChanged;

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends State<QuickCheckScreen> {
  final ModelInferenceService _inferenceService = ModelInferenceService();
  io.File? _image;
  Uint8List? _imageBytes; // Web: original bytes for inference
  Uint8List? _displayImageBytes; // Web: resized bytes for display (prevents WebGL errors)
  Map<String, dynamic>? _lastInferResult;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _isLoadingModels = false;

  bool get _hasImage => kIsWeb ? (_displayImageBytes != null && _displayImageBytes!.isNotEmpty) : (_image != null);

  Future<void> _pickImage(ImageSource source) async {
    debugPrint('📷 [QuickCheck] Picking image from ${source == ImageSource.camera ? "camera" : "gallery"}');
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: kIsWeb ? 1920 : null, // Limit size on web to prevent WebGL issues
    );
    if (pickedFile != null) {
      debugPrint('📷 [QuickCheck] Image picked: ${pickedFile.path}');
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        debugPrint('📷 [QuickCheck] Read ${bytes.length} bytes');
        
        // Validate bytes on web
        if (bytes.isEmpty || bytes.length < 100) {
          debugPrint('❌ [QuickCheck] Invalid image bytes: ${bytes.length} bytes');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load image: Invalid image data')),
            );
          }
          return;
        }
        
        // Resize image for display to prevent WebGL errors (max 1920px on longest side)
        Uint8List? displayBytes;
        try {
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            debugPrint('📷 [QuickCheck] Decoded image: ${decoded.width}x${decoded.height}');
            // Resize if too large (WebGL has texture size limits)
            img.Image? resized = decoded;
            const maxDisplaySize = 1920;
            if (decoded.width > maxDisplaySize || decoded.height > maxDisplaySize) {
              final ratio = decoded.width > decoded.height 
                  ? maxDisplaySize / decoded.width 
                  : maxDisplaySize / decoded.height;
              resized = img.copyResize(
                decoded,
                width: (decoded.width * ratio).round(),
                height: (decoded.height * ratio).round(),
              );
              debugPrint('📷 [QuickCheck] Resized for display: ${resized.width}x${resized.height}');
            }
            displayBytes = Uint8List.fromList(img.encodePng(resized));
            debugPrint('📷 [QuickCheck] Display bytes: ${displayBytes.length} bytes');
          }
        } catch (e) {
          debugPrint('❌ [QuickCheck] Failed to resize image for display: $e');
          // Fallback to original bytes
          displayBytes = bytes;
        }
        
        setState(() {
          _imageBytes = bytes; // Keep original for inference
          _displayImageBytes = displayBytes ?? bytes; // Use resized for display
          _image = null;
          _lastInferResult = null;
        });
        debugPrint('📷 [QuickCheck] Image set - has bytes: ${_imageBytes != null && _imageBytes!.isNotEmpty}, has display: ${_displayImageBytes != null && _displayImageBytes!.isNotEmpty}');
      } else {
        setState(() {
          _image = io.File(pickedFile.path);
          _imageBytes = null;
          _lastInferResult = null;
        });
      }
    } else {
      debugPrint('📷 [QuickCheck] No image picked (user cancelled)');
    }
  }

  Future<void> _runAnalyze() async {
    if (!_hasImage) return;
    // Lazy load 5-class models on first use; show "Loading detailed models…"
    if (!_inferenceService.isFiveClassModelsLoaded) {
      setState(() => _isLoadingModels = true);
      await _inferenceService.ensureFiveClassModelsLoaded();
      if (!mounted) return;
      setState(() => _isLoadingModels = false);
    }
    setState(() => _isAnalyzing = true);
    if (_inferenceService.dualEnsembleReady) {
      _inferenceService.setModelType(ModelType.ensembleDual);
    }
    Map<String, dynamic>? res;
    if (kIsWeb && _imageBytes != null) {
      res = await _inferenceService.inferFromBytes(_imageBytes!);
    } else if (_image != null) {
      res = await _inferenceService.infer(_image!);
    }
    if (!mounted) return;
    setState(() {
      _lastInferResult = res;
      _isAnalyzing = false;
    });
  }

  PhotoResult _photoResultFromInfer(Map<String, dynamic> result) {
    ClassProbabilities? classProbs = result['classProbs'] as ClassProbabilities?;
    if (classProbs == null && result['probabilitiesList'] != null) {
      classProbs = ClassProbabilities.fromList(result['probabilitiesList'] as List<double>);
    }
    if (classProbs == null && result['probabilities'] != null) {
      final pm = result['probabilities'] as Map<String, double>;
      classProbs = ClassProbabilities(
        benign: pm['Benign'] ?? 0.0,
        healthy: pm['Healthy'] ?? 0.0,
        oca: pm['OCA'] ?? 0.0,
        opmd: pm['OPMD'] ?? 0.0,
        unknown: pm['Unknown'] ?? 0.0,
      );
    }
    RiskLevel? riskLevel = result['riskLevel'] as RiskLevel?;
    if (riskLevel == null && result['label'] != null) {
      final label = result['label'] as String;
      if (label == 'OCA') {
        riskLevel = RiskLevel.high;
      } else if (label == 'OPMD') {
        riskLevel = RiskLevel.moderate;
      } else {
        riskLevel = RiskLevel.low;
      }
    }
    double confidence = 0.0;
    if (result.containsKey('confidence')) {
      final conf = result['confidence'];
      confidence = conf is double ? conf : (conf as num).toDouble();
      if (confidence > 1.0) confidence /= 100.0;
    }
    return PhotoResult(
      photoType: PhotoType.frontView,
      classProbabilities: classProbs,
      confidence: confidence,
      qualityScore: 1.0,
      riskLevel: riskLevel,
      isValidOralPhoto: true,
      displayLabel: (result['displayLabel'] ?? result['label']) as String?,
      cancerProbability: (result['cancerProbability'] as num?)?.toDouble(),
      perPhotoSummaryLabel: result['perPhotoSummaryLabel'] as String?,
    );
  }

  ScreeningResult _screeningResultFromInfer(Map<String, dynamic> result) {
    final photoResult = _photoResultFromInfer(result);
    final agg = photoResult.classProbabilities ?? const ClassProbabilities(healthy: 0.0, benign: 0.0, opmd: 0.0, oca: 0.0);
    final double cancerProb = (result['cancerProbability'] as num?)?.toDouble() ?? 0.0;
    final bool oodUnclear = result['oodUnclear'] as bool? ?? false;
    final bool lowQuality = result['lowQuality'] as bool? ?? false;

    // V2 single-photo outcome (binary is authority; retake zone and quality apply)
    ScreeningOutcome outcome;
    if (oodUnclear) {
      outcome = ScreeningOutcome.retakeSuggested;
    } else if (cancerProb >= ScreeningConfig.binaryScreeningThreshold) {
      outcome = ScreeningOutcome.reviewRecommended;
    } else if ((cancerProb >= ScreeningConfig.retakeLowerBound && cancerProb < ScreeningConfig.retakeUpperBound) ||
        lowQuality) {
      outcome = ScreeningOutcome.retakeSuggested;
    } else {
      outcome = ScreeningOutcome.lowRisk;
    }

    final subtypeGuidance = outcome == ScreeningOutcome.reviewRecommended
        ? _inferenceService.deriveSubtypeGuidance(agg)
        : SubtypeGuidance.none;
    final overallRisk = _inferenceService.outcomeToRiskLevel(outcome, subtypeGuidance);
    final urgencyLevel = _inferenceService.outcomeToUrgency(outcome, subtypeGuidance);
    final double pOpmdPlus = agg.opmd + agg.oca;
    final assessment = _inferenceService.buildV2AssessmentMessage(
      outcome: outcome,
      guidance: subtypeGuidance,
      photosUsed: 1,
      photosCaptured: 1,
      borderlineOpmdPlus: outcome == ScreeningOutcome.lowRisk ? pOpmdPlus : null,
    );

    double overallConfidence = 0.0;
    if (result.containsKey('confidence')) {
      final c = result['confidence'];
      overallConfidence = c is double ? c : (c as num).toDouble();
      if (overallConfidence > 1.0) overallConfidence /= 100.0;
    }
    final recommendations = ScreeningResult.generateRecommendations(overallRisk, [photoResult]);

    return ScreeningResult(
      overallRisk: overallRisk,
      overallConfidence: overallConfidence,
      photoResults: [photoResult],
      recommendations: recommendations,
      specialistRequired: urgencyLevel == UrgencyLevel.prompt || urgencyLevel == UrgencyLevel.urgent,
      urgencyLevel: urgencyLevel,
      urgencyText: urgencyLevel.displayText,
      aggregatedProbabilities: agg,
      analyzedAt: DateTime.now(),
      overallAssessmentTitle: assessment.title,
      overallAssessmentMessage: assessment.message,
      labelConfidence: agg.confidence,
      screeningOutcome: outcome,
      subtypeGuidance: subtypeGuidance,
      photosCaptured: 1,
      photosUsed: 1,
    );
  }

  void _openExplainResult() {
    if (_lastInferResult == null) return;
    final screeningResult = _screeningResultFromInfer(_lastInferResult!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DetailedResultsScreen(result: screeningResult),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bolt,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.quickCheckTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.quickCheckDesc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.quickCheckPreliminaryLine,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.lock_outlined,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.fullyPrivate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasImage = _hasImage;
    final hasResult = _lastInferResult != null;
    final riskLevel = hasResult ? _lastInferResult!['riskLevel'] as RiskLevel? : null;
    final displayLabel = hasResult ? (_lastInferResult!['displayLabel'] ?? _lastInferResult!['label']) as String? : null;
    final perPhotoSummaryLabel = hasResult ? _lastInferResult!['perPhotoSummaryLabel'] as String? : null;
    final cancerProbability = hasResult ? (_lastInferResult!['cancerProbability'] as num?)?.toDouble() : null;
    double? confidence;
    if (hasResult && _lastInferResult!.containsKey('confidence')) {
      final c = _lastInferResult!['confidence'];
      confidence = c is double ? c : (c as num).toDouble();
      if (confidence > 1.0) confidence /= 100.0;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (match Home)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.quickCheckTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onLocaleChanged != null)
                        IconButton(
                          icon: const Icon(Icons.language),
                          onPressed: () => showAppLanguagePicker(
                            context,
                            widget.onLocaleChanged!,
                          ),
                          tooltip: l10n.language,
                          color: Colors.blue[600],
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.health_and_safety,
                          color: Colors.blue[600],
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Hero card
              _buildHeroCard(context),
              const SizedBox(height: 24),

              // Image preview (web: Image.memory; mobile: Image.file)
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb && _displayImageBytes != null && _displayImageBytes!.isNotEmpty
                      ? Image.memory(
                          _displayImageBytes!,
                          height: 250,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ [QuickCheck] Failed to display image: $error');
                            debugPrint('   Stack trace: $stackTrace');
                            return Container(
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to display image',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Image.file(_image! as dynamic, height: 250, fit: BoxFit.contain),
                )
              else
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_search, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(
                          l10n.quickCheckTakeOrSelectPhoto,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Camera and Gallery
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isAnalyzing || _isLoadingModels) ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(l10n.quickCheckCamera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isAnalyzing || _isLoadingModels) ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Analyze button (when image is set)
              if (hasImage && !_isAnalyzing && !_isLoadingModels)
                ElevatedButton.icon(
                  onPressed: _runAnalyze,
                  icon: const Icon(Icons.analytics),
                  label: Text(l10n.quickCheckAnalyze),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              const SizedBox(height: 24),

              // Progress (analyzing or loading models on first use)
              if (_isAnalyzing || _isLoadingModels)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _isLoadingModels
                            ? 'Loading detailed models…'
                            : l10n.quickCheckAnalyzing,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      if (_isLoadingModels)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'One-time setup for best accuracy.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                )
              // Result card + Explain result
              else if (hasResult)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.quickCheckClassificationResult,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (riskLevel != null) ...[
                        RiskBadge(riskLevel: riskLevel, large: true),
                        const SizedBox(height: 12),
                      ],
                      if (cancerProbability != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Screening Risk Score: ${(cancerProbability! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cancerProbability >= ScreeningConfig.binaryScreeningThreshold
                                  ? Colors.red[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ),
                      if (displayLabel != null)
                        Text(
                          localizePerPhotoSummaryLabel(l10n, perPhotoSummaryLabel) ?? classLabelFriendly(l10n, displayLabel!),
                          style: const TextStyle(fontSize: 16),
                        ),
                      if (displayLabel != null && cancerProbability != null && confidence != null &&
                          (perPhotoSummaryLabel == null || perPhotoSummaryLabel == 'Healthy'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.perPhotoVisualDetailMostly(
                              classLabelFriendly(l10n, displayLabel!),
                              (confidence <= 1.0 ? confidence * 100 : confidence).toStringAsFixed(0),
                            ),
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ),
                      if (confidence != null && (displayLabel == null || cancerProbability == null))
                        Text(
                          l10n.detailModelPeakPercent((confidence <= 1.0 ? confidence * 100 : confidence).toStringAsFixed(1)),
                          style: const TextStyle(fontSize: 16),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openExplainResult,
                          icon: const Icon(Icons.info_outline),
                          label: Text(l10n.quickCheckExplainResult),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
