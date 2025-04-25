import 'package:equatable/equatable.dart';

/// Bitki analiz sonuçları modeli
/// Plant.id API'den dönen yanıtları modelleme
class PlantAnalysisResult extends Equatable {
  const PlantAnalysisResult({
    required this.id,
    required this.plantName,
    required this.probability,
    required this.isHealthy,
    required this.diseases,
    required this.description,
    required this.suggestions,
    required this.imageUrl,
    required this.similarImages,
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
  });

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

  /// Sınıfın mevcut değerlerini koruyarak yeni bir örnek oluşturur
  PlantAnalysisResult copyWith({
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
  }) {
    return PlantAnalysisResult(
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
    );
  }

  /// API yanıtından model oluşturma
  factory PlantAnalysisResult.fromJson(Map<String, dynamic> json) {
    // Bitki tanımlama API'sinden gelen yanıtı işleme
    if (json.containsKey('suggestions')) {
      final suggestions = json['suggestions'] as List<dynamic>;
      final firstMatch = suggestions.isNotEmpty ? suggestions[0] : null;

      if (firstMatch != null) {
        // Hastalık tespiti
        List<Disease> diseases = [];
        bool isHealthy = true;

        if (json.containsKey('health_assessment')) {
          final health = json['health_assessment'];
          isHealthy = health['is_healthy'] ?? true;

          if (health.containsKey('diseases')) {
            diseases = (health['diseases'] as List<dynamic>)
                .map((disease) => Disease.fromJson(disease))
                .toList();
          }
        }

        return PlantAnalysisResult(
          id: json['id'] ?? '',
          plantName: firstMatch['plant_name'] ?? 'Bilinmeyen Bitki',
          probability: firstMatch['probability']?.toDouble() ?? 0.0,
          isHealthy: isHealthy,
          diseases: diseases,
          description: firstMatch['plant_details']?['description'] ?? '',
          suggestions: _extractSuggestions(json),
          imageUrl: json['images']?[0] ?? '',
          similarImages: _extractSimilarImages(json),
          taxonomy: firstMatch['plant_details']?['taxonomy'] != null
              ? PlantTaxonomy.fromJson(
                  firstMatch['plant_details']['taxonomy'],
                )
              : null,
          edibleParts: _convertToStringList(
            firstMatch['plant_details']?['edible_parts'],
          ),
          propagationMethods: _convertToStringList(
            firstMatch['plant_details']?['propagation_methods'],
          ),
          watering: firstMatch['plant_details']?['watering'],
          sunlight: firstMatch['plant_details']?['sunlight'],
          soil: firstMatch['plant_details']?['soil'],
          climate: firstMatch['plant_details']?['climate'],
          geminiAnalysis: firstMatch['plant_details']?['gemini_analysis'],
          location: firstMatch['plant_details']?['location'],
          fieldName: firstMatch['plant_details']?['field_name'],
        );
      }
    }

    // Sağlık analizi API'sinden gelen yanıtı işleme
    if (json.containsKey('health_assessment')) {
      final health = json['health_assessment'];
      final isHealthy = health['is_healthy'] ?? true;

      List<Disease> diseases = [];
      if (health.containsKey('diseases')) {
        diseases = (health['diseases'] as List<dynamic>)
            .map((disease) => Disease.fromJson(disease))
            .toList();
      }

      return PlantAnalysisResult(
        id: json['id'] ?? '',
        plantName:
            json['plant_details']?['common_names']?[0] ?? 'Bilinmeyen Bitki',
        probability:
            1.0, // Sağlık değerlendirmesinde genellikle olasılık verilmez
        isHealthy: isHealthy,
        diseases: diseases,
        description: json['plant_details']?['description'] ?? '',
        suggestions: _extractTreatments(health),
        imageUrl: json['images']?[0] ?? '',
        similarImages: _extractSimilarImages(json),
        taxonomy: null,
        edibleParts: null,
        propagationMethods: null,
        watering: null,
        sunlight: null,
        soil: null,
        climate: null,
        geminiAnalysis: null,
        location: json['plant_details']?['location'],
        fieldName: json['plant_details']?['field_name'],
      );
    }

    // Varsayılan boş sonuç
    return const PlantAnalysisResult(
      id: '',
      plantName: 'Bilinmeyen Bitki',
      probability: 0.0,
      isHealthy: true,
      diseases: [],
      description: '',
      suggestions: [],
      imageUrl: '',
      similarImages: [],
      soil: null,
      climate: null,
      geminiAnalysis: null,
      location: null,
      fieldName: null,
    );
  }

