enum TobaccoType {
  cigarette,
  beedi,
  hookah,
  arecaNut,
  paanMasala,
  gutka,
  surti,
  gul,
  other;

  String get displayName {
    switch (this) {
      case TobaccoType.cigarette:
        return 'Cigarette';
      case TobaccoType.beedi:
        return 'Beedi';
      case TobaccoType.hookah:
        return 'Hookah';
      case TobaccoType.arecaNut:
        return 'Areca Nut (Supari)';
      case TobaccoType.paanMasala:
        return 'Paan Masala';
      case TobaccoType.gutka:
        return 'Gutka';
      case TobaccoType.surti:
        return 'Surti';
      case TobaccoType.gul:
        return 'Gul';
      case TobaccoType.other:
        return 'Other';
    }
  }
}

enum DurationCategory {
  lessThan1Year,
  oneToFiveYears,
  fiveToTenYears,
  tenToTwentyYears,
  moreThan20Years;

  String get displayName {
    switch (this) {
      case DurationCategory.lessThan1Year:
        return 'Less than 1 year';
      case DurationCategory.oneToFiveYears:
        return '1–5 years';
      case DurationCategory.fiveToTenYears:
        return '5–10 years';
      case DurationCategory.tenToTwentyYears:
        return '10–20 years';
      case DurationCategory.moreThan20Years:
        return 'More than 20 years';
    }
  }
}

enum FrequencyCategory {
  occasional,
  oneToFivePerDay,
  fiveToTenPerDay,
  moreThanTenPerDay;

  String get displayName {
    switch (this) {
      case FrequencyCategory.occasional:
        return 'Occasional';
      case FrequencyCategory.oneToFivePerDay:
        return '1–5 per day';
      case FrequencyCategory.fiveToTenPerDay:
        return '5–10 per day';
      case FrequencyCategory.moreThanTenPerDay:
        return 'More than 10 per day';
    }
  }
}

enum ExposureRiskLevel {
  low,
  moderate,
  high;

  String get displayName {
    switch (this) {
      case ExposureRiskLevel.low:
        return 'Low';
      case ExposureRiskLevel.moderate:
        return 'Moderate';
      case ExposureRiskLevel.high:
        return 'High';
    }
  }
}

class ExposureData {
  final List<TobaccoType> tobaccoTypes;
  final String? otherDescription;
  final DurationCategory? duration;
  final FrequencyCategory? frequency;
  final int exposureScore;
  final ExposureRiskLevel exposureRiskLevel;

  const ExposureData({
    required this.tobaccoTypes,
    this.otherDescription,
    this.duration,
    this.frequency,
    required this.exposureScore,
    required this.exposureRiskLevel,
  });

  /// No tobacco use — score 0, Low risk.
  const ExposureData.none()
    : tobaccoTypes = const [],
      otherDescription = null,
      duration = null,
      frequency = null,
      exposureScore = 0,
      exposureRiskLevel = ExposureRiskLevel.low;

  Map<String, dynamic> toJson() => {
    'tobaccoTypes': tobaccoTypes.map((t) => t.name).toList(),
    if (otherDescription != null) 'otherDescription': otherDescription,
    'duration': duration?.name,
    'frequency': frequency?.name,
    'exposureScore': exposureScore,
    'exposureRiskLevel': exposureRiskLevel.name,
  };

  factory ExposureData.fromJson(Map<String, dynamic> json) {
    return ExposureData(
      tobaccoTypes:
          (json['tobaccoTypes'] as List<dynamic>?)
              ?.map(
                (t) => TobaccoType.values.firstWhere(
                  (v) => v.name == t,
                  orElse: () => TobaccoType.other,
                ),
              )
              .toList() ??
          [],
      otherDescription: json['otherDescription'] as String?,
      duration: json['duration'] != null
          ? DurationCategory.values.firstWhere(
              (v) => v.name == json['duration'],
              orElse: () => DurationCategory.lessThan1Year,
            )
          : null,
      frequency: json['frequency'] != null
          ? FrequencyCategory.values.firstWhere(
              (v) => v.name == json['frequency'],
              orElse: () => FrequencyCategory.occasional,
            )
          : null,
      exposureScore: json['exposureScore'] as int? ?? 0,
      exposureRiskLevel: ExposureRiskLevel.values.firstWhere(
        (v) => v.name == json['exposureRiskLevel'],
        orElse: () => ExposureRiskLevel.low,
      ),
    );
  }

  @override
  String toString() =>
      'ExposureData(types: ${tobaccoTypes.map((t) => t.displayName).join(", ")}, '
      'otherDescription: ${otherDescription ?? "N/A"}, '
      'duration: ${duration?.displayName ?? "N/A"}, '
      'frequency: ${frequency?.displayName ?? "N/A"}, '
      'score: $exposureScore, risk: ${exposureRiskLevel.displayName})';
}
