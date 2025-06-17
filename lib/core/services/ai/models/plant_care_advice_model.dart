/// Bitki bakım tavsiyeleri modeli
///
/// Gemini AI'dan gelen bakım tavsiyelerini structured format'ta tutar
class PlantCareAdviceModel {
  /// Constructor
  const PlantCareAdviceModel({
    required this.title,
    required this.plantName,
    required this.watering,
    required this.sunlight,
    required this.soil,
    required this.fertilization,
    required this.pruning,
    required this.commonProblems,
    required this.tips,
    this.errorMessage,
  });

  /// Tavsiye başlığı
  final String title;

  /// Bitki adı
  final String plantName;

  /// Sulama bilgileri
  final WateringInfo watering;

  /// Işık gereksinimleri
  final SunlightInfo sunlight;

  /// Toprak bilgileri
  final SoilInfo soil;

  /// Gübreleme bilgileri
  final FertilizationInfo fertilization;

  /// Budama bilgileri
  final PruningInfo pruning;

  /// Yaygın sorunlar
  final List<String> commonProblems;

  /// Genel ipuçları
  final List<String> tips;

  /// Hata mesajı (varsa)
  final String? errorMessage;

  /// JSON'dan model oluşturur
  factory PlantCareAdviceModel.fromJson(Map<String, dynamic> json) {
    try {
      return PlantCareAdviceModel(
        title: json['title'] as String? ?? 'Bakım Tavsiyeleri',
        plantName: json['plantName'] as String? ?? '',
        watering: WateringInfo.fromJson(
            json['watering'] as Map<String, dynamic>? ?? {}),
        sunlight: SunlightInfo.fromJson(
            json['sunlight'] as Map<String, dynamic>? ?? {}),
        soil: SoilInfo.fromJson(json['soil'] as Map<String, dynamic>? ?? {}),
        fertilization: FertilizationInfo.fromJson(
            json['fertilization'] as Map<String, dynamic>? ?? {}),
        pruning: PruningInfo.fromJson(
            json['pruning'] as Map<String, dynamic>? ?? {}),
        commonProblems:
            List<String>.from(json['commonProblems'] as List? ?? []),
        tips: List<String>.from(json['tips'] as List? ?? []),
        errorMessage: json['error'] as String?,
      );
    } catch (e) {
      return PlantCareAdviceModel.error(
        plantName: json['plantName'] as String? ?? 'Bilinmeyen Bitki',
        error: 'JSON parsing hatası: $e',
      );
    }
  }

  /// Hata durumu için factory constructor
  factory PlantCareAdviceModel.error({
    required String plantName,
    required String error,
  }) {
    return PlantCareAdviceModel(
      title: 'Bakım Tavsiyeleri - Hata',
      plantName: plantName,
      watering: WateringInfo.empty(),
      sunlight: SunlightInfo.empty(),
      soil: SoilInfo.empty(),
      fertilization: FertilizationInfo.empty(),
      pruning: PruningInfo.empty(),
      commonProblems: [],
      tips: ['Lütfen daha sonra tekrar deneyin'],
      errorMessage: error,
    );
  }

  /// Model'i JSON'a çevirir
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'plantName': plantName,
      'watering': watering.toJson(),
      'sunlight': sunlight.toJson(),
      'soil': soil.toJson(),
      'fertilization': fertilization.toJson(),
      'pruning': pruning.toJson(),
      'commonProblems': commonProblems,
      'tips': tips,
      if (errorMessage != null) 'error': errorMessage,
    };
  }

  /// Hata durumunda mı?
  bool get hasError => errorMessage != null;

  /// Başarılı mı?
  bool get isSuccessful => !hasError && plantName.isNotEmpty;

  @override
  String toString() {
    return 'PlantCareAdviceModel(plantName: $plantName, hasError: $hasError)';
  }
}

/// Sulama bilgileri
class WateringInfo {
  const WateringInfo({
    required this.frequency,
    required this.amount,
    required this.seasonalTips,
  });

  /// Sulama sıklığı
  final String frequency;

  /// Su miktarı
  final String amount;

  /// Mevsimsel öneriler
  final String seasonalTips;

