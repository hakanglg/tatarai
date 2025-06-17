import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini AI modeli konfigürasyon tiplerini tanımlar
enum GeminiModelType {
  /// Görsel analizi için optimize edilmiş model (Gemini 2.0 Flash)
  imageAnalysis('gemini-2.0-flash'),

  /// Metin üretimi için optimize edilmiş model
  textGeneration('gemini-2.0-flash'),

  /// Sohbet için optimize edilmiş model
  chat('gemini-2.0-flash'),

  /// Hızlı işlemler için basit model (gelecekte gemini-1.5-flash-8b olabilir)
  fastProcessing('gemini-2.0-flash');

  const GeminiModelType(this.modelName);

  /// Gemini API'deki model adı
  final String modelName;
}

/// Gemini yanıt dilleri
enum GeminiResponseLanguage {
  turkish('tr'),
  english('en');

  const GeminiResponseLanguage(this.code);
  final String code;
}

/// Gemini AI model konfigürasyonu ve ayarları
///
/// Bu sınıf, farklı analiz türleri için optimize edilmiş model ayarlarını
/// merkezi bir şekilde yönetir ve Clean Architecture prensiplerine uyar
class GeminiModelConfig {
  /// Private constructor - static factory metotları kullanılmalı
  const GeminiModelConfig._({
    required this.modelType,
    required this.generationConfig,
    required this.safetySettings,
    required this.systemInstruction,
  });

  /// Model tipi
  final GeminiModelType modelType;

  /// Üretim konfigürasyonu (temperature, topK, vs.)
  final GenerationConfig generationConfig;

  /// Güvenlik ayarları
  final List<SafetySetting> safetySettings;

  /// Sistem talimatları (system prompt)
  final String? systemInstruction;

  /// Model adını döndürür
  String get modelName => modelType.modelName;

  // ============================================================================
  // FACTORY CONSTRUCTORS - Her analiz türü için optimize edilmiş konfigürasyonlar
  // ============================================================================

  /// Görsel analizi için optimize edilmiş konfigürasyon
  ///
  /// - Deterministik yanıtlar için düşük temperature
  /// - JSON çıktısı için optimize edilmiş ayarlar
  /// - Uzun ve detaylı analiz için yüksek token limiti
  factory GeminiModelConfig.forImageAnalysis({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return GeminiModelConfig._(
      modelType: GeminiModelType.imageAnalysis,
      generationConfig: GenerationConfig(
        temperature: 0.0, // Tamamen deterministik
        topK: 1, // En olası seçeneği al
        topP: 0.95, // Yüksek olasılıklı yanıtlar
        maxOutputTokens: 4096, // Uzun detaylı analiz
        responseMimeType: 'application/json', // JSON formatı zorla
        stopSequences: _getStopSequencesForAnalysis(),
      ),
      safetySettings: _getStandardSafetySettings(),
      systemInstruction: _getSystemInstructionForAnalysis(language),
    );
  }

  /// Bitki bakım tavsiyeleri için optimize edilmiş konfigürasyon
  ///
  /// - Orta düzeyde yaratıcılık için temperature
  /// - Pratik öneriler için optimize edilmiş ayarlar
  factory GeminiModelConfig.forPlantCare({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return GeminiModelConfig._(
      modelType: GeminiModelType.textGeneration,
      generationConfig: GenerationConfig(
        temperature: 0.1, // Az yaratıcılık
        topK: 10,
        topP: 0.9,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
        stopSequences: _getStopSequencesForCare(),
      ),
      safetySettings: _getStandardSafetySettings(),
      systemInstruction: _getSystemInstructionForCare(language),
    );
  }

  /// Hastalık tedavi önerileri için optimize edilmiş konfigürasyon
  ///
  /// - Tıbbi kesinlik için düşük temperature
  /// - Güvenli tedavi önerileri için katı güvenlik ayarları
  factory GeminiModelConfig.forDiseaseRecommendations({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return GeminiModelConfig._(
      modelType: GeminiModelType.textGeneration,
      generationConfig: GenerationConfig(
        temperature: 0.0, // Kesin bilgi için deterministik
        topK: 1,
        topP: 0.95,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
        stopSequences: _getStopSequencesForDisease(),
      ),
      safetySettings: _getStrictSafetySettings(), // Sıkı güvenlik
      systemInstruction: _getSystemInstructionForDisease(language),
    );
  }

  /// Genel içerik üretimi için optimize edilmiş konfigürasyon
  ///
  /// - Dengeli yaratıcılık için orta temperature
  /// - Genel amaçlı kullanım için standart ayarlar
  factory GeminiModelConfig.forGeneralContent({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return GeminiModelConfig._(
      modelType: GeminiModelType.textGeneration,
      generationConfig: GenerationConfig(
        temperature: 0.3, // Dengeli yaratıcılık
        topK: 20,
        topP: 0.8,
        maxOutputTokens: 1024,
        stopSequences: [], // Genel içerik için stop sequence'lar yok
      ),
      safetySettings: _getStandardSafetySettings(),
      systemInstruction: null, // Genel içerik için sistem talimatı yok
    );
  }

  /// Hızlı tanımlama için optimize edilmiş konfigürasyon
  ///
  /// - Hızlı yanıt için düşük token limiti
  /// - Basit tanımlama için minimal ayarlar
  factory GeminiModelConfig.forQuickIdentification({
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  }) {
    return GeminiModelConfig._(
      modelType: GeminiModelType.fastProcessing,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        topK: 5,
        topP: 0.9,
        maxOutputTokens: 512, // Kısa yanıt
        responseMimeType: 'application/json',
        stopSequences: _getStopSequencesForQuickId(),
      ),
      safetySettings: _getStandardSafetySettings(),
      systemInstruction: _getSystemInstructionForQuickId(language),
    );
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Ayarları oluşturan yardımcı metotlar
  // ============================================================================

  /// Görsel analizi için stop sequence'ları döndürür
  /// API limiti: maksimum 5 stop sequence
  static List<String> _getStopSequencesForAnalysis() {
    return [
      '```', // Markdown kod blokları
      'Bu analiz',
      'Bu yanıt',
      'Not:',
      'UYARI:', // Uyarı metinleri
    ];
  }

  /// Bakım tavsiyeleri için stop sequence'ları döndürür
  /// API limiti: maksimum 5 stop sequence
  static List<String> _getStopSequencesForCare() {
    return [
      '```',
      'Bu yanıt',
      'Bu bilgiler',
      'Not:',
      'Uyarı:',
    ];
  }

  /// Hastalık önerileri için stop sequence'ları döndürür
  /// API limiti: maksimum 5 stop sequence
  static List<String> _getStopSequencesForDisease() {
    return [
      '```',
      'Bu yanıt',
      'Bu bilgiler',
      'Yasal Uyarı:',
      'Tıbbi Tavsiye:',
    ];
  }

  /// Hızlı tanımlama için stop sequence'ları döndürür
  /// API limiti: maksimum 5 stop sequence
  static List<String> _getStopSequencesForQuickId() {
    return [
      '```',
      'Bu yanıt',
      'Bu bitki',
      'Not:',
      'Detay:',
    ];
  }

  /// Standart güvenlik ayarları
  static List<SafetySetting> _getStandardSafetySettings() {
    return [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
    ];
  }

  /// Sıkı güvenlik ayarları (hastalık önerileri için)
  static List<SafetySetting> _getStrictSafetySettings() {
    return [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.low),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.low),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.low),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.low),
    ];
  }

