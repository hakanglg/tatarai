/// Hastalık tavsiyeleri modeli
///
/// Gemini AI'dan gelen hastalık tedavi önerilerini structured format'ta tutar
class DiseaseRecommendationsModel {
  /// Constructor
  const DiseaseRecommendationsModel({
    required this.title,
    required this.diseaseName,
    required this.description,
    required this.symptoms,
    required this.causes,
    required this.treatments,
    required this.prevention,
    required this.severity,
    required this.urgency,
    this.errorMessage,
  });

  /// Tavsiye başlığı
  final String title;

  /// Hastalık adı
  final String diseaseName;

  /// Hastalık açıklaması
  final String description;

  /// Semptomlar
  final List<String> symptoms;

  /// Nedenler
  final List<String> causes;

  /// Tedavi yöntemleri
  final List<TreatmentMethod> treatments;

  /// Önleme yöntemleri
  final List<String> prevention;

  /// Hastalık ciddiyeti
  final DiseaseSeverity severity;

  /// Aciliyet durumu
  final UrgencyLevel urgency;

  /// Hata mesajı (varsa)
  final String? errorMessage;

  /// JSON'dan model oluşturur
  factory DiseaseRecommendationsModel.fromJson(Map<String, dynamic> json) {
    try {
      return DiseaseRecommendationsModel(
        title: json['title'] as String? ?? 'Hastalık Tavsiyeleri',
        diseaseName: json['diseaseName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        symptoms: List<String>.from(json['symptoms'] as List? ?? []),
        causes: List<String>.from(json['causes'] as List? ?? []),
        treatments: (json['treatments'] as List? ?? [])
            .map((e) => TreatmentMethod.fromJson(e as Map<String, dynamic>))
            .toList(),
        prevention: List<String>.from(json['prevention'] as List? ?? []),
        severity: _parseSeverity(json['severity'] as String?),
        urgency: _parseUrgency(json['urgency'] as String?),
        errorMessage: json['error'] as String?,
      );
    } catch (e) {
      return DiseaseRecommendationsModel.error(
        diseaseName: json['diseaseName'] as String? ?? 'Bilinmeyen Hastalık',
        error: 'JSON parsing hatası: $e',
      );
    }
  }

  /// Hata durumu için factory constructor
  factory DiseaseRecommendationsModel.error({
    required String diseaseName,
    required String error,
  }) {
    return DiseaseRecommendationsModel(
      title: 'Hastalık Tavsiyeleri - Hata',
      diseaseName: diseaseName,
      description: 'Hastalık bilgileri alınamadı',
      symptoms: [],
      causes: [],
      treatments: [],
      prevention: ['Lütfen daha sonra tekrar deneyin'],
      severity: DiseaseSeverity.unknown,
      urgency: UrgencyLevel.low,
      errorMessage: error,
    );
  }

  /// Model'i JSON'a çevirir
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'diseaseName': diseaseName,
      'description': description,
      'symptoms': symptoms,
      'causes': causes,
      'treatments': treatments.map((e) => e.toJson()).toList(),
      'prevention': prevention,
      'severity': severity.name,
      'urgency': urgency.name,
      if (errorMessage != null) 'error': errorMessage,
    };
  }

  /// Hata durumunda mı?
  bool get hasError => errorMessage != null;

  /// Başarılı mı?
  bool get isSuccessful => !hasError && diseaseName.isNotEmpty;

  /// Acil müdahale gerekli mi?
  bool get isUrgent =>
      urgency == UrgencyLevel.high || urgency == UrgencyLevel.critical;

  /// Ciddi bir hastalık mı?
  bool get isSevere =>
      severity == DiseaseSeverity.severe ||
      severity == DiseaseSeverity.critical;

  @override
  String toString() {
    return 'DiseaseRecommendationsModel(diseaseName: $diseaseName, severity: $severity, hasError: $hasError)';
  }

  /// Severity parsing helper
  static DiseaseSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'low':
      case 'düşük':
        return DiseaseSeverity.low;
      case 'moderate':
      case 'orta':
        return DiseaseSeverity.moderate;
      case 'severe':
      case 'ciddi':
        return DiseaseSeverity.severe;
      case 'critical':
      case 'kritik':
        return DiseaseSeverity.critical;
      default:
        return DiseaseSeverity.unknown;
    }
  }

  /// Urgency parsing helper
  static UrgencyLevel _parseUrgency(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'low':
      case 'düşük':
        return UrgencyLevel.low;
      case 'medium':
      case 'orta':
        return UrgencyLevel.medium;
      case 'high':
      case 'yüksek':
        return UrgencyLevel.high;
      case 'critical':
      case 'kritik':
        return UrgencyLevel.critical;
      default:
        return UrgencyLevel.low;
    }
  }
}

/// Tedavi yöntemi
class TreatmentMethod {
  const TreatmentMethod({
    required this.type,
    required this.method,
    required this.duration,
    required this.frequency,
    this.materials,
    this.warnings,
  });

  /// Tedavi türü (organik, kimyasal, mekanik)
  final String type;

  /// Tedavi yöntemi açıklaması
  final String method;

  /// Süre
  final String duration;

  /// Sıklık
  final String frequency;

  /// Gerekli malzemeler
  final List<String>? materials;

  /// Uyarılar
  final List<String>? warnings;

  factory TreatmentMethod.fromJson(Map<String, dynamic> json) {
    return TreatmentMethod(
      type: json['type'] as String? ?? 'Genel',
      method: json['method'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      materials: json['materials'] != null
          ? List<String>.from(json['materials'] as List)
          : null,
      warnings: json['warnings'] != null
          ? List<String>.from(json['warnings'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'method': method,
      'duration': duration,
      'frequency': frequency,
      if (materials != null) 'materials': materials,
      if (warnings != null) 'warnings': warnings,
    };
  }
}

/// Hastalık ciddiyeti
enum DiseaseSeverity {
  /// Bilinmeyen
  unknown('Bilinmeyen'),

  /// Düşük
  low('Düşük'),

  /// Orta
  moderate('Orta'),

  /// Ciddi
  severe('Ciddi'),

  /// Kritik
  critical('Kritik');

  const DiseaseSeverity(this.displayName);

  /// Görüntüleme adı
  final String displayName;
}

/// Aciliyet seviyesi
enum UrgencyLevel {
  /// Düşük
  low('Düşük'),

  /// Orta
  medium('Orta'),

  /// Yüksek
  high('Yüksek'),

  /// Kritik
  critical('Kritik');

  const UrgencyLevel(this.displayName);

  /// Görüntüleme adı
  final String displayName;
}
