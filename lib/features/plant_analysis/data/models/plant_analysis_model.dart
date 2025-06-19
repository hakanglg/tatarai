import '../../domain/entities/plant_analysis_entity.dart';
import 'disease_model.dart';

/// Plant Analysis Data Model (Data katmanı)
///
/// API responses ve database operations için kullanılan model.
/// Entity'ye ve entity'den dönüştürülebilir.
class PlantAnalysisModel {
  /// Analiz benzersiz tanımlayıcısı
  final String id;

  /// Bitki adı
  final String plantName;

  /// Tanımlama olasılığı (0-1 arası)
  final double probability;

  /// Bitkinin sağlıklı olup olmadığı
  final bool isHealthy;

  /// Tespit edilen hastalıklar
  final List<Disease> diseases;

  /// Bitki açıklaması
  final String description;

  /// Bakım ve tedavi önerileri
  final List<String> suggestions;

  /// Kullanıcının yüklediği görüntü URL'i
  final String imageUrl;

  /// Benzer bitki görüntüleri
  final List<String> similarImages;

  /// Taksonomik bilgiler
  final PlantTaxonomy? taxonomy;

  /// Yenilebilir kısımlar
  final List<String>? edibleParts;

  /// Çoğaltma yöntemleri
  final List<String>? propagationMethods;

  /// Sulama bilgileri
  final String? watering;

  /// Işık ihtiyacı
  final String? sunlight;

  /// Toprak gereksinimleri
  final String? soil;

  /// İklim gereksinimleri
  final String? climate;

  /// Gemini AI analizinin tam metni
  final String? geminiAnalysis;

  /// Konum bilgisi
  final String? location;

  /// Tarla adı veya konumu
  final String? fieldName;

  /// Bitkinin gelişim aşaması
  final String? growthStage;

  /// Gelişim skoru (0-100 arası)
  final int? growthScore;

  /// Gelişim yorumu
  final String? growthComment;

  /// Zaman damgası (milliseconds)
  final int? timestamp;

  /// Müdahale yöntemleri
  final List<String>? interventionMethods;

  /// Tarımsal öneriler
  final List<String>? agriculturalTips;

  /// Bölgesel bilgiler
  final List<String>? regionalInfo;

  /// API'dan gelen ham yanıt
  final Map<String, dynamic>? rawResponse;

  // ============================================================================
  // YENİ ALANLAR - Gelişmiş tarımsal analiz bilgileri
  // ============================================================================

  /// Ana hastalık adı (tekil)
  final String? diseaseName;

  /// Ana hastalık açıklaması
  final String? diseaseDescription;

  /// Önerilen tedavi/ilaç adı
  final String? treatmentName;

  /// Dekar başına dozaj bilgisi
  final String? dosagePerDecare;

  /// Uygulama yöntemi (yapraktan, topraktan vs.)
  final String? applicationMethod;

  /// Uygulama zamanı (saat, gün, hava koşulu)
  final String? applicationTime;

  /// Uygulama sıklığı (kaç günde bir vs.)
  final String? applicationFrequency;

  /// Hasat öncesi bekleme süresi
  final String? waitingPeriod;

  /// Tedavi etkinlik oranı
  final String? effectiveness;

  /// Ek notlar ve uyarılar
  final String? notes;

  /// Tek öneri (ana öneri)
  final String? suggestion;

  /// Ana müdahale yöntemi
  final String? intervention;

  /// Ana tarımsal ipucu
  final String? agriculturalTip;

  /// Constructor
  const PlantAnalysisModel({
    required this.id,
    required this.plantName,
    required this.probability,
    required this.isHealthy,
    required this.diseases,
    required this.description,
    required this.suggestions,
    required this.imageUrl,
    this.similarImages = const [],
    this.taxonomy,
    this.edibleParts,
    this.propagationMethods,
    this.watering,
    this.sunlight,
    this.soil,
    this.climate,
    this.geminiAnalysis,
    this.location,
    this.fieldName,
    this.growthStage,
    this.growthScore,
    this.growthComment,
    this.timestamp,
    this.interventionMethods,
    this.agriculturalTips,
    this.regionalInfo,
    this.rawResponse,
    // Yeni alanlar
    this.diseaseName,
    this.diseaseDescription,
    this.treatmentName,
    this.dosagePerDecare,
    this.applicationMethod,
    this.applicationTime,
    this.applicationFrequency,
    this.waitingPeriod,
    this.effectiveness,
    this.notes,
    this.suggestion,
    this.intervention,
    this.agriculturalTip,
  });

