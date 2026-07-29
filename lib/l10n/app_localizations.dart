import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('gu'),
    Locale('hi'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Oral Cavity Check'**
  String get appTitle;

  /// No description provided for @loadingModels.
  ///
  /// In en, this message translates to:
  /// **'Loading AI models...'**
  String get loadingModels;

  /// No description provided for @failedToInitialize.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize'**
  String get failedToInitialize;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get navDebug;

  /// No description provided for @navQuickCheck.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get navQuickCheck;

  /// No description provided for @quickCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get quickCheckTitle;

  /// No description provided for @quickCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Use one photo for a quick result'**
  String get quickCheckDesc;

  /// No description provided for @quickCheckAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get quickCheckAnalyze;

  /// No description provided for @quickCheckAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get quickCheckAnalyzing;

  /// No description provided for @quickCheckExplainResult.
  ///
  /// In en, this message translates to:
  /// **'Explain result'**
  String get quickCheckExplainResult;

  /// No description provided for @quickCheckTakeOrSelectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take or select a photo'**
  String get quickCheckTakeOrSelectPhoto;

  /// No description provided for @quickCheckModelSelection.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get quickCheckModelSelection;

  /// No description provided for @quickCheckSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get quickCheckSelectModel;

  /// No description provided for @quickCheckCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get quickCheckCamera;

  /// No description provided for @quickCheckClassificationResult.
  ///
  /// In en, this message translates to:
  /// **'Classification Result'**
  String get quickCheckClassificationResult;

  /// No description provided for @oralHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'Oral Health Check'**
  String get oralHealthCheck;

  /// No description provided for @startNewCheck.
  ///
  /// In en, this message translates to:
  /// **'Start New Check'**
  String get startNewCheck;

  /// No description provided for @takeFivePhotosDesc.
  ///
  /// In en, this message translates to:
  /// **'Take 5 photos of your mouth for AI-powered early detection of potential issues.'**
  String get takeFivePhotosDesc;

  /// No description provided for @beginCheck.
  ///
  /// In en, this message translates to:
  /// **'Begin Check'**
  String get beginCheck;

  /// No description provided for @fullyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Fully private'**
  String get fullyPrivate;

  /// No description provided for @fullCheckDuration.
  ///
  /// In en, this message translates to:
  /// **'Full check: ~8–10 minutes'**
  String get fullCheckDuration;

  /// No description provided for @fullCheckHelperNote.
  ///
  /// In en, this message translates to:
  /// **'Best with a helper taking your photos'**
  String get fullCheckHelperNote;

  /// No description provided for @quickCheckDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick check: ~2 minutes'**
  String get quickCheckDurationLabel;

  /// No description provided for @quickCheckPreliminaryLine.
  ///
  /// In en, this message translates to:
  /// **'Fast preliminary look in ~2 minutes'**
  String get quickCheckPreliminaryLine;

  /// No description provided for @whyFivePhotos.
  ///
  /// In en, this message translates to:
  /// **'Why 5 Photos?'**
  String get whyFivePhotos;

  /// No description provided for @ninetyTwoPercentMoreAccurate.
  ///
  /// In en, this message translates to:
  /// **'92% more accurate'**
  String get ninetyTwoPercentMoreAccurate;

  /// No description provided for @multipleAnglesDesc.
  ///
  /// In en, this message translates to:
  /// **'Multiple angles provide comprehensive coverage of high-risk areas'**
  String get multipleAnglesDesc;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get howItWorks;

  /// No description provided for @stepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get stepPrepare;

  /// No description provided for @stepPrepareDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick checklist'**
  String get stepPrepareDesc;

  /// No description provided for @stepCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get stepCapture;

  /// No description provided for @stepCaptureDesc.
  ///
  /// In en, this message translates to:
  /// **'5 guided photos'**
  String get stepCaptureDesc;

  /// No description provided for @stepAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get stepAnalyze;

  /// No description provided for @stepAnalyzeDesc.
  ///
  /// In en, this message translates to:
  /// **'AI check'**
  String get stepAnalyzeDesc;

  /// No description provided for @stepResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get stepResults;

  /// No description provided for @stepResultsDesc.
  ///
  /// In en, this message translates to:
  /// **'Instant report'**
  String get stepResultsDesc;

  /// No description provided for @recentChecks.
  ///
  /// In en, this message translates to:
  /// **'Recent Checks'**
  String get recentChecks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @historyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'History feature coming soon'**
  String get historyComingSoon;

  /// No description provided for @noChecksYet.
  ///
  /// In en, this message translates to:
  /// **'No checks yet'**
  String get noChecksYet;

  /// No description provided for @startFirstCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Start your first check to track your oral health over time'**
  String get startFirstCheckDesc;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get analysisFailed;

  /// No description provided for @reminderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Reminder feature coming soon'**
  String get reminderComingSoon;

  /// No description provided for @findSpecialistComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Find specialist feature coming soon'**
  String get findSpecialistComingSoon;

  /// No description provided for @shareComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Share feature coming soon'**
  String get shareComingSoon;

  /// No description provided for @pdfComingSoon.
  ///
  /// In en, this message translates to:
  /// **'PDF download coming soon'**
  String get pdfComingSoon;

  /// No description provided for @welcomeOralCavityCheck.
  ///
  /// In en, this message translates to:
  /// **'Oral Cavity\nCheck'**
  String get welcomeOralCavityCheck;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered early detection\nfor better oral health'**
  String get welcomeSubtitle;

  /// No description provided for @fivePhotoCheck.
  ///
  /// In en, this message translates to:
  /// **'5-Photo Check'**
  String get fivePhotoCheck;

  /// No description provided for @fivePhotoCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive coverage of key areas'**
  String get fivePhotoCheckDesc;

  /// No description provided for @aiPoweredAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Analysis'**
  String get aiPoweredAnalysis;

  /// No description provided for @aiPoweredAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Advanced detection algorithms'**
  String get aiPoweredAnalysisDesc;

  /// No description provided for @hundredPercentPrivate.
  ///
  /// In en, this message translates to:
  /// **'100% Private'**
  String get hundredPercentPrivate;

  /// No description provided for @hundredPercentPrivateDesc.
  ///
  /// In en, this message translates to:
  /// **'All processing happens on your device'**
  String get hundredPercentPrivateDesc;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @beforeWeStart.
  ///
  /// In en, this message translates to:
  /// **'Before We Start'**
  String get beforeWeStart;

  /// No description provided for @preparationChecklist.
  ///
  /// In en, this message translates to:
  /// **'Preparation Checklist'**
  String get preparationChecklist;

  /// No description provided for @preparationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For best results, please prepare:'**
  String get preparationSubtitle;

  /// No description provided for @preparationPhotoSequenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Views we\'ll guide you through'**
  String get preparationPhotoSequenceTitle;

  /// No description provided for @preparationPhotoSequenceHint.
  ///
  /// In en, this message translates to:
  /// **'These are the usual angles for a full mouth check. After you save each photo, you can change the label if you captured a different area.'**
  String get preparationPhotoSequenceHint;

  /// No description provided for @goodLighting.
  ///
  /// In en, this message translates to:
  /// **'Good lighting'**
  String get goodLighting;

  /// No description provided for @goodLightingDesc.
  ///
  /// In en, this message translates to:
  /// **'Find a well-lit area or face a window'**
  String get goodLightingDesc;

  /// No description provided for @cleanMouth.
  ///
  /// In en, this message translates to:
  /// **'Clean mouth'**
  String get cleanMouth;

  /// No description provided for @cleanMouthDesc.
  ///
  /// In en, this message translates to:
  /// **'Rinse your mouth with water'**
  String get cleanMouthDesc;

  /// No description provided for @removeLipProducts.
  ///
  /// In en, this message translates to:
  /// **'Remove lip products'**
  String get removeLipProducts;

  /// No description provided for @removeLipProductsDesc.
  ///
  /// In en, this message translates to:
  /// **'Take off lipstick or lip gloss'**
  String get removeLipProductsDesc;

  /// No description provided for @mirrorNearby.
  ///
  /// In en, this message translates to:
  /// **'Mirror nearby'**
  String get mirrorNearby;

  /// No description provided for @mirrorNearbyDesc.
  ///
  /// In en, this message translates to:
  /// **'Helpful for positioning, especially for palate'**
  String get mirrorNearbyDesc;

  /// No description provided for @setAside2Minutes.
  ///
  /// In en, this message translates to:
  /// **'Set aside 8–10 minutes'**
  String get setAside2Minutes;

  /// No description provided for @screeningTakes60Seconds.
  ///
  /// In en, this message translates to:
  /// **'Each photo takes about 1-2 minutes'**
  String get screeningTakes60Seconds;

  /// No description provided for @imReady.
  ///
  /// In en, this message translates to:
  /// **'I\'m Ready'**
  String get imReady;

  /// No description provided for @photoXOfY.
  ///
  /// In en, this message translates to:
  /// **'Photo {current} of 5{suffix}'**
  String photoXOfY(int current, String suffix);

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **' • Required'**
  String get requiredLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In en, this message translates to:
  /// **' • Optional'**
  String get optionalLabel;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get usePhoto;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @failedToCapture.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture: {error}'**
  String failedToCapture(String error);

  /// No description provided for @failedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String failedToPickImage(String error);

  /// No description provided for @failedToSavePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to save photo: {error}'**
  String failedToSavePhoto(String error);

  /// No description provided for @cropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get cropPhoto;

  /// No description provided for @cropImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop Image'**
  String get cropImageTitle;

  /// No description provided for @failedToCropImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to crop image: {error}'**
  String failedToCropImage(String error);

  /// No description provided for @cropTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Crop too small. Keep at least {size}px on each side.'**
  String cropTooSmall(int size);

  /// No description provided for @cropTightWarning.
  ///
  /// In en, this message translates to:
  /// **'Cropped area is only {percent}% of the previous image. Keep enough surrounding tissue for context.'**
  String cropTightWarning(String percent);

  /// No description provided for @croppedPhotoNeedsRetake.
  ///
  /// In en, this message translates to:
  /// **'Cropped photo quality is low. Please recrop or retake for better analysis.'**
  String get croppedPhotoNeedsRetake;

  /// No description provided for @tipsForPhotoType.
  ///
  /// In en, this message translates to:
  /// **'Tips for {photoType}'**
  String tipsForPhotoType(String photoType);

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @exitCheck.
  ///
  /// In en, this message translates to:
  /// **'Exit Check?'**
  String get exitCheck;

  /// No description provided for @exitCheckMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit? Your progress will be lost.'**
  String get exitCheckMessage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @rotate90.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get rotate90;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @pinchToZoom.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom • Tap rotate to turn'**
  String get pinchToZoom;

  /// No description provided for @tipFrontView1.
  ///
  /// In en, this message translates to:
  /// **'Use natural light or face a window'**
  String get tipFrontView1;

  /// No description provided for @tipFrontView2.
  ///
  /// In en, this message translates to:
  /// **'Open your mouth wide to show teeth and gums'**
  String get tipFrontView2;

  /// No description provided for @tipFrontView3.
  ///
  /// In en, this message translates to:
  /// **'Keep your face centered in the frame'**
  String get tipFrontView3;

  /// No description provided for @tipFrontView4.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone about 12 inches away'**
  String get tipFrontView4;

  /// No description provided for @tipRightCheek1.
  ///
  /// In en, this message translates to:
  /// **'Gently pull your cheek outward with a finger'**
  String get tipRightCheek1;

  /// No description provided for @tipRightCheek2.
  ///
  /// In en, this message translates to:
  /// **'Try to fill most of the frame with the cheek tissue'**
  String get tipRightCheek2;

  /// No description provided for @tipRightCheek3.
  ///
  /// In en, this message translates to:
  /// **'Make sure the inner cheek surface is visible'**
  String get tipRightCheek3;

  /// No description provided for @tipRightCheek4.
  ///
  /// In en, this message translates to:
  /// **'Use flash if lighting is dim'**
  String get tipRightCheek4;

  /// No description provided for @tipLeftCheek1.
  ///
  /// In en, this message translates to:
  /// **'Gently pull your cheek outward with a finger'**
  String get tipLeftCheek1;

  /// No description provided for @tipLeftCheek2.
  ///
  /// In en, this message translates to:
  /// **'Try to fill most of the frame with the cheek tissue'**
  String get tipLeftCheek2;

  /// No description provided for @tipLeftCheek3.
  ///
  /// In en, this message translates to:
  /// **'Make sure the inner cheek surface is visible'**
  String get tipLeftCheek3;

  /// No description provided for @tipLeftCheek4.
  ///
  /// In en, this message translates to:
  /// **'Use flash if lighting is dim'**
  String get tipLeftCheek4;

  /// No description provided for @tipTongue1.
  ///
  /// In en, this message translates to:
  /// **'Stick your tongue out and up'**
  String get tipTongue1;

  /// No description provided for @tipTongue2.
  ///
  /// In en, this message translates to:
  /// **'Show both the top surface and edges'**
  String get tipTongue2;

  /// No description provided for @tipTongue3.
  ///
  /// In en, this message translates to:
  /// **'Try to relax your tongue for a natural position'**
  String get tipTongue3;

  /// No description provided for @tipTongue4.
  ///
  /// In en, this message translates to:
  /// **'Good lighting helps show texture details'**
  String get tipTongue4;

  /// No description provided for @tipPalate1.
  ///
  /// In en, this message translates to:
  /// **'Tilt your head back slightly'**
  String get tipPalate1;

  /// No description provided for @tipPalate2.
  ///
  /// In en, this message translates to:
  /// **'Open your mouth as wide as comfortable'**
  String get tipPalate2;

  /// No description provided for @tipPalate3.
  ///
  /// In en, this message translates to:
  /// **'Say \"Ahhh\" to lower your tongue'**
  String get tipPalate3;

  /// No description provided for @tipPalate4.
  ///
  /// In en, this message translates to:
  /// **'You may need help from someone else'**
  String get tipPalate4;

  /// No description provided for @instructionFrontView.
  ///
  /// In en, this message translates to:
  /// **'Open mouth wide and show upper & lower teeth. Center your face in the frame.'**
  String get instructionFrontView;

  /// No description provided for @instructionRightCheek.
  ///
  /// In en, this message translates to:
  /// **'Pull right cheek outward gently. Get close to capture the inner tissue.'**
  String get instructionRightCheek;

  /// No description provided for @instructionLeftCheek.
  ///
  /// In en, this message translates to:
  /// **'Pull left cheek outward gently. Get close to capture the inner tissue.'**
  String get instructionLeftCheek;

  /// No description provided for @instructionTongue.
  ///
  /// In en, this message translates to:
  /// **'Stick tongue out and up. Show the top surface and move side to side to show edges.'**
  String get instructionTongue;

  /// No description provided for @instructionPalate.
  ///
  /// In en, this message translates to:
  /// **'Tilt head back slightly. Open mouth wide and say \"Ahhh\" to lower tongue.'**
  String get instructionPalate;

  /// No description provided for @readyToCapture.
  ///
  /// In en, this message translates to:
  /// **'Ready to capture'**
  String get readyToCapture;

  /// No description provided for @adjustPosition.
  ///
  /// In en, this message translates to:
  /// **'Adjust position'**
  String get adjustPosition;

  /// No description provided for @brightnessLabel.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightnessLabel;

  /// No description provided for @focusLabel.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focusLabel;

  /// No description provided for @contrastLabel.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrastLabel;

  /// No description provided for @qualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get qualityGood;

  /// No description provided for @qualityRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get qualityRetake;

  /// No description provided for @feedbackMoveCloserToLight.
  ///
  /// In en, this message translates to:
  /// **'Move closer to light source'**
  String get feedbackMoveCloserToLight;

  /// No description provided for @feedbackHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold phone steady'**
  String get feedbackHoldSteady;

  /// No description provided for @feedbackEnsureLighting.
  ///
  /// In en, this message translates to:
  /// **'Ensure good lighting'**
  String get feedbackEnsureLighting;

  /// No description provided for @feedbackPleaseRetake.
  ///
  /// In en, this message translates to:
  /// **'Please retake photo'**
  String get feedbackPleaseRetake;

  /// No description provided for @howItWorksTake5Photos.
  ///
  /// In en, this message translates to:
  /// **'Take 5 Photos'**
  String get howItWorksTake5Photos;

  /// No description provided for @howItWorksTake5PhotosDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture your mouth from different angles:\n\n• Front view (teeth & gums)\n• Right cheek\n• Left cheek\n• Tongue\n• Palate (roof of mouth)'**
  String get howItWorksTake5PhotosDesc;

  /// No description provided for @howItWorksAIAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get howItWorksAIAnalysis;

  /// No description provided for @howItWorksAIAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Our AI examines your photos for:\n\n• Color changes\n• Unusual textures\n• Lesions or growths\n• Early warning signs\n\nAll analysis happens on your device.'**
  String get howItWorksAIAnalysisDesc;

  /// No description provided for @howItWorksGetResults.
  ///
  /// In en, this message translates to:
  /// **'Get Results'**
  String get howItWorksGetResults;

  /// No description provided for @howItWorksGetResultsDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive instant results with:\n\n• Risk assessment (Low/Moderate/High)\n• Photo-by-photo breakdown\n• Personalized recommendations\n• Option to share with doctor'**
  String get howItWorksGetResultsDesc;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @stepXOfY.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepXOfY(int current, int total);

  /// No description provided for @noActiveSession.
  ///
  /// In en, this message translates to:
  /// **'No active session'**
  String get noActiveSession;

  /// No description provided for @reviewPhotos.
  ///
  /// In en, this message translates to:
  /// **'Review Photos'**
  String get reviewPhotos;

  /// No description provided for @yourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Your Photos'**
  String get yourPhotos;

  /// No description provided for @frontViewRequired.
  ///
  /// In en, this message translates to:
  /// **'Front view (required) must be acceptable'**
  String get frontViewRequired;

  /// No description provided for @addMoreAngles.
  ///
  /// In en, this message translates to:
  /// **'Add more angles for better results (optional)'**
  String get addMoreAngles;

  /// No description provided for @capturedPhotosLookGood.
  ///
  /// In en, this message translates to:
  /// **'Captured photos look good'**
  String get capturedPhotosLookGood;

  /// No description provided for @needAtLeastTwoPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Add another angle'**
  String get needAtLeastTwoPhotosTitle;

  /// No description provided for @needAtLeastTwoPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis needs at least two acceptable photos. Your front view counts as one—add one more clear angle.'**
  String get needAtLeastTwoPhotosSubtitle;

  /// No description provided for @needAtLeastTwoPhotosForAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Add at least one more acceptable photo. Analysis requires at least two angles.'**
  String get needAtLeastTwoPhotosForAnalysis;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replacePhoto;

  /// No description provided for @analyzeAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'Analyze All Photos'**
  String get analyzeAllPhotos;

  /// No description provided for @analyzeNPhotos.
  ///
  /// In en, this message translates to:
  /// **'Analyze {count} Photo(s)'**
  String analyzeNPhotos(int count);

  /// No description provided for @allPhotosGood.
  ///
  /// In en, this message translates to:
  /// **'All photos look good!'**
  String get allPhotosGood;

  /// No description provided for @frontViewOkOptional.
  ///
  /// In en, this message translates to:
  /// **'Front view OK. Add or retake others (optional)'**
  String get frontViewOkOptional;

  /// No description provided for @somePhotosNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'Some photos need attention'**
  String get somePhotosNeedAttention;

  /// No description provided for @tipsForBetterPhotos.
  ///
  /// In en, this message translates to:
  /// **'Tips for better photos'**
  String get tipsForBetterPhotos;

  /// No description provided for @considerRetaking.
  ///
  /// In en, this message translates to:
  /// **'Consider retaking'**
  String get considerRetaking;

  /// No description provided for @analyzingYourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Your Photos'**
  String get analyzingYourPhotos;

  /// No description provided for @analysisStep1.
  ///
  /// In en, this message translates to:
  /// **'Checking image quality'**
  String get analysisStep1;

  /// No description provided for @analysisStep2.
  ///
  /// In en, this message translates to:
  /// **'Analyzing color patterns'**
  String get analysisStep2;

  /// No description provided for @analysisStep3.
  ///
  /// In en, this message translates to:
  /// **'Detecting texture abnormalities'**
  String get analysisStep3;

  /// No description provided for @analysisStep4.
  ///
  /// In en, this message translates to:
  /// **'Evaluating lesion markers'**
  String get analysisStep4;

  /// No description provided for @analysisStep5.
  ///
  /// In en, this message translates to:
  /// **'Calculating risk assessment'**
  String get analysisStep5;

  /// No description provided for @checkComplete.
  ///
  /// In en, this message translates to:
  /// **'Check Complete'**
  String get checkComplete;

  /// No description provided for @noConcerningSigns.
  ///
  /// In en, this message translates to:
  /// **'No Concerning Signs Detected'**
  String get noConcerningSigns;

  /// No description provided for @someChangesDetected.
  ///
  /// In en, this message translates to:
  /// **'Some Changes Detected'**
  String get someChangesDetected;

  /// No description provided for @concerningChangesFound.
  ///
  /// In en, this message translates to:
  /// **'Concerning Changes Found'**
  String get concerningChangesFound;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @areasNeedingAttention.
  ///
  /// In en, this message translates to:
  /// **'Areas needing attention'**
  String get areasNeedingAttention;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @disclaimerResults.
  ///
  /// In en, this message translates to:
  /// **'This screening is for early warning only and is not a medical diagnosis.'**
  String get disclaimerResults;

  /// No description provided for @setReminderForNextCheck.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder for Next Check'**
  String get setReminderForNextCheck;

  /// No description provided for @findDentistNearMe.
  ///
  /// In en, this message translates to:
  /// **'Find a Dentist Near Me'**
  String get findDentistNearMe;

  /// No description provided for @findSpecialistNow.
  ///
  /// In en, this message translates to:
  /// **'Find Specialist Now'**
  String get findSpecialistNow;

  /// No description provided for @scheduleRoutineCheckup.
  ///
  /// In en, this message translates to:
  /// **'Schedule routine dental checkup within 6 months'**
  String get scheduleRoutineCheckup;

  /// No description provided for @scheduleAppointment2to4Weeks.
  ///
  /// In en, this message translates to:
  /// **'Schedule appointment with dentist within 2-4 weeks'**
  String get scheduleAppointment2to4Weeks;

  /// No description provided for @urgentSeeSpecialist.
  ///
  /// In en, this message translates to:
  /// **'URGENT: See oral surgeon or oncologist within 1 week'**
  String get urgentSeeSpecialist;

  /// No description provided for @messageLow.
  ///
  /// In en, this message translates to:
  /// **'Our AI didn\'t detect any suspicious changes in your oral cavity. Continue maintaining good oral hygiene habits.'**
  String get messageLow;

  /// No description provided for @messageModerate.
  ///
  /// In en, this message translates to:
  /// **'We found some changes that may need professional review. Most changes are benign, but it\'s best to get a professional opinion.'**
  String get messageModerate;

  /// No description provided for @messageHigh.
  ///
  /// In en, this message translates to:
  /// **'Our AI detected changes that require professional evaluation. Please don\'t delay - early detection significantly improves outcomes.'**
  String get messageHigh;

  /// No description provided for @unableToAnalyzePhotos.
  ///
  /// In en, this message translates to:
  /// **'Unable to Analyze Photos'**
  String get unableToAnalyzePhotos;

  /// No description provided for @nPhotosSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} Photo(s) Skipped'**
  String nPhotosSkipped(int count);

  /// No description provided for @photosDontAppearMouth.
  ///
  /// In en, this message translates to:
  /// **'The photos don\'t appear to be of your mouth. Please retake with clear oral cavity photos.'**
  String get photosDontAppearMouth;

  /// No description provided for @somePhotosExcluded.
  ///
  /// In en, this message translates to:
  /// **'Some photos weren\'t recognized as oral cavity images and were excluded.'**
  String get somePhotosExcluded;

  /// No description provided for @detailedAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Detailed Analysis'**
  String get detailedAnalysis;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share Report'**
  String get shareReport;

  /// No description provided for @howWeDecided.
  ///
  /// In en, this message translates to:
  /// **'How we decided'**
  String get howWeDecided;

  /// No description provided for @analysisDetails.
  ///
  /// In en, this message translates to:
  /// **'Analysis Details'**
  String get analysisDetails;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @shareWithDoctor.
  ///
  /// In en, this message translates to:
  /// **'Share with Doctor'**
  String get shareWithDoctor;

  /// No description provided for @photoByPhotoAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Photo-by-Photo Analysis'**
  String get photoByPhotoAnalysis;

  /// No description provided for @overallAssessment.
  ///
  /// In en, this message translates to:
  /// **'Overall Assessment'**
  String get overallAssessment;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @importantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Important Disclaimer'**
  String get importantDisclaimer;

  /// No description provided for @disclaimerDetailed.
  ///
  /// In en, this message translates to:
  /// **'This initial check is for informational purposes only and is not a medical diagnosis. It provides an AI-assisted visual check to help determine whether professional evaluation may be advisable. Professional evaluation is essential for any concerning findings. Always consult qualified healthcare providers for medical advice.'**
  String get disclaimerDetailed;

  /// No description provided for @photosNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Photos Not Recognized'**
  String get photosNotRecognized;

  /// No description provided for @nOfMPhotosNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} Photos Not Recognized'**
  String nOfMPhotosNotRecognized(int count, int total);

  /// No description provided for @retakeScreeningAll.
  ///
  /// In en, this message translates to:
  /// **'None of your photos appear to be of the oral cavity. Please retake the screening with clear photos of your mouth.'**
  String get retakeScreeningAll;

  /// No description provided for @retakeScreeningSome.
  ///
  /// In en, this message translates to:
  /// **'Some photos don\'t appear to be of the oral cavity and were excluded from analysis. For better results, retake the screening.'**
  String get retakeScreeningSome;

  /// No description provided for @checkHistory.
  ///
  /// In en, this message translates to:
  /// **'Check History'**
  String get checkHistory;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @completeFirstCheck.
  ///
  /// In en, this message translates to:
  /// **'Complete your first check to start tracking your oral health over time'**
  String get completeFirstCheck;

  /// No description provided for @detailedHistoryComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Detailed history view coming soon'**
  String get detailedHistoryComingSoon;

  /// No description provided for @clearHistoryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get clearHistoryConfirmTitle;

  /// No description provided for @clearHistoryConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your screening history. This action cannot be undone.'**
  String get clearHistoryConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @photosAnalyzedConfidence.
  ///
  /// In en, this message translates to:
  /// **'{count} photos analyzed • {percent}% confidence'**
  String photosAnalyzedConfidence(int count, String percent);

  /// No description provided for @trendImproved.
  ///
  /// In en, this message translates to:
  /// **'Improved'**
  String get trendImproved;

  /// No description provided for @trendIncreased.
  ///
  /// In en, this message translates to:
  /// **'Increased'**
  String get trendIncreased;

  /// No description provided for @trendStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get trendStable;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String todayAt(String time);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'{day}/{month}/{year}'**
  String dateFormat(int day, int month, int year);

  /// No description provided for @yourPrivacyMatters.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get yourPrivacyMatters;

  /// No description provided for @heresHowWeProtectYou.
  ///
  /// In en, this message translates to:
  /// **'Here\'s how we protect you'**
  String get heresHowWeProtectYou;

  /// No description provided for @onDeviceProcessing.
  ///
  /// In en, this message translates to:
  /// **'On-Device Processing'**
  String get onDeviceProcessing;

  /// No description provided for @onDeviceProcessingDesc.
  ///
  /// In en, this message translates to:
  /// **'All AI analysis happens entirely on your device. Your photos never leave your phone and are not uploaded to any server.'**
  String get onDeviceProcessingDesc;

  /// No description provided for @noCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'No Cloud Storage'**
  String get noCloudStorage;

  /// No description provided for @noCloudStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'We don\'t store your photos or health data in the cloud. Everything stays locally on your device.'**
  String get noCloudStorageDesc;

  /// No description provided for @noTracking.
  ///
  /// In en, this message translates to:
  /// **'No Tracking'**
  String get noTracking;

  /// No description provided for @noTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'We don\'t track your usage or collect personal information. Your health screening is completely private.'**
  String get noTrackingDesc;

  /// No description provided for @yourControl.
  ///
  /// In en, this message translates to:
  /// **'Your Control'**
  String get yourControl;

  /// No description provided for @yourControlDesc.
  ///
  /// In en, this message translates to:
  /// **'You can delete your screening history at any time. All data is immediately removed.'**
  String get yourControlDesc;

  /// No description provided for @medicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Medical Disclaimer'**
  String get medicalDisclaimer;

  /// No description provided for @disclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'This app provides an AI-assisted initial visual check of oral images to help determine whether professional evaluation may be advisable.\n\nIt is not a medical diagnosis tool and must not be used as the sole basis for medical decisions. The results are informational only and do not replace examination, diagnosis, or treatment by a qualified healthcare professional.\n\nIf you notice persistent symptoms, pain, bleeding, ulcers that do not heal, or any concerning changes, please consult a dentist, oral surgeon, or qualified healthcare provider promptly.\n\nBy continuing, you acknowledge that you understand this tool is intended to support early referral decisions and not to provide medical diagnosis.'**
  String get disclaimerBody;

  /// No description provided for @disclaimerCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I understand this tool is intended to support early referral decisions and not to provide medical diagnosis'**
  String get disclaimerCheckbox;

  /// No description provided for @acceptContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get acceptContinue;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get statusNotStarted;

  /// No description provided for @statusCapturing.
  ///
  /// In en, this message translates to:
  /// **'Capturing Photos'**
  String get statusCapturing;

  /// No description provided for @statusReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing Photos'**
  String get statusReviewing;

  /// No description provided for @statusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get statusAnalyzing;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low Risk'**
  String get riskLow;

  /// No description provided for @riskModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate Risk'**
  String get riskModerate;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High Risk'**
  String get riskHigh;

  /// No description provided for @classFriendlyHealthy.
  ///
  /// In en, this message translates to:
  /// **'No concerning changes detected (Healthy)'**
  String get classFriendlyHealthy;

  /// No description provided for @classFriendlyBenign.
  ///
  /// In en, this message translates to:
  /// **'Minor, non-concerning changes (Benign)'**
  String get classFriendlyBenign;

  /// No description provided for @classFriendlyOPMD.
  ///
  /// In en, this message translates to:
  /// **'Changes that may need follow-up were noted (OPMD)'**
  String get classFriendlyOPMD;

  /// No description provided for @classFriendlyOCA.
  ///
  /// In en, this message translates to:
  /// **'Findings that should be checked by a specialist (OCA)'**
  String get classFriendlyOCA;

  /// No description provided for @classFriendlyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Image unclear or not suitable for assessment (Unknown)'**
  String get classFriendlyUnknown;

  /// No description provided for @classFriendlyUncertain.
  ///
  /// In en, this message translates to:
  /// **'Awaiting clinical verification (Uncertain)'**
  String get classFriendlyUncertain;

  /// No description provided for @photoFrontView.
  ///
  /// In en, this message translates to:
  /// **'Front View'**
  String get photoFrontView;

  /// No description provided for @photoRightCheek.
  ///
  /// In en, this message translates to:
  /// **'Right Cheek'**
  String get photoRightCheek;

  /// No description provided for @photoLeftCheek.
  ///
  /// In en, this message translates to:
  /// **'Left Cheek'**
  String get photoLeftCheek;

  /// No description provided for @photoTongue.
  ///
  /// In en, this message translates to:
  /// **'Tongue'**
  String get photoTongue;

  /// No description provided for @photoPalate.
  ///
  /// In en, this message translates to:
  /// **'Palate'**
  String get photoPalate;

  /// No description provided for @photoLabelCurrentView.
  ///
  /// In en, this message translates to:
  /// **'Current View'**
  String get photoLabelCurrentView;

  /// No description provided for @photoLabelChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get photoLabelChange;

  /// No description provided for @photoLabelPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select photo label'**
  String get photoLabelPickerTitle;

  /// No description provided for @photoLabelPickerHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional — override the default label for this photo'**
  String get photoLabelPickerHelper;

  /// No description provided for @photoLabelCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get photoLabelCustom;

  /// No description provided for @photoLabelCustomHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Tongue – Upper'**
  String get photoLabelCustomHint;

  /// No description provided for @photoLabelCustomEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a label'**
  String get photoLabelCustomEmpty;

  /// No description provided for @photoLabelSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get photoLabelSave;

  /// No description provided for @notOral.
  ///
  /// In en, this message translates to:
  /// **'Not oral'**
  String get notOral;

  /// No description provided for @notAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'Not analyzed'**
  String get notAnalyzed;

  /// No description provided for @qualityIssue.
  ///
  /// In en, this message translates to:
  /// **'Quality issue'**
  String get qualityIssue;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percent}%'**
  String confidenceLabel(String percent);

  /// No description provided for @labelConfidencePercent.
  ///
  /// In en, this message translates to:
  /// **'Label confidence: {percent}%'**
  String labelConfidencePercent(String percent);

  /// No description provided for @oralCavityScreeningReport.
  ///
  /// In en, this message translates to:
  /// **'Oral Cavity Initial Check Report'**
  String get oralCavityScreeningReport;

  /// No description provided for @generatedOn.
  ///
  /// In en, this message translates to:
  /// **'Generated on: {date}'**
  String generatedOn(String date);

  /// No description provided for @reportDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'This initial check is for informational purposes only and is not a medical diagnosis. It provides an AI-assisted visual check to help determine whether professional evaluation may be advisable. The results are informational only and do not replace examination, diagnosis, or treatment by a qualified healthcare professional. Please consult qualified healthcare professionals for proper diagnosis and treatment.'**
  String get reportDisclaimerBody;

  /// No description provided for @shareReportSubject.
  ///
  /// In en, this message translates to:
  /// **'Oral Cavity Initial Check Report'**
  String get shareReportSubject;

  /// No description provided for @shareReportText.
  ///
  /// In en, this message translates to:
  /// **'Here is my oral cavity initial check report. Risk level: {riskLevel}'**
  String shareReportText(String riskLevel);

  /// No description provided for @riskLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk Level:'**
  String get riskLevelLabel;

  /// No description provided for @screeningRemindersChannel.
  ///
  /// In en, this message translates to:
  /// **'Screening Reminders'**
  String get screeningRemindersChannel;

  /// No description provided for @screeningRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminders for oral cavity screening'**
  String get screeningRemindersDesc;

  /// No description provided for @timeForOralScreening.
  ///
  /// In en, this message translates to:
  /// **'Time for Oral Screening'**
  String get timeForOralScreening;

  /// No description provided for @threeMonthReminderBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s been 3 months since your last screening. Regular checkups help detect issues early.'**
  String get threeMonthReminderBody;

  /// No description provided for @testNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification from Oral Cavity Screening app'**
  String get testNotificationBody;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Current language'**
  String get currentLanguage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @labelConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Label confidence'**
  String get labelConfidenceLabel;

  /// No description provided for @detailedTissueClassificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Tissue Classification'**
  String get detailedTissueClassificationTitle;

  /// No description provided for @aiTissueClassificationSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tissue Classification Summary'**
  String get aiTissueClassificationSummarySubtitle;

  /// No description provided for @tissueInterpretationDominant.
  ///
  /// In en, this message translates to:
  /// **'The AI tissue-classification system identified a stronger visual match with the \"{label}\" tissue-pattern category compared to other categories. This detailed classification supports interpretation of the analyzed oral images and does not change the screening recommendation.'**
  String tissueInterpretationDominant(String label);

  /// No description provided for @tissueInterpretationMixed.
  ///
  /// In en, this message translates to:
  /// **'No single tissue-pattern category was strongly dominant across the analyzed images. The visual features identified by the AI overlapped multiple classification categories. This does not change the screening recommendation.'**
  String get tissueInterpretationMixed;

  /// No description provided for @photoTableDetailPeakHeader.
  ///
  /// In en, this message translates to:
  /// **'Detail peak'**
  String get photoTableDetailPeakHeader;

  /// No description provided for @detailModelPeakPercent.
  ///
  /// In en, this message translates to:
  /// **'Detail model peak: {percent}%'**
  String detailModelPeakPercent(String percent);

  /// No description provided for @photosAnalyzedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 photo analyzed} other{{count} photos analyzed}}'**
  String photosAnalyzedCount(int count);

  /// No description provided for @reportPhotosAnalyzedLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos analyzed'**
  String get reportPhotosAnalyzedLabel;

  /// No description provided for @photosStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosStatLabel;

  /// No description provided for @urgencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get urgencyLabel;

  /// No description provided for @actionConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Action confidence: {level}'**
  String actionConfidenceLabel(String level);

  /// No description provided for @checksDisagreedSuffix.
  ///
  /// In en, this message translates to:
  /// **'(checks disagreed)'**
  String get checksDisagreedSuffix;

  /// No description provided for @urgencyRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine (2–4 weeks)'**
  String get urgencyRoutine;

  /// No description provided for @urgencyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt (1–2 weeks)'**
  String get urgencyPrompt;

  /// No description provided for @urgencyUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent (within 1 week)'**
  String get urgencyUrgent;

  /// No description provided for @urgencyRetakePhotos.
  ///
  /// In en, this message translates to:
  /// **'Retake photos'**
  String get urgencyRetakePhotos;

  /// No description provided for @eriQuestionnaireTitle.
  ///
  /// In en, this message translates to:
  /// **'Tobacco Exposure'**
  String get eriQuestionnaireTitle;

  /// No description provided for @eriGateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you use any tobacco products?'**
  String get eriGateQuestion;

  /// No description provided for @eriGateHelper.
  ///
  /// In en, this message translates to:
  /// **'This helps us provide better guidance. It does not provide a diagnosis. Your answers stay on this device.'**
  String get eriGateHelper;

  /// No description provided for @eriYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get eriYes;

  /// No description provided for @eriNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get eriNo;

  /// No description provided for @eriTypeQuestion.
  ///
  /// In en, this message translates to:
  /// **'What type of tobacco do you use?'**
  String get eriTypeQuestion;

  /// No description provided for @eriSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get eriSelectAll;

  /// No description provided for @eriOtherSpecifyLabel.
  ///
  /// In en, this message translates to:
  /// **'Please specify'**
  String get eriOtherSpecifyLabel;

  /// No description provided for @eriOtherSpecifyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Khaini, Zarda...'**
  String get eriOtherSpecifyHint;

  /// No description provided for @eriOtherSpecifyError.
  ///
  /// In en, this message translates to:
  /// **'Please specify the other tobacco type'**
  String get eriOtherSpecifyError;

  /// No description provided for @eriTypeRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one type'**
  String get eriTypeRequiredError;

  /// No description provided for @eriDurationQuestion.
  ///
  /// In en, this message translates to:
  /// **'How long have you been using tobacco?'**
  String get eriDurationQuestion;

  /// No description provided for @eriDurationRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please select a duration'**
  String get eriDurationRequiredError;

  /// No description provided for @eriFrequencyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many times per day (approx.)?'**
  String get eriFrequencyQuestion;

  /// No description provided for @eriFrequencyHelper.
  ///
  /// In en, this message translates to:
  /// **'For smoking: number of cigarettes/beedis. For chewing: number of times used.'**
  String get eriFrequencyHelper;

  /// No description provided for @eriFrequencyRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please select a frequency'**
  String get eriFrequencyRequiredError;

  /// No description provided for @eriChangeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Change answer'**
  String get eriChangeAnswer;

  /// No description provided for @eriDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Exposure Risk Index is based on self-reported data and does not replace medical evaluation.'**
  String get eriDisclaimer;

  /// No description provided for @eriRiskSummary.
  ///
  /// In en, this message translates to:
  /// **'Risk Summary'**
  String get eriRiskSummary;

  /// No description provided for @eriAiImageRisk.
  ///
  /// In en, this message translates to:
  /// **'AI Image Risk'**
  String get eriAiImageRisk;

  /// No description provided for @eriExposureRisk.
  ///
  /// In en, this message translates to:
  /// **'Exposure Risk'**
  String get eriExposureRisk;

  /// No description provided for @eriFinalRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Final Recommendation'**
  String get eriFinalRecommendation;

  /// No description provided for @eriNotReported.
  ///
  /// In en, this message translates to:
  /// **'Not reported'**
  String get eriNotReported;

  /// No description provided for @eriNoReportedTobaccoUse.
  ///
  /// In en, this message translates to:
  /// **'No reported tobacco use'**
  String get eriNoReportedTobaccoUse;

  /// No description provided for @eriTobaccoExposureWithLevel.
  ///
  /// In en, this message translates to:
  /// **'Tobacco Exposure: {level}'**
  String eriTobaccoExposureWithLevel(String level);

  /// No description provided for @eriRecommendedRescreenInterval.
  ///
  /// In en, this message translates to:
  /// **'Recommended rescreen interval: {interval}'**
  String eriRecommendedRescreenInterval(String interval);

  /// No description provided for @eriTobaccoExposureSummary.
  ///
  /// In en, this message translates to:
  /// **'Tobacco Exposure Summary'**
  String get eriTobaccoExposureSummary;

  /// No description provided for @eriTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get eriTypeLabel;

  /// No description provided for @eriOtherSpecifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Other (specified)'**
  String get eriOtherSpecifiedLabel;

  /// No description provided for @eriDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get eriDurationLabel;

  /// No description provided for @eriFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get eriFrequencyLabel;

  /// No description provided for @eriExposureRiskLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Exposure Risk Level'**
  String get eriExposureRiskLevelLabel;

  /// No description provided for @eriExposureScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Exposure Score'**
  String get eriExposureScoreLabel;

  /// No description provided for @eriRescreenIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Rescreen Interval'**
  String get eriRescreenIntervalLabel;

  /// No description provided for @eriReportField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get eriReportField;

  /// No description provided for @eriReportValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get eriReportValue;

  /// No description provided for @tobaccoTypeCigarette.
  ///
  /// In en, this message translates to:
  /// **'Cigarette'**
  String get tobaccoTypeCigarette;

  /// No description provided for @tobaccoTypeBeedi.
  ///
  /// In en, this message translates to:
  /// **'Beedi'**
  String get tobaccoTypeBeedi;

  /// No description provided for @tobaccoTypeHookah.
  ///
  /// In en, this message translates to:
  /// **'Hookah'**
  String get tobaccoTypeHookah;

  /// No description provided for @tobaccoTypeArecaNut.
  ///
  /// In en, this message translates to:
  /// **'Areca Nut (Supari)'**
  String get tobaccoTypeArecaNut;

  /// No description provided for @tobaccoTypePaanMasala.
  ///
  /// In en, this message translates to:
  /// **'Paan Masala'**
  String get tobaccoTypePaanMasala;

  /// No description provided for @tobaccoTypeGutka.
  ///
  /// In en, this message translates to:
  /// **'Gutka'**
  String get tobaccoTypeGutka;

  /// No description provided for @tobaccoTypeSurti.
  ///
  /// In en, this message translates to:
  /// **'Surti'**
  String get tobaccoTypeSurti;

  /// No description provided for @tobaccoTypeGul.
  ///
  /// In en, this message translates to:
  /// **'Gul'**
  String get tobaccoTypeGul;

  /// No description provided for @tobaccoTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tobaccoTypeOther;

  /// No description provided for @durationLessThan1Year.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 year'**
  String get durationLessThan1Year;

  /// No description provided for @duration1To5Years.
  ///
  /// In en, this message translates to:
  /// **'1–5 years'**
  String get duration1To5Years;

  /// No description provided for @duration5To10Years.
  ///
  /// In en, this message translates to:
  /// **'5–10 years'**
  String get duration5To10Years;

  /// No description provided for @duration10To20Years.
  ///
  /// In en, this message translates to:
  /// **'10–20 years'**
  String get duration10To20Years;

  /// No description provided for @durationMoreThan20Years.
  ///
  /// In en, this message translates to:
  /// **'More than 20 years'**
  String get durationMoreThan20Years;

  /// No description provided for @frequencyOccasional.
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get frequencyOccasional;

  /// No description provided for @frequency1To5PerDay.
  ///
  /// In en, this message translates to:
  /// **'1–5 per day'**
  String get frequency1To5PerDay;

  /// No description provided for @frequency5To10PerDay.
  ///
  /// In en, this message translates to:
  /// **'5–10 per day'**
  String get frequency5To10PerDay;

  /// No description provided for @frequencyMoreThan10PerDay.
  ///
  /// In en, this message translates to:
  /// **'More than 10 per day'**
  String get frequencyMoreThan10PerDay;

  /// No description provided for @exposureRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get exposureRiskLow;

  /// No description provided for @exposureRiskModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get exposureRiskModerate;

  /// No description provided for @exposureRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get exposureRiskHigh;

  /// No description provided for @eriRecHighUrgentReferral.
  ///
  /// In en, this message translates to:
  /// **'Tobacco exposure significantly elevates risk. Urgent specialist referral recommended.'**
  String get eriRecHighUrgentReferral;

  /// No description provided for @eriMsgLongTermExposure.
  ///
  /// In en, this message translates to:
  /// **'Based on reported long-term tobacco exposure, regular clinical evaluation is strongly recommended even if current image findings are not highly suspicious.'**
  String get eriMsgLongTermExposure;

  /// No description provided for @eriRecModerateConcern.
  ///
  /// In en, this message translates to:
  /// **'Tobacco exposure adds to concern. Follow-up dental visit strongly advised.'**
  String get eriRecModerateConcern;

  /// No description provided for @eriMsgModerateExposure.
  ///
  /// In en, this message translates to:
  /// **'Moderate tobacco exposure noted. Combined with image findings, timely clinical follow-up is recommended.'**
  String get eriMsgModerateExposure;

  /// No description provided for @eriRecEnhancedMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Monitoring Recommended'**
  String get eriRecEnhancedMonitoring;

  /// No description provided for @eriRecRescreen1Month.
  ///
  /// In en, this message translates to:
  /// **'Due to high tobacco exposure, rescreen in 1 month instead of 3.'**
  String get eriRecRescreen1Month;

  /// No description provided for @eriRecRescreen2Months.
  ///
  /// In en, this message translates to:
  /// **'Due to moderate tobacco exposure, consider rescreening in 2 months.'**
  String get eriRecRescreen2Months;

  /// No description provided for @eriFinalRecommendationElevatedNote.
  ///
  /// In en, this message translates to:
  /// **'The final recommendation combines findings from the analyzed images with your reported tobacco exposure.'**
  String get eriFinalRecommendationElevatedNote;

  /// No description provided for @assessmentTitleInconclusiveRetake.
  ///
  /// In en, this message translates to:
  /// **'Inconclusive – Retake Photos'**
  String get assessmentTitleInconclusiveRetake;

  /// No description provided for @assessmentTitleModerateReviewSuggested.
  ///
  /// In en, this message translates to:
  /// **'Moderate – Review Suggested'**
  String get assessmentTitleModerateReviewSuggested;

  /// No description provided for @assessmentTitleModerateNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Moderate – Needs Attention'**
  String get assessmentTitleModerateNeedsAttention;

  /// No description provided for @assessmentTitleModerateNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Moderate – Needs Review'**
  String get assessmentTitleModerateNeedsReview;

  /// No description provided for @assessmentMessageInconclusiveRetake.
  ///
  /// In en, this message translates to:
  /// **'Photos were not clear/consistent enough to give a reliable result. Please retake in good light. If you have symptoms (pain, ulcer >2 weeks, bleeding), consult a clinician.'**
  String get assessmentMessageInconclusiveRetake;

  /// No description provided for @assessmentMessageLowRisk.
  ///
  /// In en, this message translates to:
  /// **'No concerning signs detected in these photos.'**
  String get assessmentMessageLowRisk;

  /// No description provided for @assessmentMessageHighRisk.
  ///
  /// In en, this message translates to:
  /// **'Findings may require urgent professional evaluation. Please consult a dentist/oral specialist within one week.'**
  String get assessmentMessageHighRisk;

  /// No description provided for @assessmentMessageModerateReviewSuggested.
  ///
  /// In en, this message translates to:
  /// **'Most signs look non-concerning. One check suggested follow-up, so a routine dental review is recommended.'**
  String get assessmentMessageModerateReviewSuggested;

  /// No description provided for @assessmentMessageModerateNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Some changes may need follow-up. Please arrange a dental review within 1–2 weeks.'**
  String get assessmentMessageModerateNeedsAttention;

  /// No description provided for @assessmentMessageModerateNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Some changes may need professional review. Please arrange a review within 1–2 weeks.'**
  String get assessmentMessageModerateNeedsReview;

  /// No description provided for @riskSubtypeTitleOcaDominant.
  ///
  /// In en, this message translates to:
  /// **'High Risk – Urgent Clinical Review Suggested'**
  String get riskSubtypeTitleOcaDominant;

  /// No description provided for @riskSubtypeTitleOpmdDominant.
  ///
  /// In en, this message translates to:
  /// **'Moderate to High Risk – Specialist Review Recommended'**
  String get riskSubtypeTitleOpmdDominant;

  /// No description provided for @riskSubtypeTitleBenignDominant.
  ///
  /// In en, this message translates to:
  /// **'Lesion Detected – Clinical Evaluation Advised'**
  String get riskSubtypeTitleBenignDominant;

  /// No description provided for @riskSubtypeMessageOcaDominant.
  ///
  /// In en, this message translates to:
  /// **'Patterns consistent with potentially serious changes detected. Please consult a dentist or oral specialist promptly.'**
  String get riskSubtypeMessageOcaDominant;

  /// No description provided for @riskSubtypeMessageOpmdDominant.
  ///
  /// In en, this message translates to:
  /// **'Early changes that may benefit from specialist review have been detected. Early detection significantly improves outcomes.'**
  String get riskSubtypeMessageOpmdDominant;

  /// No description provided for @riskSubtypeMessageBenignDominant.
  ///
  /// In en, this message translates to:
  /// **'A lesion was detected that appears non-threatening but should be evaluated by a healthcare professional to confirm.'**
  String get riskSubtypeMessageBenignDominant;

  /// No description provided for @perPhotoLabelPotentialConcern.
  ///
  /// In en, this message translates to:
  /// **'Potential Concern'**
  String get perPhotoLabelPotentialConcern;

  /// No description provided for @perPhotoLabelReviewRecommended.
  ///
  /// In en, this message translates to:
  /// **'Review Recommended'**
  String get perPhotoLabelReviewRecommended;

  /// No description provided for @perPhotoLabelHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get perPhotoLabelHealthy;

  /// No description provided for @perPhotoLabelRetakeOrReview.
  ///
  /// In en, this message translates to:
  /// **'Retake or further analysis needed'**
  String get perPhotoLabelRetakeOrReview;

  /// No description provided for @perPhotoNoteHighConflict.
  ///
  /// In en, this message translates to:
  /// **'Screening detected risk factors. Visual pattern appears healthy, but professional review is recommended.'**
  String get perPhotoNoteHighConflict;

  /// No description provided for @perPhotoNoteModerateConflict.
  ///
  /// In en, this message translates to:
  /// **'Subtle signs detected. Visual pattern: Healthy. Consider a follow-up.'**
  String get perPhotoNoteModerateConflict;

  /// No description provided for @perPhotoNoteHighConflictBenign.
  ///
  /// In en, this message translates to:
  /// **'Screening detected risk factors. Visual pattern appears benign. Professional review is recommended.'**
  String get perPhotoNoteHighConflictBenign;

  /// No description provided for @perPhotoNoteModerateConflictBenign.
  ///
  /// In en, this message translates to:
  /// **'Subtle signs detected. Visual pattern: Benign. Consider a follow-up.'**
  String get perPhotoNoteModerateConflictBenign;

  /// No description provided for @perPhotoVisualDetailMostly.
  ///
  /// In en, this message translates to:
  /// **'Visual Detail: Mostly {label} ({percent}%)'**
  String perPhotoVisualDetailMostly(String label, String percent);

  /// No description provided for @photosCapturedGoodQuality.
  ///
  /// In en, this message translates to:
  /// **'{count}/5 photos captured with good quality'**
  String photosCapturedGoodQuality(int count);

  /// No description provided for @photosMayNeedRetake.
  ///
  /// In en, this message translates to:
  /// **'{count} photo(s) may need retaking for best results'**
  String photosMayNeedRetake(int count);

  /// No description provided for @recNoConcerningSigns.
  ///
  /// In en, this message translates to:
  /// **'No concerning signs detected'**
  String get recNoConcerningSigns;

  /// No description provided for @recContinueOralHygiene.
  ///
  /// In en, this message translates to:
  /// **'Continue regular oral hygiene'**
  String get recContinueOralHygiene;

  /// No description provided for @recScheduleRoutineCheckup.
  ///
  /// In en, this message translates to:
  /// **'Schedule routine dental checkup'**
  String get recScheduleRoutineCheckup;

  /// No description provided for @recRescreen3Months.
  ///
  /// In en, this message translates to:
  /// **'Rescreen in 3 months'**
  String get recRescreen3Months;

  /// No description provided for @recNeedClearerPhotosFor.
  ///
  /// In en, this message translates to:
  /// **'Need clearer photos for: {list}'**
  String recNeedClearerPhotosFor(String list);

  /// No description provided for @recSomeChangesNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'Some changes detected that need attention'**
  String get recSomeChangesNeedAttention;

  /// No description provided for @recSchedule2to4Weeks.
  ///
  /// In en, this message translates to:
  /// **'Schedule appointment with dentist within 2-4 weeks'**
  String get recSchedule2to4Weeks;

  /// No description provided for @recAvoidTobaccoAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Avoid tobacco and alcohol'**
  String get recAvoidTobaccoAlcohol;

  /// No description provided for @recMonitorChangesClosely.
  ///
  /// In en, this message translates to:
  /// **'Monitor any changes closely'**
  String get recMonitorChangesClosely;

  /// No description provided for @recPaySpecialAttentionTo.
  ///
  /// In en, this message translates to:
  /// **'Pay special attention to: {list}'**
  String recPaySpecialAttentionTo(String list);

  /// No description provided for @recConcerningChangesDetected.
  ///
  /// In en, this message translates to:
  /// **'Concerning changes detected'**
  String get recConcerningChangesDetected;

  /// No description provided for @recUrgentSeeSpecialist.
  ///
  /// In en, this message translates to:
  /// **'URGENT: See oral surgeon or oncologist within 1 week'**
  String get recUrgentSeeSpecialist;

  /// No description provided for @recBringReportToAppointment.
  ///
  /// In en, this message translates to:
  /// **'Bring this report to your appointment'**
  String get recBringReportToAppointment;

  /// No description provided for @recEarlyDetectionImprovesOutcomes.
  ///
  /// In en, this message translates to:
  /// **'Early detection significantly improves outcomes'**
  String get recEarlyDetectionImprovesOutcomes;

  /// No description provided for @check1Referral.
  ///
  /// In en, this message translates to:
  /// **'Check 1 (referral)'**
  String get check1Referral;

  /// No description provided for @check2Detail.
  ///
  /// In en, this message translates to:
  /// **'Check 2 (detail)'**
  String get check2Detail;

  /// No description provided for @check2DetailWithConfidence.
  ///
  /// In en, this message translates to:
  /// **'Check 2 (detail): {label} ({percent}% confidence)'**
  String check2DetailWithConfidence(String label, String percent);

  /// No description provided for @verdictBothLowRisk.
  ///
  /// In en, this message translates to:
  /// **'Both checks suggest low risk. No immediate follow-up needed; routine check-ups are still recommended.'**
  String get verdictBothLowRisk;

  /// No description provided for @verdictBothSomeConcern.
  ///
  /// In en, this message translates to:
  /// **'Both checks suggest some concern ({label}). We recommend follow-up with a healthcare provider.'**
  String verdictBothSomeConcern(String label);

  /// No description provided for @verdictReferralAppropriate.
  ///
  /// In en, this message translates to:
  /// **'Both checks suggest referral is appropriate. Please see a healthcare provider for further evaluation.'**
  String get verdictReferralAppropriate;

  /// No description provided for @verdictDifferentSignals.
  ///
  /// In en, this message translates to:
  /// **'The two checks gave different signals. We show {risk} and recommend follow-up so a professional can decide.'**
  String verdictDifferentSignals(String risk);

  /// No description provided for @verdictCouldNotAssess.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be assessed. {note}'**
  String verdictCouldNotAssess(String note);

  /// No description provided for @verdictPleaseRetake.
  ///
  /// In en, this message translates to:
  /// **'Please retake.'**
  String get verdictPleaseRetake;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'es',
    'gu',
    'hi',
    'mr',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
