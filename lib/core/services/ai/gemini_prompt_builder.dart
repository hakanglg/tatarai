import 'gemini_model_config.dart';
// Future için PlantAnalysisModel import edilebilir reflection için
// import '../../../features/plant_analysis/data/models/plant_analysis_model.dart';

/// Gemini AI promptlarını oluşturan utility sınıfı
///
/// Bu sınıf, bitki analizi için optimize edilmiş promptları
/// merkezi bir şekilde oluşturur ve yönetir. DRY prensiplerine uyar.
/// Tüm promptlar İngilizce olarak gönderilir ancak yanıtlar kullanıcının
/// seçtiği dile göre döner.
class GeminiPromptBuilder {
  /// Private constructor - sadece static metotlar kullanılmalı
  GeminiPromptBuilder._();

  // ============================================================================
  // IMAGE ANALYSIS PROMPTS - Görsel analizi için prompt'lar
  // ============================================================================

  /// Kapsamlı bitki analizi prompt'u oluşturur
  ///
  /// [locationInfo] - Coğrafi konum bilgisi
  /// [language] - Yanıt dili (JSON değerleri için)
  static String buildImageAnalysisPrompt({
    required String locationInfo,
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    final roleDefinition = _buildRoleDefinition();
    final analysisInstructions = _buildAnalysisInstructions();
    final locationContext = _buildLocationContext(locationInfo);
    final jsonSchema = _buildJsonSchema(language);
    final criticalInstructions = _buildCriticalInstructions(language);

    return '''$roleDefinition

$analysisInstructions

$locationContext

$jsonSchema

$criticalInstructions

[START] Now analyze the image and respond in the JSON format specified above:''';
  }

  /// Hızlı bitki tanımlama prompt'u oluşturur
  static String buildQuickIdentificationPrompt({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return '''You are a plant expert. Quickly identify the plant in the image.

ONLY respond in JSON format:
{
  "plantName": "${_getPlantNameExample(language)}",
  "commonNames": ["${_getCommonNameExample(language, 1)}", "${_getCommonNameExample(language, 2)}"],
  "confidence": 0.95,
  "basicInfo": "${_getBasicInfoExample(language)}"
}

Analyze the image and provide JSON response:''';
  }

  // ============================================================================
  // TEXT GENERATION PROMPTS - Metin üretimi için prompt'lar
  // ============================================================================

  /// Bitki bakım tavsiyeleri prompt'u oluşturur
  static String buildPlantCarePrompt({
    required String plantName,
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    final responseLanguageNote = language == GeminiResponseLanguage.turkish
        ? 'Respond in Turkish'
        : 'Respond in English';

    return '''You are an expert agricultural engineer. Provide care recommendations for "$plantName" plant.
$responseLanguageNote.

ONLY respond in JSON format:
{
  "title": "${_getCareTitle(language)}",
  "plantName": "$plantName",
  "watering": {
    "frequency": "${_getWateringFrequencyExample(language)}",
    "amount": "${_getWaterAmountExample(language)}",
    "seasonalTips": "${_getSeasonalTipsExample(language)}"
  },
  "sunlight": {
    "requirement": "${_getLightRequirementExample(language)}",
    "hours": "${_getDailyHoursExample(language)}",
    "placement": "${_getPlacementExample(language)}"
  },
  "soil": {
    "type": "${_getSoilTypeExample(language)}",
    "ph": "${_getPhRangeExample(language)}",
    "drainage": "${_getDrainageExample(language)}"
  },
  "fertilization": {
    "schedule": "${_getFertilizationScheduleExample(language)}",
    "type": "${_getFertilizerTypeExample(language)}",
    "amount": "${_getFertilizerAmountExample(language)}"
  },
  "pruning": {
    "season": "${_getPruningSeasonExample(language)}",
    "technique": "${_getPruningTechniqueExample(language)}",
    "frequency": "${_getPruningFrequencyExample(language)}"
  },
  "commonProblems": ["${_getCommonProblemExample(language, 1)}", "${_getCommonProblemExample(language, 2)}"],
  "tips": ["${_getTipExample(language, 1)}", "${_getTipExample(language, 2)}"]
}

Provide detailed care recommendations for "$plantName":''';
  }

  /// Hastalık tedavi önerileri prompt'u oluşturur
  static String buildDiseaseRecommendationsPrompt({
    required String diseaseName,
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    final responseLanguageNote = language == GeminiResponseLanguage.turkish
        ? 'Respond in Turkish'
        : 'Respond in English';

    return '''You are a plant pathology expert. Provide treatment recommendations for "$diseaseName" disease.
$responseLanguageNote.

ONLY respond in JSON format:
{
  "title": "${_getDiseaseTitle(language)}",
  "diseaseName": "$diseaseName",
  "symptoms": ["${_getSymptomExample(language, 1)}", "${_getSymptomExample(language, 2)}"],
  "causes": ["${_getCauseExample(language, 1)}", "${_getCauseExample(language, 2)}"],
  "organicTreatments": [
    {
      "method": "${_getTreatmentMethodExample(language)}",
      "application": "${_getApplicationMethodExample(language)}",
      "frequency": "${_getFrequencyExample(language)}",
      "timing": "${_getTimingExample(language)}"
    }
  ],
  "biologicalControl": [
    {
      "agent": "${_getBiologicalAgentExample(language)}",
      "usage": "${_getUsageExample(language)}",
      "effectiveness": "${_getEffectivenessExample(language)}"
    }
  ],
  "culturalPractices": ["${_getCulturalPracticeExample(language, 1)}", "${_getCulturalPracticeExample(language, 2)}"],
  "prevention": ["${_getPreventionExample(language, 1)}", "${_getPreventionExample(language, 2)}"],
  "whenToTreat": "${_getWhenToTreatExample(language)}",
  "severity": "${_getSeverityExample(language)}",
  "prognosis": "${_getPrognosisExample(language)}"
}

ONLY suggest organic and safe treatment methods.
Provide detailed treatment recommendations for "$diseaseName":''';
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Prompt bileşenleri oluşturan yardımcı metotlar
  // ============================================================================

  /// Uzman rolü tanımını oluşturur (İngilizce)
  static String _buildRoleDefinition() {
    return '''[ROLE] You are an expert agricultural engineer and plant pathologist.
You analyze plants in images to identify species, diagnose diseases, 
provide treatment recommendations, and give general care advice.
You have extensive knowledge of agricultural practices and plant diseases.''';
  }

  /// Analiz talimatlarını oluşturur (İngilizce)
  static String _buildAnalysisInstructions() {
    return '''[ANALYSIS INSTRUCTIONS]
1. Accurately identify the plant species and variety in the image
2. Assess the overall health condition of the plant
3. Identify and diagnose any disease symptoms if present
4. Provide probability percentage for identification accuracy
5. Suggest specific treatment recommendations with detailed application methods
6. Include dosage information, application timing, and frequency
7. Provide agricultural tips specific to the plant and region
8. Assess growth stage and provide growth score (0-100)
9. Consider environmental factors and seasonal requirements''';
  }

  /// Konum bağlamını oluşturur (İngilizce)
  static String _buildLocationContext(String locationInfo) {
    if (locationInfo.isEmpty) return '';

    return '''[GEOGRAPHY] The analyzed image is from: $locationInfo
Consider climate conditions, common diseases, seasonal patterns, and 
agricultural practices specific to this geographical region when providing recommendations.''';
  }

  /// JSON şemasını PlantAnalysisModel'den otomatik oluşturur
  static String _buildJsonSchema(GeminiResponseLanguage language) {
    // PlantAnalysisModel'den temel JSON schema generate et
    final schema = _generateSchemaFromModel(language);

    return '''[JSON FORMAT] ONLY respond in this exact JSON format:
$schema''';
  }

  /// PlantAnalysisModel'den JSON schema generate eder
  static String _generateSchemaFromModel(GeminiResponseLanguage language) {
    // Model'den otomatik schema generate etmek için
    // PlantAnalysisModel'in tüm alanlarını map'le
    final schemaMap = <String, dynamic>{
      // Temel alanlar
      'plantName': _getExampleValue('plantName', language),
      'isHealthy': 'true/false',
      'probability': '0.95',
      'description': _getExampleValue('description', language),

      // Hastalık bilgileri
      'diseaseName': _getExampleValue('diseaseName', language),
      'diseaseDescription': _getExampleValue('diseaseDescription', language),

      // Tedavi bilgileri
      'treatmentName': _getExampleValue('treatmentName', language),
      'dosagePerDecare': _getExampleValue('dosagePerDecare', language),
      'applicationMethod': _getExampleValue('applicationMethod', language),
      'applicationTime': _getExampleValue('applicationTime', language),
      'applicationFrequency':
          _getExampleValue('applicationFrequency', language),
      'waitingPeriod': _getExampleValue('waitingPeriod', language),
      'effectiveness': _getExampleValue('effectiveness', language),

      // Genel bilgiler
      'notes': _getExampleValue('notes', language),
      'suggestion': _getExampleValue('suggestion', language),
      'intervention': _getExampleValue('intervention', language),
      'agriculturalTip': _getExampleValue('agriculturalTip', language),

      // Çevre bilgileri
      'watering': _getExampleValue('watering', language),
      'sunlight': _getExampleValue('sunlight', language),
      'soil': _getExampleValue('soil', language),
      'climate': _getExampleValue('climate', language),

      // Gelişim bilgileri
      'growthStage': _getExampleValue('growthStage', language),
      'growthScore': '75',
      'growthComment': _getExampleValue('growthComment', language),
    };

    // JSON'a dönüştür ve güzel formatla
    return _formatJsonSchema(schemaMap);
  }

  /// JSON schema'yı güzel formatlayıp string'e çevirir
  static String _formatJsonSchema(Map<String, dynamic> schema) {
    final buffer = StringBuffer('{\n');

    final entries = schema.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      buffer.write('  "${entry.key}": ');

      if (entry.value is String) {
        buffer.write('"${entry.value}"');
      } else {
        buffer.write('${entry.value}');
      }

      if (!isLast) buffer.write(',');
      buffer.write('\n');
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// Field adına göre örnek değer döndürür
  static String _getExampleValue(
      String fieldName, GeminiResponseLanguage language) {
    final examples = _getFieldExamples(language);
    return examples[fieldName] ?? _getDefaultExample(fieldName, language);
  }

  /// Tüm field örneklerini içeren map
  static Map<String, String> _getFieldExamples(
      GeminiResponseLanguage language) {
    if (language == GeminiResponseLanguage.turkish) {
      return {
        'plantName': 'Bitki adı (Latince adı)',
        'description': 'Detaylı açıklama',
        'diseaseName': 'Hastalık adı',
        'diseaseDescription': 'Hastalık açıklaması',
        'treatmentName': 'İlaç/tedavi adı',
        'dosagePerDecare': 'Dekar başına dozaj (ör. 150 ml/da)',
        'applicationMethod': 'Uygulama yöntemi (yaprak, damlama vs.)',
        'applicationTime': 'Uygulama zamanı (gün/saat/hava koşulu)',
        'applicationFrequency': 'Uygulama sıklığı (ör. 10 günde bir)',
        'waitingPeriod': 'Hasat öncesi bekleme süresi',
        'effectiveness': 'Etkinlik oranı',
        'notes': 'Ek notlar',
        'suggestion': 'Öneri',
        'intervention': 'Müdahale',
        'agriculturalTip': 'Tarım ipucu',
        'watering': 'Sulama önerisi',
        'sunlight': 'Işık ihtiyacı',
        'soil': 'Toprak türü',
        'climate': 'İklim bilgisi',
        'growthStage': 'Gelişim evresi',
        'growthComment': 'Gelişim yorumu',
      };
    } else {
      return {
        'plantName': 'Plant Name (Latin name)',
        'description': 'Detailed description',
        'diseaseName': 'Disease name',
        'diseaseDescription': 'Disease description',
        'treatmentName': 'Treatment/medicine name',
        'dosagePerDecare': 'Dosage per decare (e.g., 150 ml/da)',
        'applicationMethod':
            'Application method (foliar, drip irrigation, etc.)',
        'applicationTime': 'Application timing (day/hour/weather condition)',
        'applicationFrequency': 'Application frequency (e.g., every 10 days)',
        'waitingPeriod': 'Pre-harvest waiting period',
        'effectiveness': 'Effectiveness rate',
        'notes': 'Additional notes',
        'suggestion': 'Suggestion',
        'intervention': 'Intervention',
        'agriculturalTip': 'Agricultural tip',
        'watering': 'Watering recommendation',
        'sunlight': 'Sunlight requirement',
        'soil': 'Soil type',
        'climate': 'Climate information',
        'growthStage': 'Growth stage',
        'growthComment': 'Growth comment',
      };
    }
  }

  /// Varsayılan örnek değer
  static String _getDefaultExample(
      String fieldName, GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? 'Değer örneği'
        : 'Example value';
  }

  /// Kritik talimatları oluşturur
  static String _buildCriticalInstructions(GeminiResponseLanguage language) {
    final responseLanguageNote = language == GeminiResponseLanguage.turkish
        ? 'Respond in Turkish for all text values'
        : 'Respond in English for all text values';

    return '''[CRITICAL INSTRUCTIONS]
1. ONLY respond in the exact JSON format specified above
2. Do not add any additional explanations, titles, or text outside JSON
3. Do not use markdown code blocks or formatting
4. $responseLanguageNote
5. JSON keys must always be in English
6. Use definitive statements in disease diagnoses
7. Prefer organic and safe treatment methods
8. Provide specific, actionable recommendations
9. Include precise dosage and timing information
10. Ensure all numeric values are realistic and practical''';
  }

  // ============================================================================
  // QUICK IDENTIFICATION & OTHER PROMPTS - Diğer prompt helper'ları
  // ============================================================================

  static String _getPlantNameExample(GeminiResponseLanguage language) {
    return _getExampleValue('plantName', language);
  }

  // Diğer yardımcı metotlar (Quick ID için)
  static String _getCommonNameExample(
      GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return index == 1 ? "yaygın ad 1" : "yaygın ad 2";
    } else {
      return index == 1 ? "common name 1" : "common name 2";
    }
  }

  static String _getBasicInfoExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Kısa açıklama"
        : "Brief description";
  }

  static String _getCareTitle(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Bakım Tavsiyeleri"
        : "Care Recommendations";
  }

  static String _getWateringFrequencyExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Sulama sıklığı"
        : "Watering frequency";
  }

  static String _getWaterAmountExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Su miktarı"
        : "Water amount";
  }

  static String _getSeasonalTipsExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Mevsimsel öneriler"
        : "Seasonal tips";
  }

  static String _getLightRequirementExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Işık ihtiyacı"
        : "Light requirement";
  }