  /// Görsel analizi için sistem talimatı
  static String _getSystemInstructionForAnalysis(
      GeminiResponseLanguage language) {
    switch (language) {
      case GeminiResponseLanguage.turkish:
        return '''Sen bir uzman ziraat mühendisi ve bitki patolojistisin. 
Görsellerdeki bitkileri analiz ederek hastalıkları tespit ediyor, 
tedavi önerileri sunuyor ve genel bakım tavsiyeleri veriyorsun.

SADECE JSON formatında yanıt ver. Hiçbir ek açıklama yapma.
Tüm bilgileri Türkçe olarak hazırla.''';

      case GeminiResponseLanguage.english:
        return '''You are an expert agricultural engineer and plant pathologist.
You analyze plants in images to detect diseases, 
provide treatment recommendations, and give general care advice.

ONLY respond in JSON format. Do not provide any additional explanations.
Prepare all information in English.''';
    }
  }

  /// Bakım tavsiyeleri için sistem talimatı
  static String _getSystemInstructionForCare(GeminiResponseLanguage language) {
    switch (language) {
      case GeminiResponseLanguage.turkish:
        return '''Sen bir uzman ziraat mühendisisin. 
Bitki bakım tavsiyeleri konusunda detaylı ve pratik öneriler veriyorsun.

SADECE JSON formatında yanıt ver.
Tüm tavsiyeleri Türkçe olarak hazırla.''';

      case GeminiResponseLanguage.english:
        return '''You are an expert agricultural engineer.
You provide detailed and practical plant care recommendations.

ONLY respond in JSON format.
Prepare all recommendations in English.''';
    }
  }

  /// Hastalık önerileri için sistem talimatı
  static String _getSystemInstructionForDisease(
      GeminiResponseLanguage language) {
    switch (language) {
      case GeminiResponseLanguage.turkish:
        return '''Sen bir bitki patolojisi uzmanısın.
Bitki hastalıkları için güvenli ve etkili tedavi yöntemleri öneriyorsun.

SADECE JSON formatında yanıt ver.
Sadece organik ve güvenli tedavi yöntemlerini öner.
Tüm önerileri Türkçe olarak hazırla.''';

      case GeminiResponseLanguage.english:
        return '''You are a plant pathology expert.
You recommend safe and effective treatment methods for plant diseases.

ONLY respond in JSON format.
Only suggest organic and safe treatment methods.
Prepare all recommendations in English.''';
    }
  }

  /// Hızlı tanımlama için sistem talimatı
  static String _getSystemInstructionForQuickId(
      GeminiResponseLanguage language) {
    switch (language) {
      case GeminiResponseLanguage.turkish:
        return '''Sen bir bitki uzmanısın. 
Görseldeki bitkiyi hızlıca tanımla ve temel bilgilerini ver.

SADECE JSON formatında kısa yanıt ver.
Tüm bilgileri Türkçe olarak hazırla.''';

      case GeminiResponseLanguage.english:
        return '''You are a plant expert.
Quickly identify the plant in the image and provide basic information.

ONLY respond in short JSON format.
Prepare all information in English.''';
    }
  }
}