  factory WateringInfo.fromJson(Map<String, dynamic> json) {
    return WateringInfo(
      frequency: json['frequency'] as String? ?? 'Belirtilmedi',
      amount: json['amount'] as String? ?? 'Belirtilmedi',
      seasonalTips: json['seasonalTips'] as String? ?? 'Belirtilmedi',
    );
  }

  factory WateringInfo.empty() {
    return const WateringInfo(
      frequency: 'Belirlenemedi',
      amount: 'Belirlenemedi',
      seasonalTips: 'Belirlenemedi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'amount': amount,
      'seasonalTips': seasonalTips,
    };
  }
}

/// Işık gereksinimleri
class SunlightInfo {
  const SunlightInfo({
    required this.requirement,
    required this.hours,
    required this.placement,
  });

  /// Işık ihtiyacı
  final String requirement;

  /// Günlük saat
  final String hours;

  /// Yerleştirme önerisi
  final String placement;

  factory SunlightInfo.fromJson(Map<String, dynamic> json) {
    return SunlightInfo(
      requirement: json['requirement'] as String? ?? 'Belirtilmedi',
      hours: json['hours'] as String? ?? 'Belirtilmedi',
      placement: json['placement'] as String? ?? 'Belirtilmedi',
    );
  }

  factory SunlightInfo.empty() {
    return const SunlightInfo(
      requirement: 'Belirlenemedi',
      hours: 'Belirlenemedi',
      placement: 'Belirlenemedi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requirement': requirement,
      'hours': hours,
      'placement': placement,
    };
  }
}

/// Toprak bilgileri
class SoilInfo {
  const SoilInfo({
    required this.type,
    required this.ph,
    required this.drainage,
  });

  /// Toprak türü
  final String type;

  /// pH aralığı
  final String ph;

  /// Drenaj ihtiyacı
  final String drainage;

  factory SoilInfo.fromJson(Map<String, dynamic> json) {
    return SoilInfo(
      type: json['type'] as String? ?? 'Belirtilmedi',
      ph: json['ph'] as String? ?? 'Belirtilmedi',
      drainage: json['drainage'] as String? ?? 'Belirtilmedi',
    );
  }

  factory SoilInfo.empty() {
    return const SoilInfo(
      type: 'Belirlenemedi',
      ph: 'Belirlenemedi',
      drainage: 'Belirlenemedi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'ph': ph,
      'drainage': drainage,
    };
  }
}

/// Gübreleme bilgileri
class FertilizationInfo {
  const FertilizationInfo({
    required this.schedule,
    required this.type,
    required this.amount,
  });

  /// Gübreleme takvimi
  final String schedule;

  /// Gübre türü
  final String type;

  /// Miktar
  final String amount;

  factory FertilizationInfo.fromJson(Map<String, dynamic> json) {
    return FertilizationInfo(
      schedule: json['schedule'] as String? ?? 'Belirtilmedi',
      type: json['type'] as String? ?? 'Belirtilmedi',
      amount: json['amount'] as String? ?? 'Belirtilmedi',
    );
  }

  factory FertilizationInfo.empty() {
    return const FertilizationInfo(
      schedule: 'Belirlenemedi',
      type: 'Belirlenemedi',
      amount: 'Belirlenemedi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule': schedule,
      'type': type,
      'amount': amount,
    };
  }
}

/// Budama bilgileri
class PruningInfo {
  const PruningInfo({
    required this.season,
    required this.technique,
    required this.frequency,
  });

  /// Budama mevsimi
  final String season;

  /// Budama tekniği
  final String technique;

  /// Sıklık
  final String frequency;

  factory PruningInfo.fromJson(Map<String, dynamic> json) {
    return PruningInfo(
      season: json['season'] as String? ?? 'Belirtilmedi',
      technique: json['technique'] as String? ?? 'Belirtilmedi',
      frequency: json['frequency'] as String? ?? 'Belirtilmedi',
    );
  }

  factory PruningInfo.empty() {
    return const PruningInfo(
      season: 'Belirlenemedi',
      technique: 'Belirlenemedi',
      frequency: 'Belirlenemedi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season': season,
      'technique': technique,
      'frequency': frequency,
    };
  }
}