  static String _getDailyHoursExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Günlük saat"
        : "Daily hours";
  }

  static String _getPlacementExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Yerleştirme önerisi"
        : "Placement suggestion";
  }

  static String _getSoilTypeExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Toprak türü"
        : "Soil type";
  }

  static String _getPhRangeExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "pH aralığı"
        : "pH range";
  }

  static String _getDrainageExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Drenaj ihtiyacı"
        : "Drainage need";
  }

  static String _getFertilizationScheduleExample(
      GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Gübreleme takvimi"
        : "Fertilization schedule";
  }

  static String _getFertilizerTypeExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Gübre türü"
        : "Fertilizer type";
  }

  static String _getFertilizerAmountExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish ? "Miktar" : "Amount";
  }

  static String _getPruningSeasonExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Budama mevsimi"
        : "Pruning season";
  }

  static String _getPruningTechniqueExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Budama tekniği"
        : "Pruning technique";
  }

  static String _getPruningFrequencyExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish ? "Sıklık" : "Frequency";
  }

  static String _getCommonProblemExample(
      GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "yaygın sorun $index";
    } else {
      return "common problem $index";
    }
  }

  static String _getTipExample(GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "ipucu $index";
    } else {
      return "tip $index";
    }
  }

  static String _getDiseaseTitle(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Hastalık Tedavi Önerileri"
        : "Disease Treatment Recommendations";
  }

  static String _getSymptomExample(GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "belirti $index";
    } else {
      return "symptom $index";
    }
  }

  static String _getCauseExample(GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "neden $index";
    } else {
      return "cause $index";
    }
  }

  static String _getTreatmentMethodExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Tedavi yöntemi"
        : "Treatment method";
  }

  static String _getApplicationMethodExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Uygulama şekli"
        : "Application method";
  }

  static String _getFrequencyExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish ? "Sıklık" : "Frequency";
  }

  static String _getTimingExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Uygulama zamanı"
        : "Application timing";
  }

  static String _getBiologicalAgentExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Biyolojik ajan"
        : "Biological agent";
  }

  static String _getUsageExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Kullanım şekli"
        : "Usage method";
  }

  static String _getEffectivenessExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Etkinlik oranı"
        : "Effectiveness rate";
  }

  static String _getCulturalPracticeExample(
      GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "kültürel uygulama $index";
    } else {
      return "cultural practice $index";
    }
  }

  static String _getPreventionExample(
      GeminiResponseLanguage language, int index) {
    if (language == GeminiResponseLanguage.turkish) {
      return "önlem $index";
    } else {
      return "prevention $index";
    }
  }

  static String _getWhenToTreatExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Tedavi zamanlaması"
        : "Treatment timing";
  }

  static String _getSeverityExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish
        ? "Hastalık şiddeti (1-10)"
        : "Disease severity (1-10)";
  }

  static String _getPrognosisExample(GeminiResponseLanguage language) {
    return language == GeminiResponseLanguage.turkish ? "Prognoz" : "Prognosis";
  }
}
