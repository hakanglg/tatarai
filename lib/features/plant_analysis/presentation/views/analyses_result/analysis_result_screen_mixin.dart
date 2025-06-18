part of 'analysis_result_screen.dart';

/// Analiz sonuçları ekranı için mixin
/// UI state yönetimi ve işlem koordinasyonu sağlar
mixin AnalysisResultScreenMixin {
  /// Mevcut analiz sonucu (UI'da gösterilen)
  PlantAnalysisModel? _analysisResult;

  /// Analiz sonucu için getter
  PlantAnalysisModel? get analysisResult => _analysisResult;

  /// Analiz sonucunu set eder
  void setAnalysisResult(PlantAnalysisModel? result) {
    _analysisResult = result;
  }

  /// İzleme ve loglama (development için)
  void logAnalysisResult() {
    // Debug logları kaldırıldı - production'da gereksiz çıktı oluşturuyor
  }

  /// Analiz sonucunu state'den alır
  ///
  /// State'i dinler ve mevcut analizi UI formatına dönüştürür.
  /// Bu metod widget rebuild sırasında çağrılır.
  ///
  /// @param state - Plant analysis cubit state
  /// @return Future<PlantAnalysisModel?> - UI için hazır analiz sonucu
  Future<PlantAnalysisModel?> loadAnalysisFromState(dynamic state) async {
    if (state.currentAnalysis == null) {
      setAnalysisResult(null);
      return null;
    }

    try {
      // Entity'den model'e dönüştürme
      final PlantAnalysisModel result =
          _convertToPlantAnalysisModel(state.currentAnalysis!);

      setAnalysisResult(result);
      logAnalysisResult();

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('AnalysisResult conversion error: $e');
      }
      setAnalysisResult(null);
      return null;
    }
  }

  /// Async analiz yükleme - Widget'ların async operasyonları için
  ///
  /// FutureBuilder gibi widget'lar bu metodu kullanabilir.
  /// Completer pattern kullanarak async operasyonu yönetir.
  ///
  /// @param state - Plant analysis state
  /// @return Future<PlantAnalysisModel?> - Async analiz sonucu
  Future<PlantAnalysisModel?> loadAnalysisResultAsync(dynamic state) async {
    final completer = Completer<PlantAnalysisModel?>();

    try {
      final result = await loadAnalysisFromState(state);
      completer.complete(result);
    } catch (e) {
      completer.complete(null);
      if (kDebugMode) {
        print('Async analysis loading error: $e');
      }
    }

    return completer.future;
  }

  /// State değişikliklerini işler
  ///
  /// Cubit listener'ın state değişikliklerini işlemesi için kullanılır.
  /// Bu metod state her değiştiğinde otomatik çağrılır.
  ///
  /// @param state - Yeni plant analysis state
  void handleStateChange(dynamic state) {
    if (state.currentAnalysis != null) {
      loadAnalysisFromState(state);
    } else {
      setAnalysisResult(null);
    }
  }

  /// Resource temizliği
  ///
  /// Widget dispose edildiğinde bu metod çağrılmalıdır.
  void cleanupMixin() {
    _analysisResult = null;
  }

  /// Converts PlantAnalysisEntity to PlantAnalysisModel
  ///
  /// Entity katmanından gelen veriyi UI katmanı için uygun formata dönüştürür.
  /// Bu dönüşüm sırasında UI'da ihtiyaç olan tüm alanları entity'den alır.
  ///
  /// @param entity - Domain layer entity
  /// @return PlantAnalysisModel - UI layer model
  PlantAnalysisModel _convertToPlantAnalysisModel(PlantAnalysisEntity entity) {
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
      // Yeni alanları entity'den al
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
}
