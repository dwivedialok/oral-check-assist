// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Revisión de Cavidad Oral';

  @override
  String get loadingModels => 'Cargando modelos de IA...';

  @override
  String get failedToInitialize => 'Error al inicializar';

  @override
  String get retry => 'Reintentar';

  @override
  String get navHome => 'Inicio';

  @override
  String get navDebug => 'Depurar';

  @override
  String get navQuickCheck => 'Revisión rápida';

  @override
  String get quickCheckTitle => 'Revisión rápida';

  @override
  String get quickCheckDesc => 'Una foto para un resultado rápido';

  @override
  String get quickCheckAnalyze => 'Analizar';

  @override
  String get quickCheckAnalyzing => 'Analizando…';

  @override
  String get quickCheckExplainResult => 'Entender el resultado';

  @override
  String get quickCheckTakeOrSelectPhoto => 'Tomar o elegir una foto';

  @override
  String get quickCheckModelSelection => 'Modelo';

  @override
  String get quickCheckSelectModel => 'Seleccionar modelo';

  @override
  String get quickCheckCamera => 'Cámara';

  @override
  String get quickCheckClassificationResult => 'Resultado';

  @override
  String get oralHealthCheck => 'Revisión de Salud Oral';

  @override
  String get startNewCheck => 'Nueva Revisión';

  @override
  String get takeFivePhotosDesc =>
      'Toma 5 fotos de tu boca para la detección temprana con IA.';

  @override
  String get beginCheck => 'Comenzar Revisión';

  @override
  String get fullyPrivate => 'Totalmente privado';

  @override
  String get fullCheckDuration => 'Revisión completa: ~8–10 minutos';

  @override
  String get fullCheckHelperNote => 'Mejor si alguien te toma las fotos';

  @override
  String get quickCheckDurationLabel => 'Revisión rápida: ~2 minutos';

  @override
  String get quickCheckPreliminaryLine =>
      'Mirada preliminar rápida en ~2 minutos';

  @override
  String get whyFivePhotos => '¿Por qué 5 fotos?';

  @override
  String get ninetyTwoPercentMoreAccurate => '92% más preciso';

  @override
  String get multipleAnglesDesc =>
      'Varios ángulos cubren mejor las zonas de riesgo';

  @override
  String get howItWorks => 'Cómo Funciona';

  @override
  String get stepPrepare => 'Preparar';

  @override
  String get stepPrepareDesc => 'Lista rápida';

  @override
  String get stepCapture => 'Capturar';

  @override
  String get stepCaptureDesc => '5 fotos guiadas';

  @override
  String get stepAnalyze => 'Analizar';

  @override
  String get stepAnalyzeDesc => 'IA revisa';

  @override
  String get stepResults => 'Resultados';

  @override
  String get stepResultsDesc => 'Informe al instante';

  @override
  String get recentChecks => 'Revisiones Recientes';

  @override
  String get viewAll => 'Ver Todo';

  @override
  String get historyComingSoon => 'Historial próximamente';

  @override
  String get noChecksYet => 'Aún no hay revisiones';

  @override
  String get startFirstCheckDesc =>
      'Haz tu primera revisión para seguir tu salud oral';

  @override
  String get analysisFailed => 'Análisis fallido';

  @override
  String get reminderComingSoon => 'Recordatorios próximamente';

  @override
  String get findSpecialistComingSoon => 'Buscar especialista próximamente';

  @override
  String get shareComingSoon => 'Compartir próximamente';

  @override
  String get pdfComingSoon => 'Descargar PDF próximamente';

  @override
  String get welcomeOralCavityCheck => 'Revisión de\nCavidad Oral';

  @override
  String get welcomeSubtitle =>
      'Detección temprana con IA\npara mejor salud oral';

  @override
  String get fivePhotoCheck => 'Revisión de 5 Fotos';

  @override
  String get fivePhotoCheckDesc => 'Cobertura de zonas clave';

  @override
  String get aiPoweredAnalysis => 'Análisis con IA';

  @override
  String get aiPoweredAnalysisDesc => 'Algoritmos de detección avanzados';

  @override
  String get hundredPercentPrivate => '100% Privado';

  @override
  String get hundredPercentPrivateDesc => 'Todo se procesa en tu dispositivo';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get beforeWeStart => 'Antes de Empezar';

  @override
  String get preparationChecklist => 'Lista de Preparación';

  @override
  String get preparationSubtitle =>
      'Para mejores resultados, prepara lo siguiente:';

  @override
  String get preparationPhotoSequenceTitle => 'Vistas que te guiaremos';

  @override
  String get preparationPhotoSequenceHint =>
      'Son los ángulos habituales para revisar toda la boca. Después de guardar cada foto, puedes cambiar la etiqueta si capturaste otra zona.';

  @override
  String get goodLighting => 'Buena luz';

  @override
  String get goodLightingDesc => 'Busca luz natural o una ventana';

  @override
  String get cleanMouth => 'Boca limpia';

  @override
  String get cleanMouthDesc => 'Enjuaga con agua';

  @override
  String get removeLipProducts => 'Quita maquillaje de labios';

  @override
  String get removeLipProductsDesc => 'Sin labial ni brillo';

  @override
  String get mirrorNearby => 'Espejo a mano';

  @override
  String get mirrorNearbyDesc => 'Ayuda para posicionar, sobre todo el paladar';

  @override
  String get setAside2Minutes => 'Reserva 8–10 minutos';

  @override
  String get screeningTakes60Seconds =>
      'Cada foto toma aproximadamente 1-2 minutos';

  @override
  String get imReady => 'Estoy Listo';

  @override
  String photoXOfY(int current, String suffix) {
    return 'Foto $current de 5$suffix';
  }

  @override
  String get requiredLabel => ' • Requerida';

  @override
  String get optionalLabel => ' • Opcional';

  @override
  String get skip => 'Omitir';

  @override
  String get gallery => 'Galería';

  @override
  String get tips => 'Consejos';

  @override
  String get retake => 'Repetir';

  @override
  String get usePhoto => 'Usar Foto';

  @override
  String get capture => 'Capturar';

  @override
  String failedToCapture(String error) {
    return 'Error al capturar: $error';
  }

  @override
  String failedToPickImage(String error) {
    return 'Error al elegir imagen: $error';
  }

  @override
  String failedToSavePhoto(String error) {
    return 'Error al guardar foto: $error';
  }

  @override
  String get cropPhoto => 'Recortar';

  @override
  String get cropImageTitle => 'Recortar imagen';

  @override
  String failedToCropImage(String error) {
    return 'Error al recortar imagen: $error';
  }

  @override
  String cropTooSmall(int size) {
    return 'Recorte demasiado pequeño. Mantén al menos ${size}px por lado.';
  }

  @override
  String cropTightWarning(String percent) {
    return 'El recorte usa solo $percent% del área anterior. Mantén tejido alrededor para contexto.';
  }

  @override
  String get croppedPhotoNeedsRetake =>
      'La calidad tras recortar es baja. Vuelve a recortar o repite la foto.';

  @override
  String tipsForPhotoType(String photoType) {
    return 'Consejos para $photoType';
  }

  @override
  String get gotIt => 'Entendido';

  @override
  String get exitCheck => '¿Salir de la Revisión?';

  @override
  String get exitCheckMessage => '¿Seguro? Se perderá el progreso.';

  @override
  String get continueButton => 'Continuar';

  @override
  String get exit => 'Salir';

  @override
  String get rotate90 => 'Rotar 90°';

  @override
  String get close => 'Cerrar';

  @override
  String get pinchToZoom => 'Pellizca para zoom • Toca para rotar';

  @override
  String get tipFrontView1 => 'Usa luz natural o ponte frente a una ventana';

  @override
  String get tipFrontView2 => 'Abre bien la boca mostrando dientes y encías';

  @override
  String get tipFrontView3 => 'Centra tu cara en el encuadre';

  @override
  String get tipFrontView4 => 'Mantén el teléfono a unos 30 cm';

  @override
  String get tipRightCheek1 => 'Tira del carrillo derecho suavemente';

  @override
  String get tipRightCheek2 => 'Llena el encuadre con el tejido del carrillo';

  @override
  String get tipRightCheek3 => 'Que se vea la parte interna del carrillo';

  @override
  String get tipRightCheek4 => 'Usa flash si hay poca luz';

  @override
  String get tipLeftCheek1 => 'Tira del carrillo izquierdo suavemente';

  @override
  String get tipLeftCheek2 => 'Llena el encuadre con el tejido del carrillo';

  @override
  String get tipLeftCheek3 => 'Que se vea la parte interna del carrillo';

  @override
  String get tipLeftCheek4 => 'Usa flash si hay poca luz';

  @override
  String get tipTongue1 => 'Saca la lengua y súbela';

  @override
  String get tipTongue2 => 'Muestra la superficie y los bordes';

  @override
  String get tipTongue3 => 'Relaja la lengua';

  @override
  String get tipTongue4 => 'Buena luz para ver el relieve';

  @override
  String get tipPalate1 => 'Inclina la cabeza hacia atrás';

  @override
  String get tipPalate2 => 'Abre la boca todo lo que puedas';

  @override
  String get tipPalate3 => 'Di \"Ah\" para bajar la lengua';

  @override
  String get tipPalate4 => 'Puede que necesites ayuda';

  @override
  String get instructionFrontView =>
      'Abre bien la boca y muestra dientes superiores e inferiores. Centra tu cara en el encuadre.';

  @override
  String get instructionRightCheek =>
      'Tira del carrillo derecho suavemente. Acércate para captar el tejido interno.';

  @override
  String get instructionLeftCheek =>
      'Tira del carrillo izquierdo suavemente. Acércate para captar el tejido interno.';

  @override
  String get instructionTongue =>
      'Saca la lengua y súbela. Muestra la superficie y muévela a los lados para mostrar los bordes.';

  @override
  String get instructionPalate =>
      'Inclina la cabeza hacia atrás. Abre la boca y di \"Ah\" para bajar la lengua.';

  @override
  String get readyToCapture => 'Listo para capturar';

  @override
  String get adjustPosition => 'Ajusta la posición';

  @override
  String get brightnessLabel => 'Brillo';

  @override
  String get focusLabel => 'Enfoque';

  @override
  String get contrastLabel => 'Contraste';

  @override
  String get qualityGood => 'Bien';

  @override
  String get qualityRetake => 'Repetir';

  @override
  String get feedbackMoveCloserToLight => 'Acércate a la luz';

  @override
  String get feedbackHoldSteady => 'Sujeta el teléfono firme';

  @override
  String get feedbackEnsureLighting => 'Asegura buena iluminación';

  @override
  String get feedbackPleaseRetake => 'Repite la foto';

  @override
  String get howItWorksTake5Photos => 'Toma 5 Fotos';

  @override
  String get howItWorksTake5PhotosDesc =>
      'Captura tu boca desde distintos ángulos:\n\n• Vista frontal (dientes y encías)\n• Carrillo derecho\n• Carrillo izquierdo\n• Lengua\n• Paladar (techo de la boca)';

  @override
  String get howItWorksAIAnalysis => 'Análisis con IA';

  @override
  String get howItWorksAIAnalysisDesc =>
      'Nuestra IA revisa tus fotos en busca de:\n\n• Cambios de color\n• Texturas inusuales\n• Lesiones o bultos\n• Signos de alerta temprana\n\nTodo el análisis se hace en tu dispositivo.';

  @override
  String get howItWorksGetResults => 'Obtén Resultados';

  @override
  String get howItWorksGetResultsDesc =>
      'Recibe resultados al instante:\n\n• Valoración de riesgo (Bajo/Moderado/Alto)\n• Análisis foto a foto\n• Recomendaciones personalizadas\n• Opción de compartir con el médico';

  @override
  String get backButton => 'Atrás';

  @override
  String get nextButton => 'Siguiente';

  @override
  String stepXOfY(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get noActiveSession => 'No hay sesión activa';

  @override
  String get reviewPhotos => 'Revisar Fotos';

  @override
  String get yourPhotos => 'Tus Fotos';

  @override
  String get frontViewRequired =>
      'Vista frontal (requerida) debe ser aceptable';

  @override
  String get addMoreAngles => 'Añade más ángulos (opcional)';

  @override
  String get capturedPhotosLookGood => 'Las fotos capturadas se ven bien';

  @override
  String get needAtLeastTwoPhotosTitle => 'Añade otro ángulo';

  @override
  String get needAtLeastTwoPhotosSubtitle =>
      'El análisis necesita al menos dos fotos aceptables. La vista frontal cuenta como una; añade otro ángulo claro.';

  @override
  String get needAtLeastTwoPhotosForAnalysis =>
      'Añade al menos otra foto aceptable. Se requieren al menos dos ángulos.';

  @override
  String get replacePhoto => 'Sustituir';

  @override
  String get analyzeAllPhotos => 'Analizar Todas las Fotos';

  @override
  String analyzeNPhotos(int count) {
    return 'Analizar $count Foto(s)';
  }

  @override
  String get allPhotosGood => '¡Todas las fotos bien!';

  @override
  String get frontViewOkOptional =>
      'Vista frontal OK. Añade o repite otras (opcional)';

  @override
  String get somePhotosNeedAttention => 'Algunas fotos necesitan atención';

  @override
  String get tipsForBetterPhotos => 'Consejos para mejores fotos';

  @override
  String get considerRetaking => 'Valora repetir';

  @override
  String get analyzingYourPhotos => 'Analizando Tus Fotos';

  @override
  String get analysisStep1 => 'Comprobando calidad de imagen';

  @override
  String get analysisStep2 => 'Analizando patrones de color';

  @override
  String get analysisStep3 => 'Detectando anomalías de textura';

  @override
  String get analysisStep4 => 'Evaluando marcadores de lesión';

  @override
  String get analysisStep5 => 'Calculando riesgo';

  @override
  String get checkComplete => 'Revisión Completada';

  @override
  String get noConcerningSigns => 'Sin Signos Preocupantes';

  @override
  String get someChangesDetected => 'Algunos Cambios Detectados';

  @override
  String get concerningChangesFound => 'Cambios Preocupantes Encontrados';

  @override
  String get recommendations => 'Recomendaciones';

  @override
  String get areasNeedingAttention => 'Zonas a revisar';

  @override
  String get viewDetails => 'Ver Detalles';

  @override
  String get done => 'Listo';

  @override
  String get disclaimerResults =>
      'Esta revisión es solo orientativa y no sustituye un diagnóstico médico.';

  @override
  String get setReminderForNextCheck => 'Recordatorio para la Próxima Revisión';

  @override
  String get findDentistNearMe => 'Buscar Dentista Cerca';

  @override
  String get findSpecialistNow => 'Buscar Especialista Ya';

  @override
  String get scheduleRoutineCheckup => 'Revisión dental rutinaria en 6 meses';

  @override
  String get scheduleAppointment2to4Weeks => 'Cita con dentista en 2-4 semanas';

  @override
  String get urgentSeeSpecialist =>
      'URGENTE: Ver cirujano oral u oncólogo en 1 semana';

  @override
  String get messageLow =>
      'No detectamos cambios sospechosos. Sigue con buena higiene oral.';

  @override
  String get messageModerate =>
      'Encontramos cambios que conviene revisar. La mayoría son benignos.';

  @override
  String get messageHigh =>
      'Detectamos cambios que requieren evaluación profesional. No retrases.';

  @override
  String get unableToAnalyzePhotos => 'No se pudieron analizar las fotos';

  @override
  String nPhotosSkipped(int count) {
    return '$count Foto(s) omitida(s)';
  }

  @override
  String get photosDontAppearMouth =>
      'Las fotos no parecen de tu boca. Repite con fotos claras de la cavidad oral.';

  @override
  String get somePhotosExcluded =>
      'Algunas fotos no se reconocieron como cavidad oral y se excluyeron.';

  @override
  String get detailedAnalysis => 'Análisis Detallado';

  @override
  String get shareReport => 'Compartir Informe';

  @override
  String get howWeDecided => 'Cómo lo decidimos';

  @override
  String get analysisDetails => 'Detalles del análisis';

  @override
  String get downloadPdf => 'Descargar PDF';

  @override
  String get shareWithDoctor => 'Compartir con el médico';

  @override
  String get photoByPhotoAnalysis => 'Análisis Foto a Foto';

  @override
  String get overallAssessment => 'Valoración General';

  @override
  String get confidence => 'Confianza';

  @override
  String get importantDisclaimer => 'Aviso Importante';

  @override
  String get disclaimerDetailed =>
      'Esta revisión es solo orientativa y no sustituye un diagnóstico médico. Es esencial una evaluación profesional ante hallazgos preocupantes. Consulte siempre a profesionales sanitarios.';

  @override
  String get photosNotRecognized => 'Fotos No Reconocidas';

  @override
  String nOfMPhotosNotRecognized(int count, int total) {
    return '$count de $total Fotos No Reconocidas';
  }

  @override
  String get retakeScreeningAll =>
      'Ninguna foto parece de la cavidad oral. Repite la revisión con fotos claras de tu boca.';

  @override
  String get retakeScreeningSome =>
      'Algunas fotos no parecen de la cavidad oral y se excluyeron. Para mejores resultados, repite la revisión.';

  @override
  String get checkHistory => 'Historial de Revisiones';

  @override
  String get clearHistory => 'Borrar Historial';

  @override
  String get completeFirstCheck =>
      'Completa tu primera revisión para seguir tu salud oral';

  @override
  String get detailedHistoryComingSoon =>
      'Vista detallada del historial próximamente';

  @override
  String get clearHistoryConfirmTitle => '¿Borrar Historial?';

  @override
  String get clearHistoryConfirmMessage =>
      'Se borrará todo tu historial de revisiones. No se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clearAll => 'Borrar Todo';

  @override
  String photosAnalyzedConfidence(int count, String percent) {
    return '$count fotos analizadas • $percent% confianza';
  }

  @override
  String get trendImproved => 'Mejorado';

  @override
  String get trendIncreased => 'Aumentado';

  @override
  String get trendStable => 'Estable';

  @override
  String todayAt(String time) {
    return 'Hoy a las $time';
  }

  @override
  String get yesterday => 'Ayer';

  @override
  String daysAgo(int count) {
    return 'Hace $count días';
  }

  @override
  String dateFormat(int day, int month, int year) {
    return '$day/$month/$year';
  }

  @override
  String get yourPrivacyMatters => 'Tu Privacidad Importa';

  @override
  String get heresHowWeProtectYou => 'Así te protegemos';

  @override
  String get onDeviceProcessing => 'Procesamiento en el Dispositivo';

  @override
  String get onDeviceProcessingDesc =>
      'Todo el análisis de IA se hace en tu dispositivo. Tus fotos no salen del teléfono.';

  @override
  String get noCloudStorage => 'Sin Almacenamiento en la Nube';

  @override
  String get noCloudStorageDesc =>
      'No guardamos fotos ni datos de salud en la nube. Todo queda en tu dispositivo.';

  @override
  String get noTracking => 'Sin Seguimiento';

  @override
  String get noTrackingDesc =>
      'No rastreamos tu uso ni recopilamos datos personales. Tu revisión es privada.';

  @override
  String get yourControl => 'Tu Control';

  @override
  String get yourControlDesc =>
      'Puedes borrar tu historial cuando quieras. Los datos se eliminan al instante.';

  @override
  String get medicalDisclaimer => 'Aviso Médico';

  @override
  String get disclaimerBody =>
      'Esta app es solo para revisión y no sustituye un diagnóstico médico. Está pensada para detección temprana y no debe usarse como único criterio. Consulte siempre a profesionales sanitarios.';

  @override
  String get disclaimerCheckbox =>
      'Entiendo que es una herramienta de revisión y no un diagnóstico médico';

  @override
  String get acceptContinue => 'Aceptar y Continuar';

  @override
  String get statusNotStarted => 'No Iniciado';

  @override
  String get statusCapturing => 'Capturando Fotos';

  @override
  String get statusReviewing => 'Revisando Fotos';

  @override
  String get statusAnalyzing => 'Analizando';

  @override
  String get statusCompleted => 'Completado';

  @override
  String get statusFailed => 'Fallido';

  @override
  String get riskLow => 'Riesgo Bajo';

  @override
  String get riskModerate => 'Riesgo Moderado';

  @override
  String get riskHigh => 'Riesgo Alto';

  @override
  String get classFriendlyHealthy => 'No se ven señales preocupantes (Healthy)';

  @override
  String get classFriendlyBenign =>
      'Cambios leves, no parecen preocupantes (Benign)';

  @override
  String get classFriendlyOPMD => 'Se ven cambios que conviene revisar (OPMD)';

  @override
  String get classFriendlyOCA => 'Conviene que lo revise un especialista (OCA)';

  @override
  String get classFriendlyUnknown =>
      'La foto no es clara / no se pudo evaluar bien (Unknown)';

  @override
  String get classFriendlyUncertain =>
      'Pendiente de verificación clínica (Uncertain)';

  @override
  String get photoFrontView => 'Vista Frontal';

  @override
  String get photoRightCheek => 'Carrillo Derecho';

  @override
  String get photoLeftCheek => 'Carrillo Izquierdo';

  @override
  String get photoTongue => 'Lengua';

  @override
  String get photoPalate => 'Paladar';

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
  String get notOral => 'No oral';

  @override
  String get notAnalyzed => 'No analizado';

  @override
  String get qualityIssue => 'Problema de calidad';

  @override
  String confidenceLabel(String percent) {
    return 'Confianza: $percent%';
  }

  @override
  String labelConfidencePercent(String percent) {
    return 'Confianza de etiqueta: $percent%';
  }

  @override
  String get oralCavityScreeningReport => 'Informe de Revisión de Cavidad Oral';

  @override
  String generatedOn(String date) {
    return 'Generado el: $date';
  }

  @override
  String get reportDisclaimerBody =>
      'Esta revisión es solo orientativa y no sustituye un diagnóstico médico. Consulte a profesionales sanitarios para diagnóstico y tratamiento.';

  @override
  String get shareReportSubject => 'Informe de Revisión de Cavidad Oral';

  @override
  String shareReportText(String riskLevel) {
    return 'Aquí está mi informe de revisión de cavidad oral. Nivel de riesgo: $riskLevel';
  }

  @override
  String get riskLevelLabel => 'Nivel de Riesgo:';

  @override
  String get screeningRemindersChannel => 'Recordatorios de Revisión';

  @override
  String get screeningRemindersDesc =>
      'Recordatorios para revisión de cavidad oral';

  @override
  String get timeForOralScreening => 'Hora de Revisión Oral';

  @override
  String get threeMonthReminderBody =>
      'Han pasado 3 meses desde tu última revisión. Las revisiones ayudan a detectar problemas a tiempo.';

  @override
  String get testNotificationBody =>
      'Notificación de prueba de la app de Revisión de Cavidad Oral';

  @override
  String get language => 'Idioma';

  @override
  String get currentLanguage => 'Idioma actual';

  @override
  String get settings => 'Ajustes';

  @override
  String get labelConfidenceLabel => 'Confianza en la etiqueta';

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
  String get photosStatLabel => 'Fotos';

  @override
  String get urgencyLabel => 'Urgencia';

  @override
  String actionConfidenceLabel(String level) {
    return 'Confianza en la acción: $level';
  }

  @override
  String get checksDisagreedSuffix => '(las comprobaciones no coinciden)';

  @override
  String get urgencyRoutine => 'Rutina (2–4 semanas)';

  @override
  String get urgencyPrompt => 'Pronto (1–2 semanas)';

  @override
  String get urgencyUrgent => 'Urgente (en 1 semana)';

  @override
  String get urgencyRetakePhotos => 'Repetir fotos';

  @override
  String get eriQuestionnaireTitle => 'Uso de tabaco';

  @override
  String get eriGateQuestion => '¿Usas algún producto de tabaco?';

  @override
  String get eriGateHelper =>
      'Esto nos ayuda a darte mejor orientación. No es un diagnóstico. Tus respuestas se guardan en este dispositivo.';

  @override
  String get eriYes => 'Sí';

  @override
  String get eriNo => 'No';

  @override
  String get eriTypeQuestion => '¿Qué tipo de tabaco usas?';

  @override
  String get eriSelectAll => 'Selecciona todo lo que aplique';

  @override
  String get eriOtherSpecifyLabel => 'Especifica';

  @override
  String get eriOtherSpecifyHint => 'ej.: Khaini, Zarda...';

  @override
  String get eriOtherSpecifyError =>
      'Si eliges \"Otro\", por favor escribe cuál';

  @override
  String get eriTypeRequiredError => 'Selecciona al menos un tipo';

  @override
  String get eriDurationQuestion => '¿Desde hace cuánto tiempo usas tabaco?';

  @override
  String get eriDurationRequiredError => 'Selecciona una duración';

  @override
  String get eriFrequencyQuestion => '¿Cuántas veces al día (aprox.)?';

  @override
  String get eriFrequencyHelper =>
      'Para fumar: número de cigarrillos/beedis. Para masticar: número de veces que lo usas.';

  @override
  String get eriFrequencyRequiredError => 'Selecciona una frecuencia';

  @override
  String get eriChangeAnswer => 'Cambiar respuesta';

  @override
  String get eriDisclaimer =>
      'El Exposure Risk Index se basa en lo que reportas y no reemplaza una evaluación médica.';

  @override
  String get eriRiskSummary => 'Resumen de riesgo';

  @override
  String get eriAiImageRisk => 'Riesgo de imagen AI';

  @override
  String get eriExposureRisk => 'Riesgo por exposición';

  @override
  String get eriFinalRecommendation => 'Recomendación final';

  @override
  String get eriNotReported => 'No reportado';

  @override
  String get eriNoReportedTobaccoUse => 'No se reportó uso de tabaco';

  @override
  String eriTobaccoExposureWithLevel(String level) {
    return 'Exposición a tabaco: $level';
  }

  @override
  String eriRecommendedRescreenInterval(String interval) {
    return 'Intervalo recomendado para repetir revisión: $interval';
  }

  @override
  String get eriTobaccoExposureSummary => 'Resumen de exposición a tabaco';

  @override
  String get eriTypeLabel => 'Tipo';

  @override
  String get eriOtherSpecifiedLabel => 'Otro (especificado)';

  @override
  String get eriDurationLabel => 'Duración';

  @override
  String get eriFrequencyLabel => 'Frecuencia';

  @override
  String get eriExposureRiskLevelLabel => 'Nivel de riesgo por exposición';

  @override
  String get eriExposureScoreLabel => 'Puntaje de exposición';

  @override
  String get eriRescreenIntervalLabel => 'Intervalo de nueva revisión';

  @override
  String get eriReportField => 'Campo';

  @override
  String get eriReportValue => 'Valor';

  @override
  String get tobaccoTypeCigarette => 'Cigarrillo';

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
  String get tobaccoTypeOther => 'Otro';

  @override
  String get durationLessThan1Year => 'Menos de 1 año';

  @override
  String get duration1To5Years => '1–5 años';

  @override
  String get duration5To10Years => '5–10 años';

  @override
  String get duration10To20Years => '10–20 años';

  @override
  String get durationMoreThan20Years => 'Más de 20 años';

  @override
  String get frequencyOccasional => 'Ocasional';

  @override
  String get frequency1To5PerDay => '1–5 al día';

  @override
  String get frequency5To10PerDay => '5–10 al día';

  @override
  String get frequencyMoreThan10PerDay => 'Más de 10 al día';

  @override
  String get exposureRiskLow => 'Bajo';

  @override
  String get exposureRiskModerate => 'Moderado';

  @override
  String get exposureRiskHigh => 'Alto';

  @override
  String get eriRecHighUrgentReferral =>
      'La exposición al tabaco aumenta mucho el riesgo. Se recomienda derivación urgente con especialista.';

  @override
  String get eriMsgLongTermExposure =>
      'Por exposición prolongada al tabaco, se recomienda evaluación clínica regular aunque la imagen no parezca muy sospechosa.';

  @override
  String get eriRecModerateConcern =>
      'La exposición al tabaco aumenta la preocupación. Se recomienda seguimiento dental.';

  @override
  String get eriMsgModerateExposure =>
      'Se observó exposición moderada al tabaco. Junto con la imagen, se recomienda seguimiento clínico oportuno.';

  @override
  String get eriRecEnhancedMonitoring => 'Se recomienda monitoreo reforzado';

  @override
  String get eriRecRescreen1Month =>
      'Por alta exposición al tabaco, repetir revisión en 1 mes en lugar de 3.';

  @override
  String get eriRecRescreen2Months =>
      'Por exposición moderada al tabaco, considera repetir revisión en 2 meses.';

  @override
  String get eriFinalRecommendationElevatedNote =>
      'La recomendación final se elevó por alta exposición reportada.';

  @override
  String get assessmentTitleInconclusiveRetake => 'Inconcluso – Repetir fotos';

  @override
  String get assessmentTitleModerateReviewSuggested =>
      'Moderado – Revisión sugerida';

  @override
  String get assessmentTitleModerateNeedsAttention =>
      'Moderado – Requiere atención';

  @override
  String get assessmentTitleModerateNeedsReview =>
      'Moderado – Requiere revisión';

  @override
  String get assessmentMessageInconclusiveRetake =>
      'Las fotos no fueron lo bastante claras o consistentes para un resultado fiable. Repítalas con buena luz. Si tiene síntomas (dolor, úlcera >2 semanas, sangrado), consulte a un profesional.';

  @override
  String get assessmentMessageLowRisk =>
      'No se detectaron signos preocupantes en estas fotos.';

  @override
  String get assessmentMessageHighRisk =>
      'Los hallazgos pueden requerir evaluación profesional urgente. Consulte a un dentista o especialista oral en una semana.';

  @override
  String get assessmentMessageModerateReviewSuggested =>
      'La mayoría de los signos no son preocupantes. Una comprobación sugirió seguimiento; se recomienda revisión dental rutinaria.';

  @override
  String get assessmentMessageModerateNeedsAttention =>
      'Algunos cambios pueden requerir seguimiento. Programe una revisión dental en 1–2 semanas.';

  @override
  String get assessmentMessageModerateNeedsReview =>
      'Algunos cambios pueden requerir revisión profesional. Programe una revisión en 1–2 semanas.';

  @override
  String get riskSubtypeTitleOcaDominant =>
      'Alto riesgo – Revisión clínica urgente recomendada';

  @override
  String get riskSubtypeTitleOpmdDominant =>
      'Riesgo moderado a alto – Revisión por especialista recomendada';

  @override
  String get riskSubtypeTitleBenignDominant =>
      'Lesión detectada – Evaluación clínica recomendada';

  @override
  String get riskSubtypeMessageOcaDominant =>
      'Se detectaron patrones compatibles con cambios potencialmente graves. Consulte a un dentista o especialista oral con prontitud.';

  @override
  String get riskSubtypeMessageOpmdDominant =>
      'Se detectaron cambios tempranos que pueden beneficiarse de revisión por especialista. La detección temprana mejora significativamente los resultados.';

  @override
  String get riskSubtypeMessageBenignDominant =>
      'Se detectó una lesión que parece no amenazante pero debe ser evaluada por un profesional de la salud para confirmar.';

  @override
  String get perPhotoLabelPotentialConcern => 'Posible inquietud';

  @override
  String get perPhotoLabelReviewRecommended => 'Revisión recomendada';

  @override
  String get perPhotoLabelHealthy => 'Sano';

  @override
  String get perPhotoLabelRetakeOrReview =>
      'Volver a tomar o se necesita más análisis';

  @override
  String get perPhotoNoteHighConflict =>
      'El cribado detectó factores de riesgo. El patrón visual parece sano, pero se recomienda revisión profesional.';

  @override
  String get perPhotoNoteModerateConflict =>
      'Se detectaron signos sutiles. Patrón visual: Sano. Considere un seguimiento.';

  @override
  String get perPhotoNoteHighConflictBenign =>
      'El cribado detectó factores de riesgo. El patrón visual parece benigno. Se recomienda revisión profesional.';

  @override
  String get perPhotoNoteModerateConflictBenign =>
      'Se detectaron signos sutiles. Patrón visual: Benigno. Considere un seguimiento.';

  @override
  String perPhotoVisualDetailMostly(String label, String percent) {
    return 'Detalle visual: Mayormente $label ($percent%)';
  }

  @override
  String photosCapturedGoodQuality(int count) {
    return '$count/5 fotos capturadas con buena calidad';
  }

  @override
  String photosMayNeedRetake(int count) {
    return '$count foto(s) pueden necesitar retomarse para mejores resultados';
  }

  @override
  String get recNoConcerningSigns => 'No se detectaron signos preocupantes';

  @override
  String get recContinueOralHygiene => 'Continúe la higiene bucal habitual';

  @override
  String get recScheduleRoutineCheckup => 'Programe revisión dental rutinaria';

  @override
  String get recRescreen3Months => 'Repetir cribado en 3 meses';

  @override
  String recNeedClearerPhotosFor(String list) {
    return 'Se necesitan fotos más claras de: $list';
  }

  @override
  String get recSomeChangesNeedAttention =>
      'Se detectaron cambios que requieren atención';

  @override
  String get recSchedule2to4Weeks =>
      'Programe cita con el dentista en 2-4 semanas';

  @override
  String get recAvoidTobaccoAlcohol => 'Evite tabaco y alcohol';

  @override
  String get recMonitorChangesClosely => 'Vigile cualquier cambio de cerca';

  @override
  String recPaySpecialAttentionTo(String list) {
    return 'Preste especial atención a: $list';
  }

  @override
  String get recConcerningChangesDetected =>
      'Se detectaron cambios preocupantes';

  @override
  String get recUrgentSeeSpecialist =>
      'URGENTE: Consulte cirujano oral u oncólogo en 1 semana';

  @override
  String get recBringReportToAppointment => 'Lleve este informe a su cita';

  @override
  String get recEarlyDetectionImprovesOutcomes =>
      'La detección temprana mejora los resultados';

  @override
  String get check1Referral => 'Revisión 1 (derivación)';

  @override
  String get check2Detail => 'Revisión 2 (detalle)';

  @override
  String check2DetailWithConfidence(String label, String percent) {
    return 'Revisión 2 (detalle): $label ($percent% confianza)';
  }

  @override
  String get verdictBothLowRisk =>
      'Ambas revisiones sugieren bajo riesgo. No se necesita seguimiento inmediato; se recomiendan revisiones rutinarias.';

  @override
  String verdictBothSomeConcern(String label) {
    return 'Ambas revisiones sugieren cierta preocupación ($label). Se recomienda seguimiento con un profesional.';
  }

  @override
  String get verdictReferralAppropriate =>
      'Ambas revisiones sugieren que la derivación es apropiada. Consulte a un profesional para más evaluación.';

  @override
  String verdictDifferentSignals(String risk) {
    return 'Las dos revisiones dieron señales distintas. Mostramos $risk y recomendamos seguimiento profesional.';
  }

  @override
  String verdictCouldNotAssess(String note) {
    return 'Esta foto no pudo evaluarse. $note';
  }

  @override
  String get verdictPleaseRetake => 'Por favor, tome de nuevo.';
}
