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
  factory PlantAnalysisModel.fromJson(Map<String, dynamic> json) {
    try {
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

      return PlantAnalysisModel(
        id: json['id'] as String? ?? '',
        plantName:
            json['plant_name'] as String? ?? json['plantName'] as String? ?? '',
        probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
        isHealthy:
            json['is_healthy'] as bool? ?? json['isHealthy'] as bool? ?? true,
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
            json['growth_score'] as int? ?? json['growthScore'] as int?,
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
    } catch (e) {
      throw FormatException('PlantAnalysisModel.fromJson parse error: $e');
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
}
