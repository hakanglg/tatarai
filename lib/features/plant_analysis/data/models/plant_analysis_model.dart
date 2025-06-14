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
    );
  }

  @override
  String toString() {
    return 'PlantAnalysisModel(id: $id, plantName: $plantName, isHealthy: $isHealthy)';
  }
}