  /// JSON'dan PlantAnalysisModel oluşturur
  /// Helper method to parse double values from JSON (supports both string and number)
  static double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Helper method to parse boolean values from JSON (supports both string and boolean)
  static bool _parseBoolValue(dynamic value, {List<Disease>? diseases}) {
    // Eğer hastalık listesi verilmişse, önce ona göre karar ver
    if (diseases != null && diseases.isNotEmpty) {
      return false; // Hastalık varsa sağlıklı değil
    }

    if (value == null) return true; // Default to healthy
    if (value is bool) return value;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes';
    }
    if (value is int) return value != 0;
    return true; // Default to healthy
  }

  /// Helper method to parse integer values from JSON (supports both string and number)
  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  factory PlantAnalysisModel.fromJson(Map<String, dynamic> json) {
    try {
      // Debug: Test user's specific JSON
      print('🔍 PlantAnalysisModel.fromJson START');
      print('🔍 JSON keys: ${json.keys.toList()}');
      print('🔍 plantName raw: ${json['plantName']}');
      print('🔍 isHealthy raw: ${json['isHealthy']}');
      print('🔍 probability raw: ${json['probability']}');
      print(
          '🔍 growthScore raw: ${json['growthScore']} (type: ${json['growthScore']?.runtimeType})');
      print(
          '🔍 growthStage raw: ${json['growthStage']} (type: ${json['growthStage']?.runtimeType})');
      print(
          '🔍 growthComment raw: ${json['growthComment']} (type: ${json['growthComment']?.runtimeType})');

      // Diseases parsing
      List<Disease> diseases = [];
      if (json['diseases'] != null) {
        diseases = (json['diseases'] as List)
            .map((disease) => Disease.fromJson(disease as Map<String, dynamic>))
            .toList();
      }

      // Taxonomy parsing
      PlantTaxonomy? taxonomy;
      if (json['taxonomy'] != null) {
        taxonomy =
            PlantTaxonomy.fromJson(json['taxonomy'] as Map<String, dynamic>);
      }

      // isHealthy'yi hastalık listesine göre belirle
      final isHealthyFromJson = _parseBoolValue(
        json['is_healthy'] ?? json['isHealthy'],
        diseases: diseases,
      );

      return PlantAnalysisModel(
        id: json['id'] as String? ?? '',
        plantName:
            json['plant_name'] as String? ?? json['plantName'] as String? ?? '',
        probability: _parseDoubleValue(json['probability']),
        isHealthy: isHealthyFromJson,
        diseases: diseases,
        description: json['description'] as String? ?? '',
        suggestions: List<String>.from(json['suggestions'] as List? ?? []),
        imageUrl:
            json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
        similarImages: List<String>.from(json['similar_images'] as List? ??
            json['similarImages'] as List? ??
            []),
        taxonomy: taxonomy,
        edibleParts: json['edible_parts'] != null
            ? List<String>.from(json['edible_parts'] as List)
            : null,
        propagationMethods: json['propagation_methods'] != null
            ? List<String>.from(json['propagation_methods'] as List)
            : null,
        watering: json['watering'] as String?,
        sunlight: json['sunlight'] as String?,
        soil: json['soil'] as String?,
        climate: json['climate'] as String?,
        geminiAnalysis: json['gemini_analysis'] as String? ??
            json['geminiAnalysis'] as String?,
        location: json['location'] as String?,
        fieldName:
            json['field_name'] as String? ?? json['fieldName'] as String?,
        growthStage:
            json['growth_stage'] as String? ?? json['growthStage'] as String?,
        growthScore:
            _parseIntValue(json['growth_score'] ?? json['growthScore']),
        growthComment: json['growth_comment'] as String? ??
            json['growthComment'] as String?,
        timestamp: json['timestamp'] as int?,
        interventionMethods: json['intervention_methods'] != null
            ? List<String>.from(json['intervention_methods'] as List)
            : null,
        agriculturalTips: json['agricultural_tips'] != null
            ? List<String>.from(json['agricultural_tips'] as List)
            : null,
        regionalInfo: json['regional_info'] != null
            ? List<String>.from(json['regional_info'] as List)
            : null,
        rawResponse: json['raw_response'] as Map<String, dynamic>?,
        // Yeni alanları parse et
        diseaseName:
            json['diseaseName'] as String? ?? json['disease_name'] as String?,
        diseaseDescription: json['diseaseDescription'] as String? ??
            json['disease_description'] as String?,
        treatmentName: json['treatmentName'] as String? ??
            json['treatment_name'] as String?,
        dosagePerDecare: json['dosagePerDecare'] as String? ??
            json['dosage_per_decare'] as String?,
        applicationMethod: json['applicationMethod'] as String? ??
            json['application_method'] as String?,
        applicationTime: json['applicationTime'] as String? ??
            json['application_time'] as String?,
        applicationFrequency: json['applicationFrequency'] as String? ??
            json['application_frequency'] as String?,
        waitingPeriod: json['waitingPeriod'] as String? ??
            json['waiting_period'] as String?,
        effectiveness: json['effectiveness'] as String?,
        notes: json['notes'] as String?,
        suggestion: json['suggestion'] as String?,
        intervention: json['intervention'] as String?,
        agriculturalTip: json['agriculturalTip'] as String? ??
            json['agricultural_tip'] as String?,
      );

      // Success debug'unu constructor'dan sonra yapamayız, çünkü direkt return ediliyor
      print('🔍 PlantAnalysisModel.fromJson SUCCESS - will return model');
    } catch (e, stackTrace) {
      // Debug için JSON içeriğini loglayalım
      print('🚨 PlantAnalysisModel.fromJson parse error: $e');
      print('🔍 JSON keys: ${json.keys.toList()}');
      print(
          '🔍 JSON plantName: ${json['plantName']} (type: ${json['plantName']?.runtimeType})');
      print(
          '🔍 JSON isHealthy: ${json['isHealthy']} (type: ${json['isHealthy']?.runtimeType})');
      print(
          '🔍 JSON probability: ${json['probability']} (type: ${json['probability']?.runtimeType})');
      print(
          '🔍 Stack trace first line: ${stackTrace.toString().split('\n').first}');

      throw FormatException(
          'PlantAnalysisModel.fromJson parse error: $e\nJSON keys: ${json.keys.toList()}');
    }
  }

  /// PlantAnalysisModel'i JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plant_name': plantName,
      'probability': probability,
      'is_healthy': isHealthy,
      'diseases': diseases.map((disease) => disease.toJson()).toList(),
      'description': description,
      'suggestions': suggestions,
      'image_url': imageUrl,
      'similar_images': similarImages,
      'taxonomy': taxonomy?.toJson(),
      'edible_parts': edibleParts,
      'propagation_methods': propagationMethods,
      'watering': watering,
      'sunlight': sunlight,
      'soil': soil,
      'climate': climate,
      'gemini_analysis': geminiAnalysis,
      'location': location,
      'field_name': fieldName,
      'growth_stage': growthStage,
      'growth_score': growthScore,
      'growth_comment': growthComment,
      'timestamp': timestamp,
      'intervention_methods': interventionMethods,
      'agricultural_tips': agriculturalTips,
      'regional_info': regionalInfo,
      'raw_response': rawResponse,
      // Yeni alanlar
      'disease_name': diseaseName,
      'disease_description': diseaseDescription,
      'treatment_name': treatmentName,
      'dosage_per_decare': dosagePerDecare,
      'application_method': applicationMethod,
      'application_time': applicationTime,
      'application_frequency': applicationFrequency,
      'waiting_period': waitingPeriod,
      'effectiveness': effectiveness,
      'notes': notes,
      'suggestion': suggestion,
      'intervention': intervention,
      'agricultural_tip': agriculturalTip,
    };
  }

  /// Model'i Entity'ye dönüştürür
  PlantAnalysisEntity toEntity() {
    return PlantAnalysisEntity(
      id: id,
      plantName: plantName,
      probability: probability,
      isHealthy: isHealthy,
      diseases: diseases,
      description: description,
      suggestions: suggestions,
      imageUrl: imageUrl,
      similarImages: similarImages,
      location: location,
      fieldName: fieldName,
      timestamp: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp!)
          : null,
      // Yeni alanlar
      diseaseName: diseaseName,
      diseaseDescription: diseaseDescription,
      treatmentName: treatmentName,
      dosagePerDecare: dosagePerDecare,
      applicationMethod: applicationMethod,
      applicationTime: applicationTime,
      applicationFrequency: applicationFrequency,
      waitingPeriod: waitingPeriod,
      effectiveness: effectiveness,
      notes: notes,
      suggestion: suggestion,
      intervention: intervention,
      agriculturalTip: agriculturalTip,
      // Growth alanları
      growthScore: growthScore,
      growthStage: growthStage,
      growthComment: growthComment,
    );
  }

  /// Entity'den Model oluşturur
  factory PlantAnalysisModel.fromEntity(PlantAnalysisEntity entity) {
    return PlantAnalysisModel(
      id: entity.id,
      plantName: entity.plantName,
      probability: entity.probability,
      isHealthy: entity.isHealthy,
      diseases: entity.diseases,
      description: entity.description,
      suggestions: entity.suggestions,
      imageUrl: entity.imageUrl,
      similarImages: entity.similarImages,
      location: entity.location,
      fieldName: entity.fieldName,
      timestamp: entity.timestamp?.millisecondsSinceEpoch,
      // Yeni alanlar
      diseaseName: entity.diseaseName,
      diseaseDescription: entity.diseaseDescription,
      treatmentName: entity.treatmentName,
      dosagePerDecare: entity.dosagePerDecare,
      applicationMethod: entity.applicationMethod,
      applicationTime: entity.applicationTime,
      applicationFrequency: entity.applicationFrequency,
      waitingPeriod: entity.waitingPeriod,
      effectiveness: entity.effectiveness,
      notes: entity.notes,
      suggestion: entity.suggestion,
      intervention: entity.intervention,
      agriculturalTip: entity.agriculturalTip,
      // Growth alanları
      growthScore: entity.growthScore,
      growthStage: entity.growthStage,
      growthComment: entity.growthComment,
    );
  }

  /// Model kopyalama
  PlantAnalysisModel copyWith({
    String? id,
    String? plantName,
    double? probability,
    bool? isHealthy,
    List<Disease>? diseases,
    String? description,
    List<String>? suggestions,
    String? imageUrl,
    List<String>? similarImages,
    PlantTaxonomy? taxonomy,
    List<String>? edibleParts,
    List<String>? propagationMethods,
    String? watering,
    String? sunlight,
    String? soil,
    String? climate,
    String? geminiAnalysis,
    String? location,
    String? fieldName,
    String? growthStage,
    int? growthScore,
    String? growthComment,
    int? timestamp,
    List<String>? interventionMethods,
    List<String>? agriculturalTips,
    List<String>? regionalInfo,
    Map<String, dynamic>? rawResponse,
    // Yeni alanlar
    String? diseaseName,
    String? diseaseDescription,
    String? treatmentName,
    String? dosagePerDecare,
    String? applicationMethod,
    String? applicationTime,
    String? applicationFrequency,
    String? waitingPeriod,
    String? effectiveness,
    String? notes,
    String? suggestion,
    String? intervention,
    String? agriculturalTip,
  }) {
    return PlantAnalysisModel(
      id: id ?? this.id,
      plantName: plantName ?? this.plantName,
      probability: probability ?? this.probability,
      isHealthy: isHealthy ?? this.isHealthy,
      diseases: diseases ?? this.diseases,
      description: description ?? this.description,
      suggestions: suggestions ?? this.suggestions,
      imageUrl: imageUrl ?? this.imageUrl,
      similarImages: similarImages ?? this.similarImages,
      taxonomy: taxonomy ?? this.taxonomy,
      edibleParts: edibleParts ?? this.edibleParts,
      propagationMethods: propagationMethods ?? this.propagationMethods,
      watering: watering ?? this.watering,
      sunlight: sunlight ?? this.sunlight,
      soil: soil ?? this.soil,
      climate: climate ?? this.climate,
      geminiAnalysis: geminiAnalysis ?? this.geminiAnalysis,
      location: location ?? this.location,
      fieldName: fieldName ?? this.fieldName,
      growthStage: growthStage ?? this.growthStage,
      growthScore: growthScore ?? this.growthScore,
      growthComment: growthComment ?? this.growthComment,
      timestamp: timestamp ?? this.timestamp,
      interventionMethods: interventionMethods ?? this.interventionMethods,
      agriculturalTips: agriculturalTips ?? this.agriculturalTips,
      regionalInfo: regionalInfo ?? this.regionalInfo,
      rawResponse: rawResponse ?? this.rawResponse,
      // Yeni alanlar
      diseaseName: diseaseName ?? this.diseaseName,
      diseaseDescription: diseaseDescription ?? this.diseaseDescription,
      treatmentName: treatmentName ?? this.treatmentName,
      dosagePerDecare: dosagePerDecare ?? this.dosagePerDecare,
      applicationMethod: applicationMethod ?? this.applicationMethod,
      applicationTime: applicationTime ?? this.applicationTime,
      applicationFrequency: applicationFrequency ?? this.applicationFrequency,
      waitingPeriod: waitingPeriod ?? this.waitingPeriod,
      effectiveness: effectiveness ?? this.effectiveness,
      notes: notes ?? this.notes,
      suggestion: suggestion ?? this.suggestion,
      intervention: intervention ?? this.intervention,
      agriculturalTip: agriculturalTip ?? this.agriculturalTip,
    );
  }

  @override
  String toString() {
    return 'PlantAnalysisModel(id: $id, plantName: $plantName, isHealthy: $isHealthy)';
  }

  /// Boş bir analiz sonucu oluşturur
  static PlantAnalysisModel createEmpty({
    required String imageUrl,
    required String location,
    String? fieldName,
    String? errorMessage,
    String? originalText,
  }) {
    return PlantAnalysisModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plantName: 'Analiz edilemedi',
      probability: 0,
      isHealthy: false,
      diseases: [],
      description: errorMessage ?? 'Görüntü analiz edilemedi',
      suggestions: [
        'Analiz yapılamadı. Lütfen daha net bir görüntü ile tekrar deneyin.',
        'Farklı bir açıdan çekim yapmayı deneyebilirsiniz.',
      ],
      imageUrl: imageUrl,
      similarImages: [],
      location: location,
      fieldName: fieldName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      // Yeni alanlar - empty değerler
      diseaseName: null,
      diseaseDescription: null,
      treatmentName: null,
      dosagePerDecare: null,
      applicationMethod: null,
      applicationTime: null,
      applicationFrequency: null,
      waitingPeriod: null,
      effectiveness: null,
      notes: null,
      suggestion: null,
      intervention: null,
      agriculturalTip: null,
    );
  }
}