  /// JSON'dan string listesi çıkarma yardımcı methodu
  static List<String>? _convertToStringList(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return null;
  }

  /// Sağlık önerilerini çıkartan yardımcı metot
  static List<String> _extractTreatments(Map<String, dynamic> health) {
    final List<String> treatments = [];

    if (health.containsKey('diseases')) {
      final diseases = health['diseases'] as List<dynamic>;
      for (final disease in diseases) {
        if (disease.containsKey('treatment')) {
          final treatment = disease['treatment'];
          if (treatment.containsKey('biological') &&
              treatment['biological'] is List) {
            treatments.addAll(
              (treatment['biological'] as List).map((e) => e.toString()),
            );
          }
          if (treatment.containsKey('chemical') &&
              treatment['chemical'] is List) {
            treatments.addAll(
              (treatment['chemical'] as List).map((e) => e.toString()),
            );
          }
          if (treatment.containsKey('prevention') &&
              treatment['prevention'] is List) {
            treatments.addAll(
              (treatment['prevention'] as List).map((e) => e.toString()),
            );
          }
        }
      }
    }

    return treatments;
  }

  /// Benzer görüntüleri çıkartan yardımcı metot
  static List<String> _extractSimilarImages(Map<String, dynamic> json) {
    final List<String> images = [];

    if (json.containsKey('similar_images')) {
      final similarImages = json['similar_images'] as List<dynamic>;
      for (final image in similarImages) {
        if (image.containsKey('url')) {
          images.add(image['url']);
        }
      }
    }

    return images;
  }

  /// Önerileri çıkartan yardımcı metot
  static List<String> _extractSuggestions(Map<String, dynamic> json) {
    final List<String> suggestions = [];

    if (json.containsKey('health_assessment')) {
      final health = json['health_assessment'];
      if (health.containsKey('diseases')) {
        final diseases = health['diseases'] as List<dynamic>;
        for (final disease in diseases) {
          if (disease.containsKey('treatment')) {
            final treatment = disease['treatment'];
            if (treatment.containsKey('biological') &&
                treatment['biological'] is List) {
              suggestions.addAll(
                (treatment['biological'] as List).map((e) => e.toString()),
              );
            }
            if (treatment.containsKey('chemical') &&
                treatment['chemical'] is List) {
              suggestions.addAll(
                (treatment['chemical'] as List).map((e) => e.toString()),
              );
            }
            if (treatment.containsKey('prevention') &&
                treatment['prevention'] is List) {
              suggestions.addAll(
                (treatment['prevention'] as List).map((e) => e.toString()),
              );
            }
          }
        }
      }
    }

    return suggestions;
  }

  @override
  List<Object?> get props => [
        id,
        plantName,
        probability,
        isHealthy,
        diseases,
        description,
        suggestions,
        imageUrl,
        similarImages,
        taxonomy,
        edibleParts,
        propagationMethods,
        watering,
        sunlight,
        soil,
        climate,
        geminiAnalysis,
        location,
        fieldName,
      ];
}

/// Bitki taksonomisi modeli
class PlantTaxonomy extends Equatable {
  const PlantTaxonomy({
    this.kingdom,
    this.phylum,
    this.class_,
    this.order,
    this.family,
    this.genus,
    this.species,
  });

  final String? kingdom;
  final String? phylum;
  final String? class_;
  final String? order;
  final String? family;
  final String? genus;
  final String? species;

  factory PlantTaxonomy.fromJson(Map<String, dynamic> json) {
    return PlantTaxonomy(
      kingdom: json['kingdom'],
      phylum: json['phylum'],
      class_: json['class'],
      order: json['order'],
      family: json['family'],
      genus: json['genus'],
      species: json['species'],
    );
  }

  @override
  List<Object?> get props => [
        kingdom,
        phylum,
        class_,
        order,
        family,
        genus,
        species,
      ];
}

/// Bitki hastalığı modeli
class Disease extends Equatable {
  const Disease({
    required this.name,
    required this.probability,
    this.description,
    this.treatment,
    this.similarImages,
  });

