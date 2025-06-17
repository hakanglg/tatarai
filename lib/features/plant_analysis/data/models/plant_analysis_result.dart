import 'package:equatable/equatable.dart';
import 'package:tatarai/core/utils/logger.dart';

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
    this.interventionMethods,
    this.agriculturalTips,
    this.regionalInfo,
    this.growthComment,
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

  /// Gelişim yorumu
  final String? growthComment;

  /// Zaman damgası
  final int? timestamp;

  /// Müdahale yöntemleri
  final List<String>? interventionMethods;

  /// Tarımsal öneriler
  final List<String>? agriculturalTips;

  /// Bölgesel bilgiler
  final List<String>? regionalInfo;

  /// Görüntü analizinin tam metni
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
    List<String>? interventionMethods,
    List<String>? agriculturalTips,
    List<String>? regionalInfo,
    String? growthComment,
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
      interventionMethods: interventionMethods ?? this.interventionMethods,
      agriculturalTips: agriculturalTips ?? this.agriculturalTips,
      regionalInfo: regionalInfo ?? this.regionalInfo,
      growthComment: growthComment ?? this.growthComment,
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

  /// API yanıtından model oluşturma
  factory PlantAnalysisResult.fromJson(Map<String, dynamic> json) {
    // Bitki tanımlama API'sinden gelen yanıtı işleme
    if (json.containsKey('suggestions')) {
      final suggestions = json['suggestions'] as List<dynamic>;
      final firstMatch = suggestions.isNotEmpty ? suggestions[0] : null;

      if (firstMatch != null && firstMatch is Map<String, dynamic>) {
        // Hastalık tespiti
        List<Disease> diseases = [];
        bool isHealthy = true;

        if (json.containsKey('health_assessment') &&
            json['health_assessment'] is Map<String, dynamic>) {
          final health = json['health_assessment'] as Map<String, dynamic>;
          isHealthy = health['is_healthy'] ?? true;

          if (health.containsKey('diseases') && health['diseases'] is List) {
            diseases = (health['diseases'] as List<dynamic>)
                .map((disease) =>
                    Disease.fromJson(disease as Map<String, dynamic>))
                .toList();
          }
        }

        // Gelişim durumu bilgisini al
        String? growthStage;
        int? growthScore;

        if (json.containsKey('growth_assessment') &&
            json['growth_assessment'] is Map<String, dynamic>) {
          final growth = json['growth_assessment'] as Map<String, dynamic>;
          growthStage = growth['stage']?.toString();
          growthScore = growth['score'] is int ? growth['score'] : null;
        } else if (firstMatch.containsKey('plant_details')) {
          // plant_details bir Map değilse, dönüştürmeyi dene
          var plantDetails = firstMatch['plant_details'];
          if (plantDetails is String) {
            // String ise Map'e dönüştür
            plantDetails = {'description': plantDetails};
            firstMatch['plant_details'] = plantDetails;
          }

          if (plantDetails is Map<String, dynamic> &&
              plantDetails.containsKey('growth_assessment') &&
              plantDetails['growth_assessment'] is Map<String, dynamic>) {
            final growth =
                plantDetails['growth_assessment'] as Map<String, dynamic>;
            growthStage = growth['stage']?.toString();
            growthScore = growth['score'] is int ? growth['score'] : null;
          }
        }

        // plant_details kontrolü
        Map<String, dynamic> plantDetails = {};
        if (firstMatch.containsKey('plant_details')) {
          if (firstMatch['plant_details'] is Map<String, dynamic>) {
            plantDetails = firstMatch['plant_details'] as Map<String, dynamic>;
          } else if (firstMatch['plant_details'] is String) {
            // String tipinde geldiyse Map'e dönüştür
            plantDetails = {'description': firstMatch['plant_details']};
          }
        }

        return PlantAnalysisResult(
          id: json['id'] ?? '',
          plantName: firstMatch['plant_name']?.toString() ?? 'Bilinmeyen Bitki',
          probability: firstMatch['probability'] is num
              ? firstMatch['probability']!.toDouble()
              : 0.0,
          isHealthy: isHealthy,
          diseases: diseases,
          description: plantDetails['description']?.toString() ?? '',
          suggestions: _extractSuggestions(json),
          imageUrl:
              json['images'] is List && (json['images'] as List).isNotEmpty
                  ? json['images'][0].toString()
                  : '',
          similarImages: _extractSimilarImages(json),
          taxonomy: plantDetails.containsKey('taxonomy') &&
                  plantDetails['taxonomy'] is Map
              ? PlantTaxonomy.fromJson(
                  plantDetails['taxonomy'] as Map<String, dynamic>)
              : null,
          edibleParts: _convertToStringList(
            plantDetails['edible_parts'],
          ),
          propagationMethods: _convertToStringList(
            plantDetails['propagation_methods'],
          ),
          watering: plantDetails['watering']?.toString(),
          sunlight: plantDetails['sunlight']?.toString(),
          soil: plantDetails['soil']?.toString(),
          climate: plantDetails['climate']?.toString(),
          geminiAnalysis: plantDetails['gemini_analysis']?.toString(),
          location: plantDetails['location']?.toString(),
          fieldName: plantDetails['field_name']?.toString(),
          growthStage: growthStage,
          growthScore: growthScore,
          timestamp: json['timestamp'] is int ? json['timestamp'] : null,
          growthComment: plantDetails['growth_comment']?.toString(),
          interventionMethods: _convertToStringList(
            plantDetails['intervention_methods'],
          ),
          agriculturalTips: _convertToStringList(
            plantDetails['agricultural_tips'],
          ),
          regionalInfo: _convertToStringList(
            plantDetails['regional_info'],
          ),
          rawResponse: json,
          // Yeni alanlar - API response parsing
          diseaseName:
              plantDetails['diseaseName'] ?? plantDetails['disease_name'],
          diseaseDescription: plantDetails['diseaseDescription'] ??
              plantDetails['disease_description'],
          treatmentName:
              plantDetails['treatmentName'] ?? plantDetails['treatment_name'],
          dosagePerDecare: plantDetails['dosagePerDecare'] ??
              plantDetails['dosage_per_decare'],
          applicationMethod: plantDetails['applicationMethod'] ??
              plantDetails['application_method'],
          applicationTime: plantDetails['applicationTime'] ??
              plantDetails['application_time'],
          applicationFrequency: plantDetails['applicationFrequency'] ??
              plantDetails['application_frequency'],
          waitingPeriod:
              plantDetails['waitingPeriod'] ?? plantDetails['waiting_period'],
          effectiveness: plantDetails['effectiveness'],
          notes: plantDetails['notes'],
          suggestion: plantDetails['suggestion'],
          intervention: plantDetails['intervention'],
          agriculturalTip: plantDetails['agriculturalTip'] ??
              plantDetails['agricultural_tip'],
        );
      }
    }

    // Sağlık analizi API'sinden gelen yanıtı işleme
    if (json.containsKey('health_assessment') &&
        json['health_assessment'] is Map<String, dynamic>) {
      final health = json['health_assessment'] as Map<String, dynamic>;
      final isHealthy = health['is_healthy'] ?? true;

      List<Disease> diseases = [];
      if (health.containsKey('diseases') && health['diseases'] is List) {
        diseases = (health['diseases'] as List)
            .whereType<Map<String, dynamic>>()
            .map((disease) => Disease.fromJson(disease as Map<String, dynamic>))
            .toList();
      }

      // Gelişim durumu bilgisini al
      String? growthStage;
      int? growthScore;

      if (json.containsKey('growth_assessment') &&
          json['growth_assessment'] is Map<String, dynamic>) {
        final growth = json['growth_assessment'] as Map<String, dynamic>;
        growthStage = growth['stage']?.toString();
        growthScore = growth['score'] is int ? growth['score'] : null;
      }

      // plant_details kontrolü
      Map<String, dynamic> plantDetails = {};
      if (json.containsKey('plant_details')) {
        if (json['plant_details'] is Map<String, dynamic>) {
          plantDetails = json['plant_details'] as Map<String, dynamic>;
        } else if (json['plant_details'] is String) {
          plantDetails = {'description': json['plant_details']};
        }
      }

      return PlantAnalysisResult(
        id: json['id'] ?? '',
        plantName: plantDetails.containsKey('common_names') &&
                plantDetails['common_names'] is List &&
                (plantDetails['common_names'] as List).isNotEmpty
            ? plantDetails['common_names'][0].toString()
            : 'Bilinmeyen Bitki',
        probability:
            1.0, // Sağlık değerlendirmesinde genellikle olasılık verilmez
        isHealthy: isHealthy,
        diseases: diseases,
        description: plantDetails['description']?.toString() ?? '',
        suggestions: _extractTreatments(health),
        imageUrl: json['images'] is List && (json['images'] as List).isNotEmpty
            ? json['images'][0].toString()
            : '',
        similarImages: _extractSimilarImages(json),
        taxonomy: null,
        edibleParts: null,
        propagationMethods: null,
        watering: null,
        sunlight: null,
        soil: null,
        climate: null,
        geminiAnalysis: null,
        location: plantDetails['location']?.toString(),
        fieldName: plantDetails['field_name']?.toString(),
        growthStage: growthStage,
        growthScore: growthScore,
        timestamp: json['timestamp'] is int ? json['timestamp'] : null,
        growthComment: plantDetails['growth_comment']?.toString(),
        interventionMethods: null,
        agriculturalTips: null,
        regionalInfo: null,
        rawResponse: json,
        // Yeni alanlar - health assessment parsing
        diseaseName:
            plantDetails['diseaseName'] ?? plantDetails['disease_name'],
        diseaseDescription: plantDetails['diseaseDescription'] ??
            plantDetails['disease_description'],
        treatmentName:
            plantDetails['treatmentName'] ?? plantDetails['treatment_name'],
        dosagePerDecare: plantDetails['dosagePerDecare'] ??
            plantDetails['dosage_per_decare'],
        applicationMethod: plantDetails['applicationMethod'] ??
            plantDetails['application_method'],
        applicationTime:
            plantDetails['applicationTime'] ?? plantDetails['application_time'],
        applicationFrequency: plantDetails['applicationFrequency'] ??
            plantDetails['application_frequency'],
        waitingPeriod:
            plantDetails['waitingPeriod'] ?? plantDetails['waiting_period'],
        effectiveness: plantDetails['effectiveness'],
        notes: plantDetails['notes'],
        suggestion: plantDetails['suggestion'],
        intervention: plantDetails['intervention'],
        agriculturalTip:
            plantDetails['agriculturalTip'] ?? plantDetails['agricultural_tip'],
      );
    }

    // Firestore'dan gelen veriler - özel alanlar ile
    try {
      List<Disease> diseases = [];

      // Disease listesini dönüştür (eğer varsa)
      if (json.containsKey('diseases') && json['diseases'] is List) {
        diseases = (json['diseases'] as List)
            .whereType<Map<String, dynamic>>()
            .map((disease) {
          final diseaseMap = disease as Map<String, dynamic>;
          return Disease.fromJson(diseaseMap);
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
        taxonomy = PlantTaxonomy.fromJson(taxMap);
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
        growthComment: json['growthComment'],
        interventionMethods: _convertToStringList(
          json['interventionMethods'],
        ),
        agriculturalTips: _convertToStringList(
          json['agriculturalTips'],
        ),
        regionalInfo: _convertToStringList(
          json['regionalInfo'],
        ),
        rawResponse: json,
        // Yeni alanlar - Firestore'dan parsing
        diseaseName: json['diseaseName'],
        diseaseDescription: json['diseaseDescription'],
        treatmentName: json['treatmentName'],
        dosagePerDecare: json['dosagePerDecare'],
        applicationMethod: json['applicationMethod'],
        applicationTime: json['applicationTime'],
        applicationFrequency: json['applicationFrequency'],
        waitingPeriod: json['waitingPeriod'],
        effectiveness: json['effectiveness'],
        notes: json['notes'],
        suggestion: json['suggestion'],
        intervention: json['intervention'],
        agriculturalTip: json['agriculturalTip'],
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
        growthComment: '',
        rawResponse: null,
        // Yeni alanlar - hata durumu için null
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

  /// JSON'dan string listesi çıkarma yardımcı methodu
  static List<String>? _convertToStringList(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is List) {
      return value.map((item) => item.toString()).toList();
    } else if (value is String) {
      // Tek bir string değeri alıp liste haline getirir
      return [value];
    }

    return null;
  }

  /// Tedavi listesini çıkaran yardımcı metod
  static List<String>? _extractTreatmentList(
      Map<String, dynamic>? treatment, String field) {
    if (treatment == null) return null;

    if (!treatment.containsKey(field)) return null;

    final list = treatment[field];
    if (list is List) {
      return List<String>.from(list.map((item) => item.toString()));
    } else if (list is String) {
      return [list];
    }

    return null;
  }

  /// Sağlık önerilerini çıkartan yardımcı metot
  static List<String> _extractTreatments(Map<String, dynamic> health) {
    final List<String> treatments = [];

    try {
      if (health.containsKey('diseases')) {
        final diseases = health['diseases'];
        if (diseases is List) {
          for (final disease in diseases) {
            if (disease is! Map<String, dynamic>) continue;

            if (disease.containsKey('treatment')) {
              final treatment = disease['treatment'];
              if (treatment is! Map<String, dynamic>) continue;

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
      }

      // Eğer hastalık tedavileri bulunamadıysa, health nesnesinde diğer ipuçlarını arayalım
      if (treatments.isEmpty && health.containsKey('suggestions')) {
        final suggestions = health['suggestions'];
        if (suggestions is List) {
          treatments.addAll(suggestions.map((e) => e.toString()));
        } else if (suggestions is String) {
          treatments.add(suggestions);
        }
      }

      return treatments;
    } catch (e) {
      print('_extractTreatments hatası: $e');
      return ['Bakım önerisi çıkarılırken hata oluştu'];
    }
  }

  /// Benzer görüntüleri çıkartan yardımcı metot
  static List<String> _extractSimilarImages(Map<String, dynamic> json) {
    try {
      List<String> images = [];

      if (json.containsKey('similar_images') &&
          json['similar_images'] is List) {
        for (var img in json['similar_images'] as List) {
          if (img is Map && img.containsKey('url')) {
            images.add(img['url'].toString());
          } else if (img is String) {
            images.add(img);
          }
        }
      } else if (json.containsKey('similarImages') &&
          json['similarImages'] is List) {
        images =
            (json['similarImages'] as List).map((e) => e.toString()).toList();
      }

      return images;
    } catch (e) {
      print('Benzer görüntüleri çıkarma hatası: $e');
      return [];
    }
  }

  /// Önerileri çıkaran yardımcı metot
  static List<String> _extractSuggestions(Map<String, dynamic> json) {
    try {
      List<String> suggestions = [];

      if (json.containsKey('suggestions') && json['suggestions'] is List) {
        final suggestionsList = json['suggestions'] as List;

        for (var suggestion in suggestionsList) {
          if (suggestion is Map<String, dynamic>) {
            // Bazı API yanıtlarında öneriler nesneler halinde geliyor
            if (suggestion.containsKey('suggestion')) {
              suggestions.add(suggestion['suggestion'].toString());
            } else if (suggestion.containsKey('text')) {
              suggestions.add(suggestion['text'].toString());
            }
          } else if (suggestion is String) {
            suggestions.add(suggestion);
          }
        }
      } else if (json.containsKey('health_assessment') &&
          json['health_assessment'] is Map<String, dynamic>) {
        // Sağlık değerlendirmesinden öneriler çıkarma
        suggestions = _extractTreatments(
            json['health_assessment'] as Map<String, dynamic>);
      }

      // Boşsa varsayılan öneri ekle
      if (suggestions.isEmpty) {
        suggestions = [
          'Düzenli sulama yapın',
          'Bitkinin ihtiyacına göre güneş ışığı sağlayın',
          'Toprak durumunu kontrol edin'
        ];
      }

      return suggestions;
    } catch (e) {
      print('Önerileri çıkarma hatası: $e');
      return ['Bakım önerileri çıkarılırken hata oluştu'];
    }
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
        growthComment,
        interventionMethods,
        agriculturalTips,
        regionalInfo,
        rawResponse,
        // Yeni alanlar - Equatable karşılaştırması için
        diseaseName,
        diseaseDescription,
        treatmentName,
        dosagePerDecare,
        applicationMethod,
        applicationTime,
        applicationFrequency,
        waitingPeriod,
        effectiveness,
        notes,
        suggestion,
        intervention,
        agriculturalTip,
      ];

  /// Boş bir analiz sonucu oluşturur
  static PlantAnalysisResult createEmpty({
    required String imageUrl,
    required String location,
    String? fieldName,
    String? errorMessage,
    String? originalText,
  }) {
    return PlantAnalysisResult(
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
      watering: '',
      sunlight: '',
      soil: '',
      climate: '',
      growthStage: '',
      growthScore: 0,
      growthComment: errorMessage ?? 'Görüntü analiz edilemedi',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: location,
      fieldName: fieldName,
      geminiAnalysis: '',
      interventionMethods: [],
      agriculturalTips: [],
      regionalInfo: [],
      rawResponse: originalText != null ? {'original': originalText} : null,
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
    this.probability,
    this.description,
    this.symptoms,
    this.treatments,
    this.interventionMethods,
    this.pesticideSuggestions,
    this.severity,
    this.affectedParts,
    this.causalAgent,
    this.preventiveMeasures,
    this.imageUrls,
    this.similarDiseases,
  });

  final String name;
  final double? probability;
  final String? description;
  final List<String>? symptoms;
  final List<String>? treatments;
  final List<String>? interventionMethods;
  final List<String>? pesticideSuggestions;
  final String? severity;
  final List<String>? affectedParts;
  final String? causalAgent;
  final List<String>? preventiveMeasures;
  final List<String>? imageUrls;
  final List<String>? similarDiseases;

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      name: json['name'] as String? ?? 'Bilinmeyen Hastalık',
      probability: (json['probability'] as num?)?.toDouble(),
      description: json['description'] as String?,
      symptoms: (json['symptoms'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      treatments: (json['treatments'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      interventionMethods: (json['interventionMethods'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      pesticideSuggestions: (json['pesticideSuggestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      severity: json['severity'] as String?,
      affectedParts: (json['affected_parts'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      causalAgent: json['causal_agent'] as String?,
      preventiveMeasures: (json['preventive_measures'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      imageUrls: (json['image_urls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      similarDiseases: (json['similar_diseases'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'probability': probability,
        'description': description,
        'symptoms': symptoms,
        'treatments': treatments,
        'interventionMethods': interventionMethods,
        'pesticideSuggestions': pesticideSuggestions,
        'severity': severity,
        'affected_parts': affectedParts,
        'causal_agent': causalAgent,
        'preventive_measures': preventiveMeasures,
        'image_urls': imageUrls,
        'similar_diseases': similarDiseases,
      };

  @override
  List<Object?> get props => [
        name,
        probability,
        description,
        symptoms,
        treatments,
        interventionMethods,
        pesticideSuggestions,
        severity,
        affectedParts,
        causalAgent,
        preventiveMeasures,
        imageUrls,
        similarDiseases,
      ];
}

/// Tedavi önerileri modeli
class Treatment extends Equatable {
  const Treatment({this.biological, this.chemical, this.prevention});

  final List<String>? biological;
  final List<String>? chemical;
  final List<String>? prevention;

  factory Treatment.fromJson(Map<String, dynamic> json) {
    try {
      // Listeleri güvenli şekilde dönüştür
      List<String>? convertToStringList(dynamic value) {
        if (value == null) return null;
        if (value is List) {
          return value.map((e) => e.toString()).toList();
        } else if (value is String) {
          return [value];
        }
        return null;
      }

      return Treatment(
        biological: convertToStringList(json['biological']),
        chemical: convertToStringList(json['chemical']),
        prevention: convertToStringList(json['prevention']),
      );
    } catch (e) {
      print('Treatment.fromJson hata: $e');
      return const Treatment();
    }
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
      'diseases': diseases.map((disease) => disease.toJson()).toList(),
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
      'taxonomy': taxonomy?.toMap(),
      'location': location,
      'fieldName': fieldName,
      'growthStage': growthStage,
      'growthScore': growthScore,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'growthComment': growthComment,
      'interventionMethods': interventionMethods,
      'agriculturalTips': agriculturalTips,
      'regionalInfo': regionalInfo,
      'rawResponse': rawResponse,
      // Yeni alanlar - JSON serialization
      'diseaseName': diseaseName,
      'diseaseDescription': diseaseDescription,
      'treatmentName': treatmentName,
      'dosagePerDecare': dosagePerDecare,
      'applicationMethod': applicationMethod,
      'applicationTime': applicationTime,
      'applicationFrequency': applicationFrequency,
      'waitingPeriod': waitingPeriod,
      'effectiveness': effectiveness,
      'notes': notes,
      'suggestion': suggestion,
      'intervention': intervention,
      'agriculturalTip': agriculturalTip,
    };
  }
}

/// PlantAnalysisResult için UI yardımcı metodları
extension PlantAnalysisResultUIExtension on PlantAnalysisResult {
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
      final percentage = (disease.probability! * 100).toStringAsFixed(0);
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

/// Metinden hastalıkları çıkar
void _extractDiseasesFromText(String text, Map<String, dynamic> target) {
  List<Map<String, dynamic>> diseases = [];
  final lowerText = text.toLowerCase();

  // 1. Önce belirli hastalık adlarını aramaya çalış
  final diseasePatterns = {
    'yaprak yanıklığı': 0.8,
    'kök çürüklüğü': 0.8,
    'külleme': 0.8,
    'pas hastalığı': 0.7,
    'mildiyö': 0.8,
    'antraknoz': 0.8,
    'mozaik virüsü': 0.75,
    'kurşuni küf': 0.7,
    'beyaz sinek': 0.7,
    'yaprak biti': 0.75,
    'kırmızı örümcek': 0.7,
    'fusarium': 0.8,
    'alternaria': 0.8,
    'septoria': 0.8,
    'verticillium': 0.8,
    'bakteriyel solgunluk': 0.8,
    'nematod': 0.7,
    'beslenme eksikliği': 0.6,
    'güneş yanığı': 0.6,
    'su stresi': 0.65,
  };

  // Hastalık belirten terimleri ara
  bool hasAnyDiseaseIndication = lowerText.contains('hastalık') ||
      lowerText.contains('hasar') ||
      lowerText.contains('zarar') ||
      lowerText.contains('enfeksiyon') ||
      lowerText.contains('belirti') ||
      lowerText.contains('çürük') ||
      lowerText.contains('küf') ||
      lowerText.contains('leke') ||
      lowerText.contains('sararmış') ||
      lowerText.contains('solmuş');

  // Hastalık adlarını metin içinde ara
  for (var disease in diseasePatterns.entries) {
    if (lowerText.contains(disease.key)) {
      // Hastalık adının geçtiği cümleyi bul
      int startIdx = lowerText.indexOf(disease.key);

      // Cümlenin başlangıcını bul
      int sentenceStart = lowerText.lastIndexOf('.', startIdx);
      if (sentenceStart < 0) {
        sentenceStart = lowerText.lastIndexOf('\n', startIdx);
      }
      if (sentenceStart < 0) sentenceStart = 0;
      sentenceStart += 1; // Noktayı dahil etme

      // Cümlenin sonunu bul
      int sentenceEnd = lowerText.indexOf('.', startIdx + disease.key.length);
      if (sentenceEnd < 0) {
        sentenceEnd = lowerText.indexOf('\n', startIdx + disease.key.length);
      }
      if (sentenceEnd < 0) sentenceEnd = lowerText.length;

      String description = text.substring(sentenceStart, sentenceEnd).trim();

      // Hastalığa uygun tedavi önerilerini bul
      List<String> treatments = [];
      if (lowerText.contains('tedavi') ||
          lowerText.contains('öneri') ||
          lowerText.contains('müdahale') ||
          lowerText.contains('yapılmalı')) {
        final treatmentRegex = RegExp(
            r'(?:tedavi|öneri|müdahale|yapılmalı)[^\.]*\.',
            caseSensitive: false);
        final treatmentMatches = treatmentRegex.allMatches(lowerText);

        for (var match in treatmentMatches) {
          treatments.add(text.substring(match.start, match.end).trim());
        }
      }

      // Hastalık kapitalize edilmiş adı
      String capitalizedName = disease.key
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');

      diseases.add({
        'name': capitalizedName,
        'probability': disease.value,
        'description': description,
        'treatments': treatments,
      });
    }
  }

  // 2. "Hastalık" kelimesini içeren bölümü ara (eğer belirli hastalıklar bulunamadıysa)
  if (diseases.isEmpty && hasAnyDiseaseIndication) {
    // Hastalık bölümünü bul
    final diseaseSection = RegExp(r'(?:hastalık|enfeksiyon|belirti)[^\n\.]+',
        caseSensitive: false);
    final matches = diseaseSection.allMatches(lowerText);

    for (var match in matches) {
      final content = text.substring(match.start, match.end).trim();

      // Genel bir hastalık girişi oluştur
      diseases.add({
        'name': 'Bitki Hastalığı',
        'probability': 0.7,
        'description': content,
        'treatments': [],
      });
    }
  }

  // 3. Sağlıklı olup olmadığını belirle
  bool isHealthy = true;

  if (diseases.isNotEmpty) {
    isHealthy = false; // Hastalık bulunduysa sağlıksız
  } else if (lowerText.contains('hastalık yok') ||
      lowerText.contains('sağlıklı görünüyor') ||
      lowerText.contains('sağlıklı bir bitki')) {
    isHealthy = true; // Açıkça sağlıklı olduğu belirtildi
  } else if (hasAnyDiseaseIndication) {
    // Hastalık belirtisi var ama spesifik hastalık bulunamadı
    isHealthy = false;
    diseases.add({
      'name': 'Belirsiz Hastalık Belirtileri',
      'probability': 0.6,
      'description':
          'Bitkide hastalık belirtileri görülüyor ancak spesifik bir tanı yapılamadı.',
      'treatments': [
        'Profesyonel bir ziraat mühendisine danışın.',
        'Düzenli gözlem yapın ve değişimleri not edin.',
        'Sulama ve gübreleme rutininizi gözden geçirin.'
      ],
    });
  }

  // Hastalık durumunu ve varsa hastalıkları ekle
  target['isHealthy'] = isHealthy;
  target['diseases'] = diseases;

  AppLogger.i('Hastalık durumu tespit edildi',
      'Sağlıklı: ${target["isHealthy"]}, Tespit edilen hastalık sayısı: ${diseases.length}');
}