/// PlantAnalysisModel için UI yardımcı metodları
extension PlantAnalysisModelUIExtension on PlantAnalysisModel {
  /// Bitkinin genel durumunu gösteren emoji
  String get healthEmoji => isHealthy ? '🌱' : '🤒';

  /// Bitkinin durumunu açıklayan metin
  String get healthStatusText => isHealthy
      ? 'Sağlıklı Bitki'
      : diseases.isNotEmpty
          ? '${diseases.length} Hastalık Tespit Edildi'
          : 'Sağlık Durumu Belirsiz';

  /// Bitkinin durumunu gösteren renk (tema renklerine bağlı)
  String get healthColorName => isHealthy ? 'success' : 'error';

  /// Eğer varsa, hastalıkları ve olasılıklarını formatlı metin olarak döndürür
  String get formattedDiseases {
    if (diseases.isEmpty) return 'Hastalık tespit edilmedi';

    return diseases.map((disease) {
      final percentage = disease.probability != null
          ? (disease.probability! * 100).toStringAsFixed(0)
          : '0';
      return '${disease.name} (%$percentage)';
    }).join(', ');
  }

  /// Ana bakım önerilerini formatlı bir şekilde döndürür
  List<String> get formattedSuggestions {
    final List<String> result = [];

    // Eğer öneriler varsa, ilk 5'ini al
    if (suggestions.isNotEmpty) {
      result.addAll(suggestions.take(5));
    }

    // Eğer müdahale yöntemleri varsa ve listemiz hala kısa ise, onları da ekle
    if (interventionMethods != null &&
        interventionMethods!.isNotEmpty &&
        result.length < 7) {
      result.addAll(interventionMethods!.take(7 - result.length));
    }

    return result;
  }

