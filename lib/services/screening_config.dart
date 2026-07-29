/// Configurable thresholds for the V2 screening pipeline.
///
/// Binary SSL model is the sole screening authority.
/// Multi-class model is informational only (subtype guidance).
class ScreeningConfig {
  ScreeningConfig._();

  // ---------------------------------------------------------------------------
  // Binary screening (hybrid patient-level aggregation)
  // ---------------------------------------------------------------------------

  /// 80 % specificity operating point for binary SSL model.
  static const double binaryScreeningThreshold = 0.4735;

  /// A single photo above this triggers screen-positive regardless of others.
  static const double highConfSingleViewThreshold = 0.65;

  // ---------------------------------------------------------------------------
  // Retake zone
  // ---------------------------------------------------------------------------

  /// Lower bound of the "retake suggested" band (inclusive).
  static const double retakeLowerBound = 0.45;

  /// Upper bound of the "retake suggested" band (exclusive).
  /// Values at or above this but below [binaryScreeningThreshold] are still
  /// low-risk in the hybrid rule, but within retake range individually.
  static const double retakeUpperBound = 0.50;

  // ---------------------------------------------------------------------------
  // Multi-class (informational)
  // ---------------------------------------------------------------------------

  /// Minimum probability for a subtype class to be considered dominant.
  static const double subtypeConfidenceThreshold = 0.40;

  /// When screen-negative, show a soft "minor patterns" note if
  /// p_opmd + p_oca exceeds this.
  static const double borderlineMultiClassThreshold = 0.35;

  // ---------------------------------------------------------------------------
  // Quality / OOD
  // ---------------------------------------------------------------------------

  /// Unknown class probability above this marks a photo as non-oral / OOD.
  static const double oodUnknownThreshold = 0.6;

  /// Capture-time quality score below this means "unclear image".
  static const double qualityUnclearThreshold = 0.6;

  /// Minimum quality score for a photo to be usable in aggregation.
  static const double qualityMin = 0.5;

  // ---------------------------------------------------------------------------
  // Aggregation
  // ---------------------------------------------------------------------------

  /// Minimum usable photos before declaring session unreliable.
  static const int minUsedPhotos = 2;

  /// Label confidence: below this the display label becomes "Uncertain".
  static const double labelConfidenceThreshold = 0.5;
}