  final String name;
  final double probability;
  final String? description;
  final Treatment? treatment;
  final List<String>? similarImages;

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      name: json['name'] ?? 'Bilinmeyen Hastalık',
      probability: json['probability']?.toDouble() ?? 0.0,
      description: json['description'],
      treatment: json['treatment'] != null
          ? Treatment.fromJson(json['treatment'])
          : null,
      similarImages: json['similar_images'] != null
          ? (json['similar_images'] as List)
              .map((img) => img['url'].toString())
              .toList()
          : null,
    );
  }

  @override
  List<Object?> get props => [
        name,
        probability,
        description,
        treatment,
        similarImages,
      ];
}

/// Tedavi önerileri modeli
class Treatment extends Equatable {
  const Treatment({this.biological, this.chemical, this.prevention});

  final List<String>? biological;
  final List<String>? chemical;
  final List<String>? prevention;

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      biological: json['biological'] != null
          ? List<String>.from(json['biological'])
          : null,
      chemical:
          json['chemical'] != null ? List<String>.from(json['chemical']) : null,
      prevention: json['prevention'] != null
          ? List<String>.from(json['prevention'])
          : null,
    );
  }

  @override
  List<Object?> get props => [biological, chemical, prevention];
}

/// PlantAnalysisResult sınıfına JSON dönüşüm metodunu ekleyelim
extension PlantAnalysisResultJsonSerialization on PlantAnalysisResult {
  /// PlantAnalysisResult nesnesini JSON formatına dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantName': plantName,
      'probability': probability,
      'isHealthy': isHealthy,
      'diseases': diseases
          .map(
            (disease) => {
              'name': disease.name,
              'probability': disease.probability,
              'description': disease.description,
            },
          )
          .toList(),
      'description': description,
      'suggestions': suggestions,
      'imageUrl': imageUrl,
      'similarImages': similarImages,
      'edibleParts': edibleParts,
      'propagationMethods': propagationMethods,
      'watering': watering,
      'sunlight': sunlight is String ? sunlight : null,
      'soil': soil,
      'climate': climate,
      'geminiAnalysis': geminiAnalysis,
      'taxonomy': taxonomy != null
          ? {
              'kingdom': taxonomy!.kingdom,
              'phylum': taxonomy!.phylum,
              'class': taxonomy!.class_,
              'order': taxonomy!.order,
              'family': taxonomy!.family,
              'genus': taxonomy!.genus,
            }
          : null,
      'location': location,
      'fieldName': fieldName,
    };
  }

  /// JSON verilerinden PlantAnalysisResult nesnesi oluşturur
  static PlantAnalysisResult fromJson(Map<String, dynamic> json) {
    return PlantAnalysisResult(
      id: json['id'] ?? '',
      plantName: json['plantName'] ?? 'Bilinmeyen Bitki',
      probability: json['probability']?.toDouble() ?? 0.0,
      isHealthy: json['isHealthy'] ?? true,
      diseases: json['diseases'] != null
          ? (json['diseases'] as List)
              .map(
                (disease) => Disease(
                  name: disease['name'] ?? '',
                  probability: disease['probability']?.toDouble() ?? 0.0,
                  description: disease['description'] ?? '',
                ),
              )
              .toList()
          : <Disease>[],
      description: json['description'] ?? '',
      suggestions: json['suggestions'] != null
          ? (json['suggestions'] as List)
              .map((suggestion) => suggestion.toString())
              .toList()
          : <String>[],
      imageUrl: json['imageUrl'] ?? '',
      similarImages: json['similarImages'] != null
          ? (json['similarImages'] as List)
              .map((image) => image.toString())
              .toList()
          : <String>[],
      soil: json['soil'],
      climate: json['climate'],
      geminiAnalysis: json['geminiAnalysis'],
      taxonomy: json['taxonomy'] != null
          ? PlantTaxonomy(
              kingdom: json['taxonomy']['kingdom'] ?? '',
              phylum: json['taxonomy']['phylum'] ?? '',
              class_: json['taxonomy']['class'] ?? '',
              order: json['taxonomy']['order'] ?? '',
              family: json['taxonomy']['family'] ?? '',
              genus: json['taxonomy']['genus'] ?? '',
            )
          : null,
      sunlight: json['sunlight'],
      watering: json['watering'],
      edibleParts: json['edibleParts'] != null
          ? (json['edibleParts'] as List)
              .map((part) => part.toString())
              .toList()
          : null,
      propagationMethods: json['propagationMethods'] != null
          ? (json['propagationMethods'] as List)
              .map((method) => method.toString())
              .toList()
          : null,
      location: json['location'],
      fieldName: json['fieldName'],
    );
  }
}
