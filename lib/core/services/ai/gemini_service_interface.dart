import 'dart:typed_data';

import '../../../features/plant_analysis/data/models/plant_analysis_model.dart';
import 'models/plant_care_advice_model.dart';
import 'models/disease_recommendations_model.dart';

/// Gemini AI service interface
/// Gemini AI API ile iletişim kuran servislerin uyması gereken contract
///
/// Bu interface sayesinde farklı AI servisleri (Gemini, OpenAI, vs.)
/// aynı contract'ı implement edebilir ve kolayca değiştirilebilir
abstract class GeminiServiceInterface {
  /// Servisin başlatılıp başlatılmadığını kontrol eder
  bool get isInitialized;

  /// Görsel analizi yapar
  ///
  /// [imageBytes] - Analiz edilecek görselin bayt dizisi
  /// [prompt] - Analiz talimatları (opsiyonel)
  /// [location] - Konum bilgisi (opsiyonel)
  /// [province] - İl bilgisi (opsiyonel)
  /// [district] - İlçe bilgisi (opsiyonel)
  /// [neighborhood] - Mahalle bilgisi (opsiyonel)
  /// [fieldName] - Tarla adı (opsiyonel)
  ///
  /// Returns: Structured PlantAnalysisModel
  Future<PlantAnalysisModel> analyzeImage(
    Uint8List imageBytes, {
    String? prompt,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  });

  /// Bitki bakım tavsiyeleri alır
  ///
  /// [plantName] - Bitki adı
  /// Returns: Structured PlantCareAdviceModel
  Future<PlantCareAdviceModel> getPlantCareAdvice(String plantName);

  /// Hastalık önerileri alır
  ///
  /// [diseaseName] - Hastalık adı
  /// Returns: Structured DiseaseRecommendationsModel
  Future<DiseaseRecommendationsModel> getDiseaseRecommendations(
      String diseaseName);

  /// Genel içerik üretimi yapar
  ///
  /// [prompt] - İçerik üretim talimatı
  /// Returns: Üretilen içerik
  Future<String> generateContent(String prompt);

  /// Servisi yeniden başlatır
  /// API anahtarı değiştiğinde veya servis hatası durumunda kullanılır
  void reinitialize();

  /// Servisi temizler ve kaynakları serbest bırakır
  void dispose();
}
