import 'dart:convert';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_result.dart';

/// Gemini API response'larını parse eden service
///
/// Bu service, Gemini'den gelen JSON yanıtlarını validasyon ile
/// PlantAnalysisResult modeline dönüştürür.
class GeminiResponseParser {
  static const String _serviceName = 'GeminiResponseParser';

  /// Gemini JSON response'ını PlantAnalysisResult'a parse eder
  ///
  /// [rawResponse] - Gemini'den gelen ham JSON string
  /// [imageUrl] - Analiz edilen görüntünün URL'si
  /// [location] - Konum bilgisi
  /// [fieldName] - Tarla adı (opsiyonel)
  ///
  /// Returns: Başarıyla parse edilmiş PlantAnalysisResult
  /// Throws: FormatException, JsonUnsupportedObjectError
  static Future<PlantAnalysisResult> parseAnalysisResponse({
    required String rawResponse,
    required String imageUrl,
    String? location,
    String? fieldName,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🔄 Gemini response parsing başlatılıyor...',
        'Response uzunluğu: ${rawResponse.length} karakter',
      );

      // 1. JSON Pre-processing
      final cleanedJson = _preprocessJsonResponse(rawResponse);

      // 2. JSON Parsing ile detaylı hata yakalama
      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(cleanedJson);
        AppLogger.successWithContext(
          _serviceName,
          '✅ JSON decode başarılı',
          'Keys: ${jsonData.keys.join(", ")}',
        );
      } catch (jsonError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ JSON decode hatası',
          'Error: $jsonError\nCleaned JSON: ${cleanedJson.substring(0, cleanedJson.length > 300 ? 300 : cleanedJson.length)}...',
        );

