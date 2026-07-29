// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Oral Cavity Check';

  @override
  String get loadingModels => 'Loading AI models...';

  @override
  String get failedToInitialize => 'Failed to initialize';

  @override
  String get retry => 'Retry';

  @override
  String get navHome => 'Home';

  @override
  String get navDebug => 'Debug';

  @override
  String get navQuickCheck => 'Quick check';

  @override
  String get quickCheckTitle => 'Quick check';

  @override
  String get quickCheckDesc => 'Use one photo for a quick result';

  @override
  String get quickCheckAnalyze => 'Analyze';

  @override
  String get quickCheckAnalyzing => 'Analyzing…';

  @override
  String get quickCheckExplainResult => 'Explain result';

  @override
  String get quickCheckTakeOrSelectPhoto => 'Take or select a photo';

  @override
  String get quickCheckModelSelection => 'Model';

  @override
  String get quickCheckSelectModel => 'Select Model';

  @override
  String get quickCheckCamera => 'Camera';

  @override
  String get quickCheckClassificationResult => 'Classification Result';

  @override
  String get oralHealthCheck => 'Oral Health Check';

  @override
  String get startNewCheck => 'Start New Check';

  @override
  String get takeFivePhotosDesc =>
      'Take 5 photos of your mouth for AI-powered early detection of potential issues.';

  @override
  String get beginCheck => 'Begin Check';

  @override
  String get fullyPrivate => 'Fully private';

  @override
  String get fullCheckDuration => 'Full check: ~8–10 minutes';

  @override
  String get fullCheckHelperNote => 'Best with a helper taking your photos';

  @override
  String get quickCheckDurationLabel => 'Quick check: ~2 minutes';

  @override
  String get quickCheckPreliminaryLine => 'Fast preliminary look in ~2 minutes';

  @override
  String get whyFivePhotos => 'Why 5 Photos?';

  @override
  String get ninetyTwoPercentMoreAccurate => '92% more accurate';

  @override
  String get multipleAnglesDesc =>
      'Multiple angles provide comprehensive coverage of high-risk areas';

  @override
  String get howItWorks => 'How It Works';

  @override
  String get stepPrepare => 'Prepare';

  @override
  String get stepPrepareDesc => 'Quick checklist';

  @override
  String get stepCapture => 'Capture';

  @override
  String get stepCaptureDesc => '5 guided photos';

  @override
  String get stepAnalyze => 'Analyze';

  @override
  String get stepAnalyzeDesc => 'AI check';

  @override
  String get stepResults => 'Results';

  @override
  String get stepResultsDesc => 'Instant report';

  @override
  String get recentChecks => 'Recent Checks';

  @override
  String get viewAll => 'View All';

  @override
  String get historyComingSoon => 'History feature coming soon';

  @override
  String get noChecksYet => 'No checks yet';

  @override
  String get startFirstCheckDesc =>
      'Start your first check to track your oral health over time';

  @override
  String get analysisFailed => 'Analysis failed';

  @override
  String get reminderComingSoon => 'Reminder feature coming soon';

  @override
  String get findSpecialistComingSoon => 'Find specialist feature coming soon';

  @override
  String get shareComingSoon => 'Share feature coming soon';

  @override
  String get pdfComingSoon => 'PDF download coming soon';

  @override
  String get welcomeOralCavityCheck => 'Oral Cavity\nCheck';

  @override
  String get welcomeSubtitle =>
      'AI-powered early detection\nfor better oral health';

  @override
  String get fivePhotoCheck => '5-Photo Check';

  @override
  String get fivePhotoCheckDesc => 'Comprehensive coverage of key areas';

  @override
  String get aiPoweredAnalysis => 'AI-Powered Analysis';

  @override
  String get aiPoweredAnalysisDesc => 'Advanced detection algorithms';

  @override
  String get hundredPercentPrivate => '100% Private';

  @override
  String get hundredPercentPrivateDesc =>
      'All processing happens on your device';

  @override
  String get getStarted => 'Get Started';

  @override
  String get beforeWeStart => 'Before We Start';

  @override
  String get preparationChecklist => 'Preparation Checklist';

  @override
  String get preparationSubtitle => 'For best results, please prepare:';

  @override
  String get preparationPhotoSequenceTitle => 'Views we\'ll guide you through';

  @override
  String get preparationPhotoSequenceHint =>
      'These are the usual angles for a full mouth check. After you save each photo, you can change the label if you captured a different area.';

  @override
  String get goodLighting => 'Good lighting';

  @override
  String get goodLightingDesc => 'Find a well-lit area or face a window';

  @override
  String get cleanMouth => 'Clean mouth';

  @override
  String get cleanMouthDesc => 'Rinse your mouth with water';

  @override
  String get removeLipProducts => 'Remove lip products';

  @override
  String get removeLipProductsDesc => 'Take off lipstick or lip gloss';

  @override
  String get mirrorNearby => 'Mirror nearby';

  @override
  String get mirrorNearbyDesc =>
      'Helpful for positioning, especially for palate';

  @override
  String get setAside2Minutes => 'Set aside 8–10 minutes';

  @override
  String get screeningTakes60Seconds => 'Each photo takes about 1-2 minutes';

  @override
  String get imReady => 'I\'m Ready';

  @override
  String photoXOfY(int current, String suffix) {
    return 'Photo $current of 5$suffix';
  }

  @override
  String get requiredLabel => ' • Required';

  @override
  String get optionalLabel => ' • Optional';

  @override
  String get skip => 'Skip';

  @override
  String get gallery => 'Gallery';

  @override
  String get tips => 'Tips';

  @override
  String get retake => 'Retake';

  @override
  String get usePhoto => 'Use Photo';

  @override
  String get capture => 'Capture';

  @override
  String failedToCapture(String error) {
    return 'Failed to capture: $error';
  }

  @override
  String failedToPickImage(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String failedToSavePhoto(String error) {
    return 'Failed to save photo: $error';
  }

  @override
  String get cropPhoto => 'Crop';

  @override
  String get cropImageTitle => 'Crop Image';

  @override
  String failedToCropImage(String error) {
    return 'Failed to crop image: $error';
  }

  @override
  String cropTooSmall(int size) {
    return 'Crop too small. Keep at least ${size}px on each side.';
  }

  @override
  String cropTightWarning(String percent) {
    return 'Cropped area is only $percent% of the previous image. Keep enough surrounding tissue for context.';
  }

  @override
  String get croppedPhotoNeedsRetake =>
      'Cropped photo quality is low. Please recrop or retake for better analysis.';

  @override
  String tipsForPhotoType(String photoType) {
    return 'Tips for $photoType';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get exitCheck => 'Exit Check?';

  @override
  String get exitCheckMessage =>
      'Are you sure you want to exit? Your progress will be lost.';

  @override
  String get continueButton => 'Continue';

  @override
  String get exit => 'Exit';

  @override
  String get rotate90 => 'Rotate 90°';

  @override
  String get close => 'Close';

  @override
  String get pinchToZoom => 'Pinch to zoom • Tap rotate to turn';

  @override
  String get tipFrontView1 => 'Use natural light or face a window';

  @override
  String get tipFrontView2 => 'Open your mouth wide to show teeth and gums';

  @override
  String get tipFrontView3 => 'Keep your face centered in the frame';

  @override
  String get tipFrontView4 => 'Hold the phone about 12 inches away';

  @override
  String get tipRightCheek1 => 'Gently pull your cheek outward with a finger';

  @override
  String get tipRightCheek2 =>
      'Try to fill most of the frame with the cheek tissue';

  @override
  String get tipRightCheek3 => 'Make sure the inner cheek surface is visible';

  @override
  String get tipRightCheek4 => 'Use flash if lighting is dim';

  @override
  String get tipLeftCheek1 => 'Gently pull your cheek outward with a finger';

  @override
  String get tipLeftCheek2 =>
      'Try to fill most of the frame with the cheek tissue';

  @override
  String get tipLeftCheek3 => 'Make sure the inner cheek surface is visible';

  @override
  String get tipLeftCheek4 => 'Use flash if lighting is dim';

  @override
  String get tipTongue1 => 'Stick your tongue out and up';

  @override
  String get tipTongue2 => 'Show both the top surface and edges';

  @override
  String get tipTongue3 => 'Try to relax your tongue for a natural position';

  @override
  String get tipTongue4 => 'Good lighting helps show texture details';

  @override
  String get tipPalate1 => 'Tilt your head back slightly';

  @override
  String get tipPalate2 => 'Open your mouth as wide as comfortable';

  @override
  String get tipPalate3 => 'Say \"Ahhh\" to lower your tongue';

  @override
  String get tipPalate4 => 'You may need help from someone else';

  @override
  String get instructionFrontView =>
      'Open mouth wide and show upper & lower teeth. Center your face in the frame.';

  @override
  String get instructionRightCheek =>
      'Pull right cheek outward gently. Get close to capture the inner tissue.';

  @override
  String get instructionLeftCheek =>
      'Pull left cheek outward gently. Get close to capture the inner tissue.';

  @override
  String get instructionTongue =>
      'Stick tongue out and up. Show the top surface and move side to side to show edges.';

  @override
  String get instructionPalate =>
      'Tilt head back slightly. Open mouth wide and say \"Ahhh\" to lower tongue.';

  @override
  String get readyToCapture => 'Ready to capture';

  @override
  String get adjustPosition => 'Adjust position';

  @override
  String get brightnessLabel => 'Brightness';

  @override
  String get focusLabel => 'Focus';

  @override
  String get contrastLabel => 'Contrast';

  @override
  String get qualityGood => 'Good';

  @override
  String get qualityRetake => 'Retake';

  @override
  String get feedbackMoveCloserToLight => 'Move closer to light source';

  @override
  String get feedbackHoldSteady => 'Hold phone steady';

  @override
  String get feedbackEnsureLighting => 'Ensure good lighting';

  @override
  String get feedbackPleaseRetake => 'Please retake photo';

  @override
  String get howItWorksTake5Photos => 'Take 5 Photos';

  @override
  String get howItWorksTake5PhotosDesc =>
      'Capture your mouth from different angles:\n\n• Front view (teeth & gums)\n• Right cheek\n• Left cheek\n• Tongue\n• Palate (roof of mouth)';

  @override
  String get howItWorksAIAnalysis => 'AI Analysis';

  @override
  String get howItWorksAIAnalysisDesc =>
      'Our AI examines your photos for:\n\n• Color changes\n• Unusual textures\n• Lesions or growths\n• Early warning signs\n\nAll analysis happens on your device.';

  @override
  String get howItWorksGetResults => 'Get Results';

  @override
  String get howItWorksGetResultsDesc =>
      'Receive instant results with:\n\n• Risk assessment (Low/Moderate/High)\n• Photo-by-photo breakdown\n• Personalized recommendations\n• Option to share with doctor';

  @override
  String get backButton => 'Back';

  @override
  String get nextButton => 'Next';

  @override
  String stepXOfY(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get noActiveSession => 'No active session';

  @override
  String get reviewPhotos => 'Review Photos';

  @override
  String get yourPhotos => 'Your Photos';

  @override
  String get frontViewRequired => 'Front view (required) must be acceptable';

  @override
  String get addMoreAngles => 'Add more angles for better results (optional)';

  @override
  String get capturedPhotosLookGood => 'Captured photos look good';

  @override
  String get needAtLeastTwoPhotosTitle => 'Add another angle';

  @override
  String get needAtLeastTwoPhotosSubtitle =>
      'Analysis needs at least two acceptable photos. Your front view counts as one—add one more clear angle.';

  @override
  String get needAtLeastTwoPhotosForAnalysis =>
      'Add at least one more acceptable photo. Analysis requires at least two angles.';

  @override
  String get replacePhoto => 'Replace';

  @override
  String get analyzeAllPhotos => 'Analyze All Photos';

  @override
  String analyzeNPhotos(int count) {
    return 'Analyze $count Photo(s)';
  }

  @override
  String get allPhotosGood => 'All photos look good!';

  @override
  String get frontViewOkOptional =>
      'Front view OK. Add or retake others (optional)';

  @override
  String get somePhotosNeedAttention => 'Some photos need attention';

  @override
  String get tipsForBetterPhotos => 'Tips for better photos';

  @override
  String get considerRetaking => 'Consider retaking';

  @override
  String get analyzingYourPhotos => 'Analyzing Your Photos';

  @override
  String get analysisStep1 => 'Checking image quality';

  @override
  String get analysisStep2 => 'Analyzing color patterns';

  @override
  String get analysisStep3 => 'Detecting texture abnormalities';

  @override
  String get analysisStep4 => 'Evaluating lesion markers';

  @override
  String get analysisStep5 => 'Calculating risk assessment';

  @override
  String get checkComplete => 'Check Complete';

  @override
  String get noConcerningSigns => 'No Concerning Signs Detected';

  @override
  String get someChangesDetected => 'Some Changes Detected';

  @override
  String get concerningChangesFound => 'Concerning Changes Found';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get areasNeedingAttention => 'Areas needing attention';

  @override
  String get viewDetails => 'View Details';

  @override
  String get done => 'Done';

  @override
  String get disclaimerResults =>
      'This screening is for early warning only and is not a medical diagnosis.';

  @override
  String get setReminderForNextCheck => 'Set Reminder for Next Check';

  @override
  String get findDentistNearMe => 'Find a Dentist Near Me';

  @override
  String get findSpecialistNow => 'Find Specialist Now';

  @override
  String get scheduleRoutineCheckup =>
      'Schedule routine dental checkup within 6 months';

  @override
  String get scheduleAppointment2to4Weeks =>
      'Schedule appointment with dentist within 2-4 weeks';

  @override
  String get urgentSeeSpecialist =>
      'URGENT: See oral surgeon or oncologist within 1 week';

  @override
  String get messageLow =>
      'Our AI didn\'t detect any suspicious changes in your oral cavity. Continue maintaining good oral hygiene habits.';

  @override
  String get messageModerate =>
      'We found some changes that may need professional review. Most changes are benign, but it\'s best to get a professional opinion.';

  @override
  String get messageHigh =>
      'Our AI detected changes that require professional evaluation. Please don\'t delay - early detection significantly improves outcomes.';

  @override
  String get unableToAnalyzePhotos => 'Unable to Analyze Photos';

  @override
  String nPhotosSkipped(int count) {
    return '$count Photo(s) Skipped';
  }

  @override
  String get photosDontAppearMouth =>
      'The photos don\'t appear to be of your mouth. Please retake with clear oral cavity photos.';

  @override
  String get somePhotosExcluded =>
      'Some photos weren\'t recognized as oral cavity images and were excluded.';

  @override
  String get detailedAnalysis => 'Detailed Analysis';

  @override
  String get shareReport => 'Share Report';

  @override
  String get howWeDecided => 'How we decided';

  @override
  String get analysisDetails => 'Analysis Details';

  @override
  String get downloadPdf => 'Download PDF';

  @override
  String get shareWithDoctor => 'Share with Doctor';

  @override
  String get photoByPhotoAnalysis => 'Photo-by-Photo Analysis';

  @override
  String get overallAssessment => 'Overall Assessment';

  @override
  String get confidence => 'Confidence';

  @override
  String get importantDisclaimer => 'Important Disclaimer';

  @override
  String get disclaimerDetailed =>
      'This initial check is for informational purposes only and is not a medical diagnosis. It provides an AI-assisted visual check to help determine whether professional evaluation may be advisable. Professional evaluation is essential for any concerning findings. Always consult qualified healthcare providers for medical advice.';

  @override
  String get photosNotRecognized => 'Photos Not Recognized';

  @override
  String nOfMPhotosNotRecognized(int count, int total) {
    return '$count of $total Photos Not Recognized';
  }

  @override
  String get retakeScreeningAll =>
      'None of your photos appear to be of the oral cavity. Please retake the screening with clear photos of your mouth.';

  @override
  String get retakeScreeningSome =>
      'Some photos don\'t appear to be of the oral cavity and were excluded from analysis. For better results, retake the screening.';

  @override
  String get checkHistory => 'Check History';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get completeFirstCheck =>
      'Complete your first check to start tracking your oral health over time';

  @override
  String get detailedHistoryComingSoon => 'Detailed history view coming soon';

  @override
  String get clearHistoryConfirmTitle => 'Clear History?';

  @override
  String get clearHistoryConfirmMessage =>
      'This will permanently delete all your screening history. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearAll => 'Clear All';

  @override
  String photosAnalyzedConfidence(int count, String percent) {
    return '$count photos analyzed • $percent% confidence';
  }

  @override
  String get trendImproved => 'Improved';

  @override
  String get trendIncreased => 'Increased';

  @override
  String get trendStable => 'Stable';

  @override
  String todayAt(String time) {
    return 'Today at $time';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String dateFormat(int day, int month, int year) {
    return '$day/$month/$year';
  }

  @override
  String get yourPrivacyMatters => 'Your Privacy Matters';

  @override
  String get heresHowWeProtectYou => 'Here\'s how we protect you';

  @override
  String get onDeviceProcessing => 'On-Device Processing';

  @override
  String get onDeviceProcessingDesc =>
      'All AI analysis happens entirely on your device. Your photos never leave your phone and are not uploaded to any server.';

  @override
  String get noCloudStorage => 'No Cloud Storage';

  @override
  String get noCloudStorageDesc =>
      'We don\'t store your photos or health data in the cloud. Everything stays locally on your device.';

  @override
  String get noTracking => 'No Tracking';

  @override
  String get noTrackingDesc =>
      'We don\'t track your usage or collect personal information. Your health screening is completely private.';

  @override
  String get yourControl => 'Your Control';

  @override
  String get yourControlDesc =>
      'You can delete your screening history at any time. All data is immediately removed.';

  @override
  String get medicalDisclaimer => 'Medical Disclaimer';

  @override
  String get disclaimerBody =>
      'This app provides an AI-assisted initial visual check of oral images to help determine whether professional evaluation may be advisable.\n\nIt is not a medical diagnosis tool and must not be used as the sole basis for medical decisions. The results are informational only and do not replace examination, diagnosis, or treatment by a qualified healthcare professional.\n\nIf you notice persistent symptoms, pain, bleeding, ulcers that do not heal, or any concerning changes, please consult a dentist, oral surgeon, or qualified healthcare provider promptly.\n\nBy continuing, you acknowledge that you understand this tool is intended to support early referral decisions and not to provide medical diagnosis.';

  @override
  String get disclaimerCheckbox =>
      'I understand this tool is intended to support early referral decisions and not to provide medical diagnosis';

  @override
  String get acceptContinue => 'Accept & Continue';

  @override
  String get statusNotStarted => 'Not Started';

  @override
  String get statusCapturing => 'Capturing Photos';

  @override
  String get statusReviewing => 'Reviewing Photos';

  @override
  String get statusAnalyzing => 'Analyzing';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get riskLow => 'Low Risk';

  @override
  String get riskModerate => 'Moderate Risk';

  @override
  String get riskHigh => 'High Risk';

  @override
  String get classFriendlyHealthy => 'No concerning changes detected (Healthy)';

  @override
  String get classFriendlyBenign => 'Minor, non-concerning changes (Benign)';

  @override
  String get classFriendlyOPMD =>
      'Changes that may need follow-up were noted (OPMD)';

  @override
  String get classFriendlyOCA =>
      'Findings that should be checked by a specialist (OCA)';

  @override
  String get classFriendlyUnknown =>
      'Image unclear or not suitable for assessment (Unknown)';

  @override
  String get classFriendlyUncertain =>
      'Awaiting clinical verification (Uncertain)';

  @override
  String get photoFrontView => 'Front View';

  @override
  String get photoRightCheek => 'Right Cheek';

  @override
  String get photoLeftCheek => 'Left Cheek';

  @override
  String get photoTongue => 'Tongue';

  @override
  String get photoPalate => 'Palate';

  @override
  String get photoLabelCurrentView => 'Current View';

  @override
  String get photoLabelChange => 'Change';

  @override
  String get photoLabelPickerTitle => 'Select photo label';

  @override
  String get photoLabelPickerHelper =>
      'Optional — override the default label for this photo';

  @override
  String get photoLabelCustom => 'Custom…';

  @override
  String get photoLabelCustomHint => 'e.g., Tongue – Upper';

  @override
  String get photoLabelCustomEmpty => 'Please enter a label';

  @override
  String get photoLabelSave => 'Save';

  @override
  String get notOral => 'Not oral';

  @override
  String get notAnalyzed => 'Not analyzed';

  @override
  String get qualityIssue => 'Quality issue';

  @override
  String confidenceLabel(String percent) {
    return 'Confidence: $percent%';
  }

  @override
  String labelConfidencePercent(String percent) {
    return 'Label confidence: $percent%';
  }

  @override
  String get oralCavityScreeningReport => 'Oral Cavity Initial Check Report';

  @override
  String generatedOn(String date) {
    return 'Generated on: $date';
  }

  @override
  String get reportDisclaimerBody =>
      'This initial check is for informational purposes only and is not a medical diagnosis. It provides an AI-assisted visual check to help determine whether professional evaluation may be advisable. The results are informational only and do not replace examination, diagnosis, or treatment by a qualified healthcare professional. Please consult qualified healthcare professionals for proper diagnosis and treatment.';

  @override
  String get shareReportSubject => 'Oral Cavity Initial Check Report';

  @override
  String shareReportText(String riskLevel) {
    return 'Here is my oral cavity initial check report. Risk level: $riskLevel';
  }

  @override
  String get riskLevelLabel => 'Risk Level:';

  @override
  String get screeningRemindersChannel => 'Screening Reminders';

  @override
  String get screeningRemindersDesc => 'Reminders for oral cavity screening';

  @override
  String get timeForOralScreening => 'Time for Oral Screening';

  @override
  String get threeMonthReminderBody =>
      'It\'s been 3 months since your last screening. Regular checkups help detect issues early.';

  @override
  String get testNotificationBody =>
      'This is a test notification from Oral Cavity Screening app';

  @override
  String get language => 'Language';

  @override
  String get currentLanguage => 'Current language';

  @override
  String get settings => 'Settings';

  @override
  String get labelConfidenceLabel => 'Label confidence';

  @override
  String get detailedTissueClassificationTitle =>
      'Detailed Tissue Classification';

  @override
  String get aiTissueClassificationSummarySubtitle =>
      'AI Tissue Classification Summary';

  @override
  String tissueInterpretationDominant(String label) {
    return 'The AI tissue-classification system identified a stronger visual match with the \"$label\" tissue-pattern category compared to other categories. This detailed classification supports interpretation of the analyzed oral images and does not change the screening recommendation.';
  }

  @override
  String get tissueInterpretationMixed =>
      'No single tissue-pattern category was strongly dominant across the analyzed images. The visual features identified by the AI overlapped multiple classification categories. This does not change the screening recommendation.';

  @override
  String get photoTableDetailPeakHeader => 'Detail peak';

  @override
  String detailModelPeakPercent(String percent) {
    return 'Detail model peak: $percent%';
  }

  @override
  String photosAnalyzedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos analyzed',
      one: '1 photo analyzed',
    );
    return '$_temp0';
  }

  @override
  String get reportPhotosAnalyzedLabel => 'Photos analyzed';

  @override
  String get photosStatLabel => 'Photos';

  @override
  String get urgencyLabel => 'Urgency';

  @override
  String actionConfidenceLabel(String level) {
    return 'Action confidence: $level';
  }

  @override
  String get checksDisagreedSuffix => '(checks disagreed)';

  @override
  String get urgencyRoutine => 'Routine (2–4 weeks)';

  @override
  String get urgencyPrompt => 'Prompt (1–2 weeks)';

  @override
  String get urgencyUrgent => 'Urgent (within 1 week)';

  @override
  String get urgencyRetakePhotos => 'Retake photos';

  @override
  String get eriQuestionnaireTitle => 'Tobacco Exposure';

  @override
  String get eriGateQuestion => 'Do you use any tobacco products?';

  @override
  String get eriGateHelper =>
      'This helps us provide better guidance. It does not provide a diagnosis. Your answers stay on this device.';

  @override
  String get eriYes => 'Yes';

  @override
  String get eriNo => 'No';

  @override
  String get eriTypeQuestion => 'What type of tobacco do you use?';

  @override
  String get eriSelectAll => 'Select all that apply';

  @override
  String get eriOtherSpecifyLabel => 'Please specify';

  @override
  String get eriOtherSpecifyHint => 'e.g., Khaini, Zarda...';

  @override
  String get eriOtherSpecifyError => 'Please specify the other tobacco type';

  @override
  String get eriTypeRequiredError => 'Please select at least one type';

  @override
  String get eriDurationQuestion => 'How long have you been using tobacco?';

  @override
  String get eriDurationRequiredError => 'Please select a duration';

  @override
  String get eriFrequencyQuestion => 'How many times per day (approx.)?';

  @override
  String get eriFrequencyHelper =>
      'For smoking: number of cigarettes/beedis. For chewing: number of times used.';

  @override
  String get eriFrequencyRequiredError => 'Please select a frequency';

  @override
  String get eriChangeAnswer => 'Change answer';

  @override
  String get eriDisclaimer =>
      'Exposure Risk Index is based on self-reported data and does not replace medical evaluation.';

  @override
  String get eriRiskSummary => 'Risk Summary';

  @override
  String get eriAiImageRisk => 'AI Image Risk';

  @override
  String get eriExposureRisk => 'Exposure Risk';

  @override
  String get eriFinalRecommendation => 'Final Recommendation';

  @override
  String get eriNotReported => 'Not reported';

  @override
  String get eriNoReportedTobaccoUse => 'No reported tobacco use';

  @override
  String eriTobaccoExposureWithLevel(String level) {
    return 'Tobacco Exposure: $level';
  }

  @override
  String eriRecommendedRescreenInterval(String interval) {
    return 'Recommended rescreen interval: $interval';
  }

  @override
  String get eriTobaccoExposureSummary => 'Tobacco Exposure Summary';

  @override
  String get eriTypeLabel => 'Type';

  @override
  String get eriOtherSpecifiedLabel => 'Other (specified)';

  @override
  String get eriDurationLabel => 'Duration';

  @override
  String get eriFrequencyLabel => 'Frequency';

  @override
  String get eriExposureRiskLevelLabel => 'Exposure Risk Level';

  @override
  String get eriExposureScoreLabel => 'Exposure Score';

  @override
  String get eriRescreenIntervalLabel => 'Rescreen Interval';

  @override
  String get eriReportField => 'Field';

  @override
  String get eriReportValue => 'Value';

  @override
  String get tobaccoTypeCigarette => 'Cigarette';

  @override
  String get tobaccoTypeBeedi => 'Beedi';

  @override
  String get tobaccoTypeHookah => 'Hookah';

  @override
  String get tobaccoTypeArecaNut => 'Areca Nut (Supari)';

  @override
  String get tobaccoTypePaanMasala => 'Paan Masala';

  @override
  String get tobaccoTypeGutka => 'Gutka';

  @override
  String get tobaccoTypeSurti => 'Surti';

  @override
  String get tobaccoTypeGul => 'Gul';

  @override
  String get tobaccoTypeOther => 'Other';

  @override
  String get durationLessThan1Year => 'Less than 1 year';

  @override
  String get duration1To5Years => '1–5 years';

  @override
  String get duration5To10Years => '5–10 years';

  @override
  String get duration10To20Years => '10–20 years';

  @override
  String get durationMoreThan20Years => 'More than 20 years';

  @override
  String get frequencyOccasional => 'Occasional';

  @override
  String get frequency1To5PerDay => '1–5 per day';

  @override
  String get frequency5To10PerDay => '5–10 per day';

  @override
  String get frequencyMoreThan10PerDay => 'More than 10 per day';

  @override
  String get exposureRiskLow => 'Low';

  @override
  String get exposureRiskModerate => 'Moderate';

  @override
  String get exposureRiskHigh => 'High';

  @override
  String get eriRecHighUrgentReferral =>
      'Tobacco exposure significantly elevates risk. Urgent specialist referral recommended.';

  @override
  String get eriMsgLongTermExposure =>
      'Based on reported long-term tobacco exposure, regular clinical evaluation is strongly recommended even if current image findings are not highly suspicious.';

  @override
  String get eriRecModerateConcern =>
      'Tobacco exposure adds to concern. Follow-up dental visit strongly advised.';

  @override
  String get eriMsgModerateExposure =>
      'Moderate tobacco exposure noted. Combined with image findings, timely clinical follow-up is recommended.';

  @override
  String get eriRecEnhancedMonitoring => 'Enhanced Monitoring Recommended';

  @override
  String get eriRecRescreen1Month =>
      'Due to high tobacco exposure, rescreen in 1 month instead of 3.';

  @override
  String get eriRecRescreen2Months =>
      'Due to moderate tobacco exposure, consider rescreening in 2 months.';

  @override
  String get eriFinalRecommendationElevatedNote =>
      'The final recommendation combines findings from the analyzed images with your reported tobacco exposure.';

  @override
  String get assessmentTitleInconclusiveRetake =>
      'Inconclusive – Retake Photos';

  @override
  String get assessmentTitleModerateReviewSuggested =>
      'Moderate – Review Suggested';

  @override
  String get assessmentTitleModerateNeedsAttention =>
      'Moderate – Needs Attention';

  @override
  String get assessmentTitleModerateNeedsReview => 'Moderate – Needs Review';

  @override
  String get assessmentMessageInconclusiveRetake =>
      'Photos were not clear/consistent enough to give a reliable result. Please retake in good light. If you have symptoms (pain, ulcer >2 weeks, bleeding), consult a clinician.';

  @override
  String get assessmentMessageLowRisk =>
      'No concerning signs detected in these photos.';

  @override
  String get assessmentMessageHighRisk =>
      'Findings may require urgent professional evaluation. Please consult a dentist/oral specialist within one week.';

  @override
  String get assessmentMessageModerateReviewSuggested =>
      'Most signs look non-concerning. One check suggested follow-up, so a routine dental review is recommended.';

  @override
  String get assessmentMessageModerateNeedsAttention =>
      'Some changes may need follow-up. Please arrange a dental review within 1–2 weeks.';

  @override
  String get assessmentMessageModerateNeedsReview =>
      'Some changes may need professional review. Please arrange a review within 1–2 weeks.';

  @override
  String get riskSubtypeTitleOcaDominant =>
      'High Risk – Urgent Clinical Review Suggested';

  @override
  String get riskSubtypeTitleOpmdDominant =>
      'Moderate to High Risk – Specialist Review Recommended';

  @override
  String get riskSubtypeTitleBenignDominant =>
      'Lesion Detected – Clinical Evaluation Advised';

  @override
  String get riskSubtypeMessageOcaDominant =>
      'Patterns consistent with potentially serious changes detected. Please consult a dentist or oral specialist promptly.';

  @override
  String get riskSubtypeMessageOpmdDominant =>
      'Early changes that may benefit from specialist review have been detected. Early detection significantly improves outcomes.';

  @override
  String get riskSubtypeMessageBenignDominant =>
      'A lesion was detected that appears non-threatening but should be evaluated by a healthcare professional to confirm.';

  @override
  String get perPhotoLabelPotentialConcern => 'Potential Concern';

  @override
  String get perPhotoLabelReviewRecommended => 'Review Recommended';

  @override
  String get perPhotoLabelHealthy => 'Healthy';

  @override
  String get perPhotoLabelRetakeOrReview => 'Retake or further analysis needed';

  @override
  String get perPhotoNoteHighConflict =>
      'Screening detected risk factors. Visual pattern appears healthy, but professional review is recommended.';

  @override
  String get perPhotoNoteModerateConflict =>
      'Subtle signs detected. Visual pattern: Healthy. Consider a follow-up.';

  @override
  String get perPhotoNoteHighConflictBenign =>
      'Screening detected risk factors. Visual pattern appears benign. Professional review is recommended.';

  @override
  String get perPhotoNoteModerateConflictBenign =>
      'Subtle signs detected. Visual pattern: Benign. Consider a follow-up.';

  @override
  String perPhotoVisualDetailMostly(String label, String percent) {
    return 'Visual Detail: Mostly $label ($percent%)';
  }

  @override
  String photosCapturedGoodQuality(int count) {
    return '$count/5 photos captured with good quality';
  }

  @override
  String photosMayNeedRetake(int count) {
    return '$count photo(s) may need retaking for best results';
  }

  @override
  String get recNoConcerningSigns => 'No concerning signs detected';

  @override
  String get recContinueOralHygiene => 'Continue regular oral hygiene';

  @override
  String get recScheduleRoutineCheckup => 'Schedule routine dental checkup';

  @override
  String get recRescreen3Months => 'Rescreen in 3 months';

  @override
  String recNeedClearerPhotosFor(String list) {
    return 'Need clearer photos for: $list';
  }

  @override
  String get recSomeChangesNeedAttention =>
      'Some changes detected that need attention';

  @override
  String get recSchedule2to4Weeks =>
      'Schedule appointment with dentist within 2-4 weeks';

  @override
  String get recAvoidTobaccoAlcohol => 'Avoid tobacco and alcohol';

  @override
  String get recMonitorChangesClosely => 'Monitor any changes closely';

  @override
  String recPaySpecialAttentionTo(String list) {
    return 'Pay special attention to: $list';
  }

  @override
  String get recConcerningChangesDetected => 'Concerning changes detected';

  @override
  String get recUrgentSeeSpecialist =>
      'URGENT: See oral surgeon or oncologist within 1 week';

  @override
  String get recBringReportToAppointment =>
      'Bring this report to your appointment';

  @override
  String get recEarlyDetectionImprovesOutcomes =>
      'Early detection significantly improves outcomes';

  @override
  String get check1Referral => 'Check 1 (referral)';

  @override
  String get check2Detail => 'Check 2 (detail)';

  @override
  String check2DetailWithConfidence(String label, String percent) {
    return 'Check 2 (detail): $label ($percent% confidence)';
  }

  @override
  String get verdictBothLowRisk =>
      'Both checks suggest low risk. No immediate follow-up needed; routine check-ups are still recommended.';

  @override
  String verdictBothSomeConcern(String label) {
    return 'Both checks suggest some concern ($label). We recommend follow-up with a healthcare provider.';
  }

  @override
  String get verdictReferralAppropriate =>
      'Both checks suggest referral is appropriate. Please see a healthcare provider for further evaluation.';

  @override
  String verdictDifferentSignals(String risk) {
    return 'The two checks gave different signals. We show $risk and recommend follow-up so a professional can decide.';
  }

  @override
  String verdictCouldNotAssess(String note) {
    return 'This photo could not be assessed. $note';
  }

  @override
  String get verdictPleaseRetake => 'Please retake.';
}
