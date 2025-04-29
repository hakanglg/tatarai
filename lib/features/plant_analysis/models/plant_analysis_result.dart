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
    this.growthStage,
    this.growthScore,
    this.timestamp,
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

  /// Bitkinin gelişim aşaması (fide, çiçeklenme, meyve vb.)
  final String? growthStage;

  /// Gelişim skoru (0-100 arası)
  final int? growthScore;

  /// Zaman damgası
  final int? timestamp;

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
    String? growthStage,
    int? growthScore,
    int? timestamp,
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
      growthStage: growthStage ?? this.growthStage,
      growthScore: growthScore ?? this.growthScore,
      timestamp: timestamp ?? this.timestamp,
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

        // Gelişim durumu bilgisini al
        String? growthStage;
        int? growthScore;

        if (json.containsKey('growth_assessment')) {
          final growth = json['growth_assessment'];
          growthStage = growth['stage'];
          growthScore = growth['score'];
        } else if (firstMatch.containsKey('plant_details') &&
            firstMatch['plant_details'].containsKey('growth_assessment')) {
          final growth = firstMatch['plant_details']['growth_assessment'];
          growthStage = growth['stage'];
          growthScore = growth['score'];
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
          growthStage: growthStage,
          growthScore: growthScore,
          timestamp: json['timestamp'],
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

      // Gelişim durumu bilgisini al
      String? growthStage;
      int? growthScore;

      if (json.containsKey('growth_assessment')) {
        final growth = json['growth_assessment'];
        growthStage = growth['stage'];
        growthScore = growth['score'];
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
        growthStage: growthStage,
        growthScore: growthScore,
        timestamp: json['timestamp'],
      );
    }

    // Firestore'dan gelen veriler - özel alanlar ile
    try {
      List<Disease> diseases = [];

      // Disease listesini dönüştür (eğer varsa)
      if (json.containsKey('diseases') && json['diseases'] is List) {
        diseases = (json['diseases'] as List)
            .where((disease) => disease is Map<String, dynamic>)
            .map((disease) {
          final diseaseMap = disease as Map<String, dynamic>;
          return Disease(
            name: diseaseMap['name'] ?? '',
            probability: diseaseMap['probability']?.toDouble() ?? 0.0,
            description: diseaseMap['description'],
            treatment: diseaseMap['treatment'] != null &&
                    diseaseMap['treatment'] is Map
                ? Treatment(
                    biological: _extractTreatmentList(
                        diseaseMap['treatment'], 'biological'),
                    chemical: _extractTreatmentList(
                        diseaseMap['treatment'], 'chemical'),
                    prevention: _extractTreatmentList(
                        diseaseMap['treatment'], 'prevention'),
                  )
                : null,
            similarImages: diseaseMap['similarImages'] is List
                ? List<String>.from(diseaseMap['similarImages'])
                : null,
          );
        }).toList();
      }

      // Önerileri dönüştür (eğer varsa)
      List<String> suggestions = [];
      if (json.containsKey('suggestions') && json['suggestions'] is List) {
        suggestions = List<String>.from(
          (json['suggestions'] as List).map((item) => item.toString()),
        );
      }

      // Benzer görüntüleri dönüştür (eğer varsa)
      List<String> similarImages = [];
      if (json.containsKey('similarImages') && json['similarImages'] is List) {
        similarImages = List<String>.from(
          (json['similarImages'] as List).map((item) => item.toString()),
        );
      }

      // Taksonomi bilgilerini dönüştür (eğer varsa)
      PlantTaxonomy? taxonomy;
      if (json.containsKey('taxonomy') && json['taxonomy'] is Map) {
        final taxMap = json['taxonomy'] as Map<String, dynamic>;
        taxonomy = PlantTaxonomy(
          kingdom: taxMap['kingdom'],
          phylum: taxMap['phylum'],
          class_: taxMap['class'],
          order: taxMap['order'],
          family: taxMap['family'],
          genus: taxMap['genus'],
          species: taxMap['species'],
        );
      }

      // Yenilebilir kısımları dönüştür (eğer varsa)
      List<String>? edibleParts;
      if (json.containsKey('edibleParts') && json['edibleParts'] is List) {
        edibleParts = List<String>.from(
          (json['edibleParts'] as List).map((item) => item.toString()),
        );
      }

      // Üretim yöntemlerini dönüştür (eğer varsa)
      List<String>? propagationMethods;
      if (json.containsKey('propagationMethods') &&
          json['propagationMethods'] is List) {
        propagationMethods = List<String>.from(
          (json['propagationMethods'] as List).map((item) => item.toString()),
        );
      }

      // Zaman damgasını dönüştür (eğer varsa)
      int? timestamp;
      if (json.containsKey('timestamp')) {
        if (json['timestamp'] is int) {
          timestamp = json['timestamp'];
        } else if (json['timestamp'] is String) {
          timestamp = int.tryParse(json['timestamp']);
        }
      }

      return PlantAnalysisResult(
        id: json['id'] ?? '',
        plantName: json['plantName'] ?? 'Bilinmeyen Bitki',
        probability:
            (json['probability'] is num) ? json['probability'].toDouble() : 0.0,
        isHealthy: json['isHealthy'] ?? true,
        diseases: diseases,
        description: json['description'] ?? '',
        suggestions: suggestions,
        imageUrl: json['imageUrl'] ?? '',
        similarImages: similarImages,
        taxonomy: taxonomy,
        edibleParts: edibleParts,
        propagationMethods: propagationMethods,
        watering: json['watering'],
        sunlight: json['sunlight'],
        soil: json['soil'],
        climate: json['climate'],
        geminiAnalysis: json['geminiAnalysis'],
        location: json['location'],
        fieldName: json['fieldName'],
        growthStage: json['growthStage'],
        growthScore: json['growthScore'] is int
            ? json['growthScore']
            : (json['growthScore'] is String
                ? int.tryParse(json['growthScore'])
                : null),
        timestamp: timestamp,
      );
    } catch (e) {
      print('PlantAnalysisResult.fromJson hata: $e');
      // Hata durumunda varsayılan sonuç
      return const PlantAnalysisResult(
        id: '',
        plantName: 'Dönüşüm Hatası',
        probability: 0.0,
        isHealthy: true,
        diseases: [],
        description: 'Veri dönüştürülürken hata oluştu',
        suggestions: [],
        imageUrl: '',
        similarImages: [],
      );
    }
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

  /// Tedavi listesini çıkaran yardımcı metod
  static List<String>? _extractTreatmentList(
      Map<String, dynamic>? treatment, String field) {
    if (treatment == null || !treatment.containsKey(field)) {
      return null;
    }

    final list = treatment[field];
    if (list is List) {
      return List<String>.from(list.map((item) => item.toString()));
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

  /// Modeli Map'e dönüştürür (Firestore için)
  Map<String, dynamic> toMap() {
    return toJson(); // JSON dönüşümünü kullan
  }

  /// Map'ten model oluşturur (Firestore için)
  factory PlantAnalysisResult.fromMap(Map<String, dynamic> map) {
    return PlantAnalysisResult.fromJson(map);
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
        growthStage,
        growthScore,
        timestamp,
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

  /// Modeli Map'e dönüştürür (Firestore için)
  Map<String, dynamic> toMap() {
    return {
      'kingdom': kingdom,
      'phylum': phylum,
      'class': class_,
      'order': order,
      'family': family,
      'genus': genus,
      'species': species,
    };
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

  /// Modeli Map'e dönüştürür (Firestore için)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'probability': probability,
      'description': description,
      'treatment': treatment?.toMap(),
      'similarImages': similarImages,
    };
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

  /// Modeli Map'e dönüştürür (Firestore için)
  Map<String, dynamic> toMap() {
    return {
      'biological': biological,
      'chemical': chemical,
      'prevention': prevention,
    };
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
              'treatment': disease.treatment?.toMap(),
              'similarImages': disease.similarImages,
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
      'taxonomy': taxonomy != null ? taxonomy!.toMap() : null,
      'location': location,
      'fieldName': fieldName,
      'growthStage': growthStage,
      'growthScore': growthScore,
      'timestamp': timestamp ??
          DateTime.now().millisecondsSinceEpoch, // Zaman damgası ekle
    };
  }
}