        // JSON decode başarısız - intelligent fallback dene
        final fallbackData =
            _attemptIntelligentParsing(rawResponse, cleanedJson);
        if (fallbackData != null) {
          jsonData = fallbackData;
          AppLogger.logWithContext(
            _serviceName,
            '🔧 Intelligent fallback başarılı',
            'Keys: ${jsonData.keys.join(", ")}',
          );
        } else {
          // Hiçbir recovery işe yaramadı - fallback response döndür
          return _createFallbackResponse(
            rawResponse: rawResponse,
            imageUrl: imageUrl,
            location: location,
            fieldName: fieldName,
            error: 'JSON decode error: $jsonError',
          );
        }
      }

      // 3. Schema Validation ile toleranslı kontrol
      try {
        _validateResponseSchema(jsonData);
      } catch (validationError) {
        AppLogger.logWithContext(
          _serviceName,
          '⚠️ Schema validation başarısız, recovery deneniyor',
          validationError.toString(),
        );

        // Schema sorunları için recovery
        jsonData = _repairJsonSchema(jsonData);

        // Tekrar validation dene
        try {
          _validateResponseSchema(jsonData);
          AppLogger.logWithContext(
            _serviceName,
            '✅ Schema recovery başarılı',
          );
        } catch (secondValidationError) {
          AppLogger.errorWithContext(
            _serviceName,
            '❌ Schema recovery başarısız',
            secondValidationError.toString(),
          );

          // Schema recovery başarısız - fallback döndür
          return _createFallbackResponse(
            rawResponse: rawResponse,
            imageUrl: imageUrl,
            location: location,
            fieldName: fieldName,
            error: 'Schema validation error: $validationError',
          );
        }
      }

      // 4. Model Construction
      final result = _buildPlantAnalysisResult(
        jsonData: jsonData,
        imageUrl: imageUrl,
        location: location,
        fieldName: fieldName,
      );

      AppLogger.successWithContext(
        _serviceName,
        '✅ Response parsing başarılı',
        'Bitki: ${result.plantName}, Hastalık sayısı: ${result.diseases.length}',
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        '❌ Response parsing genel hatası',
        e,
        stackTrace,
      );

      // Genel hata durumunda fallback response döndür
      return _createFallbackResponse(
        rawResponse: rawResponse,
        imageUrl: imageUrl,
        location: location,
        fieldName: fieldName,
        error: e.toString(),
      );
    }
  }

  /// JSON response'ını temizler ve hazırlar
  static String _preprocessJsonResponse(String rawResponse) {
    AppLogger.logWithContext(
      _serviceName,
      '🔍 JSON preprocessing başlıyor',
      'Ham yanıt uzunluğu: ${rawResponse.length}',
    );

    // DEBUG: Ham yanıtın ilk kısmını logla
    AppLogger.logWithContext(
      _serviceName,
      '🔹 Ham yanıt örneği:',
      rawResponse.substring(
          0, rawResponse.length > 200 ? 200 : rawResponse.length),
    );

    String cleaned = rawResponse.trim();

    // 1. Markdown kod bloklarını temizle
    if (cleaned.contains('```json')) {
      final startIndex = cleaned.indexOf('```json') + 7;
      final endIndex = cleaned.lastIndexOf('```');
      if (startIndex > 7 && endIndex > startIndex) {
        cleaned = cleaned.substring(startIndex, endIndex).trim();
        AppLogger.logWithContext(
            _serviceName, '🧹 Markdown JSON bloğu temizlendi');
      }
    } else if (cleaned.startsWith('```') && cleaned.endsWith('```')) {
      cleaned = cleaned.substring(3, cleaned.length - 3).trim();
      AppLogger.logWithContext(
          _serviceName, '🧹 Markdown kod bloğu temizlendi');
    }

    // 2. Çoklu JSON bloklarını kontrol et (bazen Gemini birden fazla blok döndürür)
    if (cleaned.contains('}{')) {
      AppLogger.logWithContext(
          _serviceName, '⚠️ Çoklu JSON bloğu tespit edildi, ilkini alıyoruz');
      final firstJsonEnd = cleaned.indexOf('}{') + 1;
      cleaned = cleaned.substring(0, firstJsonEnd);
    }

    // 3. BOM ve whitespace temizliği
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1);
      AppLogger.logWithContext(_serviceName, '🧹 BOM karakteri temizlendi');
    }

    // 4. Control characters'ı temizle
    final beforeControlClean = cleaned.length;
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    if (cleaned.length != beforeControlClean) {
      AppLogger.logWithContext(_serviceName,
          '🧹 Control karakterler temizlendi: ${beforeControlClean - cleaned.length} karakter');
    }

    // 5. Yaygın JSON hatalarını düzelt
    // Trailing comma'ları temizle
    cleaned = cleaned.replaceAll(RegExp(r',\s*}'), '}');
    cleaned = cleaned.replaceAll(RegExp(r',\s*]'), ']');

    // 6. Unicode karakterleri düzelt
    cleaned = cleaned.replaceAll('\\u0000', '');

    // 7. JSON başlangıç ve bitiş kontrolü
    if (!cleaned.startsWith('{') && !cleaned.startsWith('[')) {
      AppLogger.logWithContext(
          _serviceName, '⚠️ JSON başlangıcı bulunamadı, { arıyoruz');
      final firstBrace = cleaned.indexOf('{');
      if (firstBrace != -1) {
        cleaned = cleaned.substring(firstBrace);
        AppLogger.logWithContext(_serviceName, '🔧 JSON başlangıcı düzeltildi');
      }
    }

    if (!cleaned.endsWith('}') && !cleaned.endsWith(']')) {
      AppLogger.logWithContext(
          _serviceName, '⚠️ JSON bitişi bulunamadı, son } arıyoruz');
      final lastBrace = cleaned.lastIndexOf('}');
      if (lastBrace != -1) {
        cleaned = cleaned.substring(0, lastBrace + 1);
        AppLogger.logWithContext(_serviceName, '🔧 JSON bitişi düzeltildi');
      }
    }

    // DEBUG: Temizlenmiş yanıtın örneğini logla
    AppLogger.logWithContext(
      _serviceName,
      '✅ JSON preprocessing tamamlandı',
      'Temizlenmiş uzunluk: ${cleaned.length}, İlk 200 karakter: ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}',
    );

    // 8. JSON syntax validation denemesi
    try {
      json.decode(cleaned);
      AppLogger.logWithContext(
          _serviceName, '✅ JSON syntax validation başarılı');
    } catch (e) {
      AppLogger.logWithContext(
          _serviceName, '❌ JSON syntax validation hatası: $e');

      // Son çare: problematik karakterleri daha agresif temizle
      cleaned = _aggressiveJsonCleanup(cleaned);

      try {
        json.decode(cleaned);
        AppLogger.logWithContext(
            _serviceName, '✅ Agresif temizlik sonrası JSON geçerli');
      } catch (e2) {
        AppLogger.logWithContext(
            _serviceName, '❌ Agresif temizlik sonrası hala JSON hatası: $e2');
      }
    }

    return cleaned;
  }

  /// Agresif JSON temizleme (son çare)
  static String _aggressiveJsonCleanup(String jsonStr) {
    AppLogger.logWithContext(
        _serviceName, '🚨 Agresif JSON temizlik başlatılıyor');

    String cleaned = jsonStr;

    // 1. Çoklu boşlukları tek boşluğa çevir
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // 2. String değerlerdeki problematik karakterleri temizle
    // Sadece string içindeki quotes'ları koruyalım
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'"([^"]*)"'),
      (match) {
        final content = match.group(1) ?? '';
        final cleanContent = content
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ')
            .replaceAll('\t', ' ')
            .replaceAll(RegExp(r'[^\x20-\x7E\u00A0-\uFFFF]'),
                ''); // Sadece yazdırılabilir karakterler
        return '"$cleanContent"';
      },
    );

    // 3. JSON structure'ı yeniden oluştur
    try {
      // En temel gereksinimleri karşılayan minimal JSON oluştur
      if (!cleaned.contains('"plantName"')) {
        AppLogger.logWithContext(
            _serviceName, '🔧 plantName eksik, varsayılan değer ekleniyor');

        // Minimal geçerli JSON oluştur
        return '''{
  "plantName": "Bilinmeyen Bitki",
  "probability": 0.5,
  "isHealthy": false,
  "diseases": [],
  "description": "JSON parsing hatası nedeniyle analiz tamamlanamadı",
  "suggestions": ["Lütfen farklı bir görüntü ile tekrar deneyin"]
}''';
      }
    } catch (e) {
      AppLogger.logWithContext(_serviceName, '❌ Agresif temizlik hatası: $e');
    }

    return cleaned;
  }

  /// Response schema'sını validate eder
  static void _validateResponseSchema(Map<String, dynamic> json) {
    final List<String> missingFields = [];
    final List<String> invalidFields = [];

    // Zorunlu alanları kontrol et
    final requiredFields = {
      'plantName': String,
      'probability': num,
      'isHealthy': bool,
      'diseases': List,
      'description': String,
      'suggestions': List,
    };

    requiredFields.forEach((fieldName, expectedType) {
      if (!json.containsKey(fieldName)) {
        missingFields.add(fieldName);
      } else if (!_isValidType(json[fieldName], expectedType)) {
        invalidFields.add(
            '$fieldName (beklenen: $expectedType, gelen: ${json[fieldName].runtimeType})');
      }
    });

    // Hatalar varsa exception fırlat
    if (missingFields.isNotEmpty || invalidFields.isNotEmpty) {
      final errorMsg = StringBuffer('Schema validation hatası:\n');
      if (missingFields.isNotEmpty) {
        errorMsg.writeln('Eksik alanlar: ${missingFields.join(', ')}');
      }
      if (invalidFields.isNotEmpty) {
        errorMsg.writeln('Geçersiz alanlar: ${invalidFields.join(', ')}');
      }
      throw FormatException(errorMsg.toString());
    }

    AppLogger.logWithContext(_serviceName, '✅ Schema validation başarılı');
  }

  /// Type validation helper
  static bool _isValidType(dynamic value, Type expectedType) {
    switch (expectedType) {
      case String:
        return value is String;
      case num:
        return value is num;
      case bool:
        return value is bool;
      case List:
        return value is List;
      case Map:
        return value is Map;
      default:
        return false;
    }
  }

  /// PlantAnalysisResult model'ini oluşturur
  static PlantAnalysisResult _buildPlantAnalysisResult({
    required Map<String, dynamic> jsonData,
    required String imageUrl,
    String? location,
    String? fieldName,
  }) {
    return PlantAnalysisResult(
      id: _generateAnalysisId(),
      plantName: _extractPlantName(jsonData),
      probability: _extractProbability(jsonData),
      isHealthy: _extractIsHealthy(jsonData),
      diseases: _extractDiseases(jsonData),
      description: _extractDescription(jsonData),
      suggestions: _extractSuggestions(jsonData),
      imageUrl: imageUrl,
      similarImages: _extractSimilarImages(jsonData),
      taxonomy: null, // Şimdilik null
      edibleParts: _extractStringList(jsonData, 'edibleParts'),
      propagationMethods: _extractStringList(jsonData, 'propagationMethods'),
      watering: _extractString(jsonData, 'watering'),
      sunlight: _extractString(jsonData, 'sunlight'),
      soil: _extractString(jsonData, 'soil'),
      climate: _extractString(jsonData, 'climate'),
      geminiAnalysis: json.encode(jsonData), // Ham JSON'u sakla
      location: location,
      fieldName: fieldName,
      growthStage: _extractString(jsonData, 'growthStage'),
      growthScore: _extractInt(jsonData, 'growthScore'),
      growthComment: _extractString(jsonData, 'growthComment'),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      interventionMethods: _extractStringList(jsonData, 'interventionMethods'),
      agriculturalTips: _extractStringList(jsonData, 'agriculturalTips'),
      regionalInfo: _extractStringList(jsonData, 'regionalInfo'),
      rawResponse: jsonData,
    );
  }

  /// Analiz ID'si oluşturur
  static String _generateAnalysisId() {
    return 'analysis_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Bitki adını extract eder
  static String _extractPlantName(Map<String, dynamic> json) {
    final plantName = json['plantName'] as String?;
    if (plantName == null || plantName.trim().isEmpty) {
      throw FormatException('Bitki adı boş veya geçersiz');
    }
    return plantName.trim();
  }

  /// Probability değerini extract eder
  static double _extractProbability(Map<String, dynamic> json) {
    final probability = json['probability'];
    if (probability is num) {
      final value = probability.toDouble();
      if (value < 0.0 || value > 1.0) {
        AppLogger.logWithContext(
            _serviceName, '⚠️ Probability değeri normalize edildi: $value');
        return value.clamp(0.0, 1.0);
      }
      return value;
    }
    throw FormatException('Probability değeri geçersiz: $probability');
  }

  /// IsHealthy değerini extract eder
  static bool _extractIsHealthy(Map<String, dynamic> json) {
    final isHealthy = json['isHealthy'];
    if (isHealthy is bool) return isHealthy;
    if (isHealthy is String) {
      return isHealthy.toLowerCase() == 'true';
    }
    throw FormatException('isHealthy değeri geçersiz: $isHealthy');
  }

  /// Hastalık listesini extract eder
  static List<Disease> _extractDiseases(Map<String, dynamic> json) {
    final diseasesList = json['diseases'];
    if (diseasesList is! List) {
      throw FormatException(
          'Diseases listesi geçersiz: ${diseasesList.runtimeType}');
    }

    final List<Disease> diseases = [];
    for (int i = 0; i < diseasesList.length; i++) {
      try {
        final diseaseData = diseasesList[i];
        if (diseaseData is Map<String, dynamic>) {
          diseases.add(_parseDisease(diseaseData, i));
        } else {
          AppLogger.logWithContext(
              _serviceName, '⚠️ Geçersiz hastalık verisi index $i atlandı');
        }
      } catch (e) {
        AppLogger.logWithContext(
            _serviceName, '⚠️ Hastalık parsing hatası index $i: $e');
      }
    }

    return diseases;
  }

  /// Tek hastalık parse eder
  static Disease _parseDisease(Map<String, dynamic> diseaseJson, int index) {
    return Disease(
      name: _extractString(diseaseJson, 'name') ?? 'Hastalık ${index + 1}',
      probability: _extractDouble(diseaseJson, 'probability'),
      description: _extractString(diseaseJson, 'description'),
      symptoms: _extractStringList(diseaseJson, 'symptoms'),
      treatments: _extractStringList(diseaseJson, 'treatments'),
      interventionMethods:
          _extractStringList(diseaseJson, 'interventionMethods'),
      pesticideSuggestions:
          _extractStringList(diseaseJson, 'pesticideSuggestions'),
      severity: _extractString(diseaseJson, 'severity'),
      affectedParts: _extractStringList(diseaseJson, 'affectedParts'),
      causalAgent: _extractString(diseaseJson, 'causalAgent'),
      preventiveMeasures: _extractStringList(diseaseJson, 'preventiveMeasures'),
      imageUrls: _extractStringList(diseaseJson, 'imageUrls'),
      similarDiseases: _extractStringList(diseaseJson, 'similarDiseases'),
    );
  }

  /// Description extract eder
  static String _extractDescription(Map<String, dynamic> json) {
    return _extractString(json, 'description') ?? 'Açıklama mevcut değil';
  }

  /// Suggestions extract eder
  static List<String> _extractSuggestions(Map<String, dynamic> json) {
    return _extractStringList(json, 'suggestions') ?? [];
  }

  /// Similar images extract eder
  static List<String> _extractSimilarImages(Map<String, dynamic> json) {
    return _extractStringList(json, 'similarImages') ?? [];
  }

  // ============================================================================
  // HELPER EXTRACTION METHODS
  // ============================================================================

  /// String değer extract eder
  static String? _extractString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    return value.toString().trim().isEmpty ? null : value.toString().trim();
  }

  /// Double değer extract eder
  static double? _extractDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Int değer extract eder
  static int? _extractInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// String listesi extract eder
  static List<String>? _extractStringList(
      Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;

    if (value is List) {
      final stringList = value
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return stringList.isEmpty ? null : stringList;
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return null;
  }

  /// Fallback response oluşturur (hata durumunda)
  static PlantAnalysisResult _createFallbackResponse({
    required String rawResponse,
    required String imageUrl,
    String? location,
    String? fieldName,
    required String error,
  }) {
    AppLogger.logWithContext(
      _serviceName,
      '🔄 Fallback response oluşturuluyor',
      'Error: $error, Response length: ${rawResponse.length}',
    );

    // Ham yanıttan bazı bilgiler çıkarmaya çalış
    String plantName = 'Bilinmeyen Bitki';
    String description = 'Gemini yanıtı parse edilemedi ancak analiz yapıldı.';

    // Basit pattern matching ile bitki adı ve açıklama bulmaya çalış
    final extractedPlant = _extractValueByKey(rawResponse, 'plantName');
    if (extractedPlant != null && extractedPlant.trim().isNotEmpty) {
      plantName = extractedPlant;
    }

    final extractedDesc = _extractValueByKey(rawResponse, 'description');
    if (extractedDesc != null && extractedDesc.trim().isNotEmpty) {
      description = extractedDesc;
    }

    // Hata tipine göre özel mesajlar
    List<String> suggestions;
    if (error.contains('JSON decode')) {
      suggestions = [
        'Gemini analiz sonucu JSON formatında alınamadı',
        'Sistem farklı bir görüntü ile tekrar deneyecek',
        'Görüntünün kalitesini artırarak tekrar deneyin',
        'Farklı açıdan çekim yaparak tekrar deneyin',
      ];
    } else if (error.contains('Schema validation')) {
      suggestions = [
        'Analiz sonucu eksik bilgiler içeriyor',
        'Sistemsel hata düzeltme işlemleri devrede',
        'Daha detaylı görüntü ile tekrar deneyin',
        'Bitki yaprağı ve gövde daha net görünecek şekilde çekim yapın',
      ];
    } else {
      suggestions = [
        'Analiz sırasında teknik bir sorun oluştu',
        'Lütfen birkaç saniye bekleyip tekrar deneyin',
        'Görüntü kalitesini artırarak tekrar deneyin',
        'Farklı bir bitki fotoğrafı ile test edin',
      ];
    }

    AppLogger.logWithContext(
      _serviceName,
      '✅ Fallback response oluşturuldu',
      'Plant: $plantName, Error type: ${error.substring(0, 50)}...',
    );

    return PlantAnalysisResult(
      id: _generateAnalysisId(),
      plantName: plantName,
      probability: 0.3, // Kısmi güven
      isHealthy: false, // Güvenli taraf
      diseases: [],
      description: description,
      suggestions: suggestions,
      imageUrl: imageUrl,
      similarImages: [],
      taxonomy: null,
      edibleParts: null,
      propagationMethods: null,
      watering: 'Orta düzeyde sulama önerilir',
      sunlight: 'Kısmi gölge uygun olabilir',
      soil: 'İyi drene toprak tercih edilir',
      climate: 'Orta iklim uygun',
      geminiAnalysis: rawResponse, // Ham yanıtı sakla
      location: location,
      fieldName: fieldName,
      growthStage: 'Belirlenemedi',
      growthScore: 30, // Düşük skor - parse problemi nedeniyle
      growthComment:
          'Parse hatası nedeniyle tam analiz tamamlanamadı: ${error.length > 100 ? error.substring(0, 100) + "..." : error}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      interventionMethods: ['Teknik destek ile iletişime geçin'],
      agriculturalTips: [
        'Görüntü kalitesini artırın',
        'Farklı açıdan çekim yapın'
      ],
      regionalInfo: location != null ? ['Konum: $location'] : null,
      rawResponse: {
        'error': error,
        'error_type': _categorizeError(error),
        'raw_response': rawResponse.length > 2000
            ? '${rawResponse.substring(0, 2000)}...'
            : rawResponse,
        'parse_timestamp': DateTime.now().toIso8601String(),
        'recovery_attempts': 'intelligent_parsing,schema_repair,fallback',
      },
    );
  }

  /// Hata tipini kategorize eder
  static String _categorizeError(String error) {
    if (error.contains('JSON decode')) return 'JSON_DECODE_ERROR';
    if (error.contains('Schema validation')) return 'SCHEMA_VALIDATION_ERROR';
    if (error.contains('FormatException')) return 'FORMAT_ERROR';
    if (error.contains('timeout')) return 'TIMEOUT_ERROR';
    if (error.contains('network')) return 'NETWORK_ERROR';
    return 'GENERAL_ERROR';
  }

  /// Response quality metrics oluşturur
  static Map<String, dynamic> analyzeResponseQuality(
      PlantAnalysisResult result) {
    final metrics = <String, dynamic>{};

    // Completeness Score (0-100)
    int completenessScore = 0;
    int totalFields = 0;

    final fieldChecks = {
      'plantName': result.plantName.isNotEmpty,
      'description': result.description.isNotEmpty,
      'suggestions': result.suggestions.isNotEmpty,
      'diseases': result.diseases.isNotEmpty,
      'watering': result.watering != null,
      'sunlight': result.sunlight != null,
      'soil': result.soil != null,
      'climate': result.climate != null,
      'growthStage': result.growthStage != null,
      'growthScore': result.growthScore != null,
    };

    fieldChecks.forEach((field, hasValue) {
      totalFields++;
      if (hasValue) completenessScore++;
    });

    metrics['completeness_score'] =
        ((completenessScore / totalFields) * 100).round();
    metrics['total_diseases'] = result.diseases.length;
    metrics['has_treatment_info'] = result.diseases.any((d) =>
        (d.treatments?.isNotEmpty ?? false) ||
        (d.interventionMethods?.isNotEmpty ?? false) ||
        (d.pesticideSuggestions?.isNotEmpty ?? false));
    metrics['response_timestamp'] = DateTime.now().toIso8601String();

    return metrics;
  }

  /// Intelligent JSON parsing (ham metinden JSON çıkarma)
  static Map<String, dynamic>? _attemptIntelligentParsing(
      String originalResponse, String cleanedResponse) {
    AppLogger.logWithContext(
      _serviceName,
      '🤖 Intelligent parsing başlatılıyor',
      'Orijinal uzunluk: ${originalResponse.length}',
    );

    // 1. Farklı JSON pattern'leri dene
    final patterns = [
      // Curly braces arasındaki içerik
      RegExp(r'\{[^{}]*\}', multiLine: true, dotAll: true),
      // Nested braces'i de içeren pattern
      RegExp(r'\{(?:[^{}]|\{[^{}]*\})*\}', multiLine: true, dotAll: true),
      // Çok basit anahtar-değer çiftleri
      RegExp(r'"plantName"\s*:\s*"[^"]*"', multiLine: true),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(originalResponse);
      for (final match in matches) {
        try {
          final candidate = match.group(0);
          if (candidate != null && candidate.trim().isNotEmpty) {
            final parsed = json.decode(candidate);
            if (parsed is Map<String, dynamic> &&
                parsed.containsKey('plantName')) {
              AppLogger.logWithContext(
                _serviceName,
                '✅ Pattern match başarılı',
                'Pattern kullanıldı, Keys: ${parsed.keys.join(", ")}',
              );
              return parsed;
            }
          }
        } catch (e) {
          // Bu pattern işe yaramadı, devam et
          continue;
        }
      }
    }

    // 2. Manuel JSON reconstruction
    try {
      final reconstructed = _manualJsonReconstruction(originalResponse);
      if (reconstructed != null) {
        final parsed = json.decode(reconstructed);
        if (parsed is Map<String, dynamic>) {
          AppLogger.logWithContext(
            _serviceName,
            '✅ Manuel reconstruction başarılı',
          );
          return parsed;
        }
      }
    } catch (e) {
      AppLogger.logWithContext(
        _serviceName,
        '⚠️ Manuel reconstruction başarısız: $e',
      );
    }

    // 3. Metinden key-value çiftleri çıkar
    try {
      final extractedData = _extractKeyValuePairs(originalResponse);
      if (extractedData.isNotEmpty) {
        AppLogger.logWithContext(
          _serviceName,
          '✅ Key-value extraction başarılı',
          'Keys: ${extractedData.keys.join(", ")}',
        );
        return extractedData;
      }
    } catch (e) {
      AppLogger.logWithContext(
        _serviceName,
        '⚠️ Key-value extraction başarısız: $e',
      );
    }

    AppLogger.logWithContext(
      _serviceName,
      '❌ Tüm intelligent parsing yöntemleri başarısız',
    );
    return null;
  }

  /// Manuel JSON reconstruction
  static String? _manualJsonReconstruction(String text) {
    // Temel plant analizi alanlarını ara
    final plantName =
        _extractValueByKey(text, 'plantName') ?? 'Bilinmeyen Bitki';
    final isHealthy = _extractBooleanByKey(text, 'isHealthy') ?? false;
    final description =
        _extractValueByKey(text, 'description') ?? 'Analiz tamamlanamadı';
    final probability = _extractNumberByKey(text, 'probability') ?? 0.5;

    return '''{
  "plantName": "$plantName",
  "probability": $probability,
  "isHealthy": $isHealthy,
  "diseases": [],
  "description": "$description",
  "suggestions": ["Analiz kısmen tamamlandı", "Daha net görüntü ile tekrar deneyin"]
}''';
  }

  /// Metinden key-value çiftleri çıkarır
  static Map<String, dynamic> _extractKeyValuePairs(String text) {
    final result = <String, dynamic>{};

    // Temel alanları ara ve çıkar
    final basicFields = {
      'plantName': _extractValueByKey(text, 'plantName'),
      'description': _extractValueByKey(text, 'description'),
      'probability': _extractNumberByKey(text, 'probability'),
      'isHealthy': _extractBooleanByKey(text, 'isHealthy'),
    };

    basicFields.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });

    // Zorunlu alanları ekle
    result['plantName'] ??= 'Bilinmeyen Bitki';
    result['probability'] ??= 0.5;
    result['isHealthy'] ??= false;
    result['diseases'] ??= <Map<String, dynamic>>[];
    result['description'] ??= 'Kısmi analiz tamamlandı';
    result['suggestions'] ??= ['Tekrar deneyiniz'];

    return result;
  }

  /// JSON schema'sını onarır (eksik alanları ekler)
  static Map<String, dynamic> _repairJsonSchema(Map<String, dynamic> original) {
    AppLogger.logWithContext(
      _serviceName,
      '🔧 JSON schema repair başlatılıyor',
      'Mevcut keys: ${original.keys.join(", ")}',
    );

    final repaired = Map<String, dynamic>.from(original);

    // Zorunlu alanları kontrol et ve ekle
    repaired['plantName'] ??= 'Bilinmeyen Bitki';
    repaired['probability'] ??= 0.5;
    repaired['isHealthy'] ??= false;
    repaired['diseases'] ??= <Map<String, dynamic>>[];
    repaired['description'] ??= 'Schema onarımı yapıldı';
    repaired['suggestions'] ??= ['Analiz tamamlandı'];

    // Type corrections
    if (repaired['probability'] is String) {
      repaired['probability'] = double.tryParse(repaired['probability']) ?? 0.5;
    }

    if (repaired['isHealthy'] is String) {
      repaired['isHealthy'] =
          repaired['isHealthy'].toString().toLowerCase() == 'true';
    }

    if (repaired['diseases'] is! List) {
      repaired['diseases'] = <Map<String, dynamic>>[];
    }

    if (repaired['suggestions'] is! List) {
      repaired['suggestions'] = [repaired['suggestions'].toString()];
    }

    AppLogger.logWithContext(
      _serviceName,
      '✅ Schema repair tamamlandı',
      'Yeni keys: ${repaired.keys.join(", ")}',
    );

    return repaired;
  }

  /// Metinden key değeri çıkarır
  static String? _extractValueByKey(String text, String key) {
    final patterns = [
      RegExp('"$key"\\s*:\\s*"([^"]*)"'),
      RegExp('$key\\s*:\\s*"([^"]*)"'),
      RegExp('$key\\s*=\\s*"([^"]*)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  /// Metinden boolean değer çıkarır
  static bool? _extractBooleanByKey(String text, String key) {
    final patterns = [
      RegExp('"$key"\\s*:\\s*(true|false)'),
      RegExp('$key\\s*:\\s*(true|false)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1) == 'true';
      }
    }
    return null;
  }

  /// Metinden sayısal değer çıkarır
  static double? _extractNumberByKey(String text, String key) {
    final patterns = [
      RegExp('"$key"\\s*:\\s*([0-9]+\\.?[0-9]*)'),
      RegExp('$key\\s*:\\s*([0-9]+\\.?[0-9]*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }
}