  /// Gelişim durumunu yüzdelik olarak göster
  String get growthPercentage {
    if (growthScore == null) return 'Belirtilmemiş';
    return '%$growthScore';
  }

  /// Detaylı yetiştirme bilgilerini özet halinde döndürür
  Map<String, String> get careDetails {
    return {
      'Sulama': watering ?? 'Belirtilmemiş',
      'Işık': sunlight ?? 'Belirtilmemiş',
      'Toprak': soil ?? 'Belirtilmemiş',
      'İklim': climate ?? 'Belirtilmemiş',
    };
  }

  /// Eğer herhangi bir bakım önerisi varsa true döndürür
  bool get hasCareInformation {
    return watering != null ||
        sunlight != null ||
        soil != null ||
        climate != null ||
        (suggestions.isNotEmpty) ||
        (interventionMethods != null && interventionMethods!.isNotEmpty) ||
        (agriculturalTips != null && agriculturalTips!.isNotEmpty);
  }

  /// Tam tarih ve saat bilgisini formatlar
  String get formattedDate {
    if (timestamp == null) return 'Belirtilmemiş';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp!);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Bugün
      return 'Bugün ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Dün
      return 'Dün ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Bu hafta
      return '${_getDayName(dateTime.weekday)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Daha eski
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Günün adını döndürür
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Pazartesi';
      case 2:
        return 'Salı';
      case 3:
        return 'Çarşamba';
      case 4:
        return 'Perşembe';
      case 5:
        return 'Cuma';
      case 6:
        return 'Cumartesi';
      case 7:
        return 'Pazar';
      default:
        return '';
    }
  }
}
