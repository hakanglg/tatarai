# Gemini AI Service Architecture - Refactored

Bu klasör, **Clean Architecture** prensiplerine uygun olarak refactor edilmiş Gemini AI servislerini içerir. Mevcut monolitik `GeminiService` sınıfı yerine modüler, test edilebilir ve maintainable bir yapı oluşturulmuştur.

## 🏗️ Mimari Genel Bakış

### Önceki Durum (Eski Kod)
```
📁 features/plant_analysis/services/
├── gemini_service.dart          (1000+ satır, monolitik)
├── gemini_response_parser.dart  (parse işlemleri)
└── plant_analysis_service.dart  (service layer)
```

### Yeni Durum (Refactor Edilmiş)
```
📁 core/services/ai/
├── gemini_service_interface.dart     (Interface/Contract)
├── gemini_service_impl.dart          (Implementation) 
├── gemini_model_config.dart          (Model Configuration)
├── gemini_prompt_builder.dart        (Prompt Builder)
├── gemini_response_types.dart        (Response Types & Quality)
└── README.md                         (Documentation)
```

## 📂 Dosya Açıklamaları

### 1. `gemini_service_interface.dart`
**Gemini AI servisinin contract'ını tanımlar.**

```dart
abstract class GeminiServiceInterface {
  bool get isInitialized;
  Future<String> analyzeImage(Uint8List imageBytes, {...});
  Future<String> getPlantCareAdvice(String plantName);
  Future<String> getDiseaseRecommendations(String diseaseName);
  Future<String> generateContent(String prompt);
  void reinitialize();
  void dispose();
}
```

**Faydaları:**
- ✅ Dependency injection desteği
- ✅ Test edilebilirlik (mock implementation'lar)
- ✅ Farklı AI provider'ları destekleme (OpenAI, Claude, etc.)
- ✅ SOLID prensiplerine uygunluk

### 2. `gemini_service_impl.dart`
**Interface'in concrete implementation'ı.**

**Özellikler:**
- 🔄 **Automatic Retry Mechanism**: 3 deneme ile robust API calls
- 🖼️ **Image Optimization**: Automatic image compression ve size optimization
- 🎯 **Model Caching**: Her model tipi için lazy loading ve caching
- 🛡️ **Comprehensive Error Handling**: Detailed error categorization
- 📊 **Fallback Responses**: API hatalarında kullanılabilir yanıtlar
- 🌐 **Multi-language Support**: Türkçe/İngilizce response support

```dart
class GeminiServiceImpl extends BaseService implements GeminiServiceInterface {
  // Dependency injection ready
  GeminiServiceImpl({
    Dio? dio,
    GeminiResponseLanguage language = GeminiResponseLanguage.turkish,
  });
}
```

### 3. `gemini_model_config.dart`
**Model konfigürasyonlarını centralize eder.**

**Model Tipleri:**
- `GeminiModelType.imageAnalysis` - Görsel analiz için optimize
- `GeminiModelType.textGeneration` - Metin üretimi için optimize  
- `GeminiModelType.chat` - Sohbet için optimize
- `GeminiModelType.fastProcessing` - Hızlı işlemler için optimize

**Factory Constructors:**
```dart
// Görsel analizi için
final config = GeminiModelConfig.forImageAnalysis(
  language: GeminiResponseLanguage.turkish
);

// Bitki bakım tavsiyeleri için
final config = GeminiModelConfig.forPlantCare();

// Hastalık tedavi önerileri için (sıkı güvenlik)
final config = GeminiModelConfig.forDiseaseRecommendations();
```

**Faydaları:**
- ⚙️ Her analiz türü için optimize edilmiş ayarlar
- 🔒 Güvenlik ayarlarının centralize yönetimi
- 🎛️ Temperature, topK, topP gibi parametrelerin optimization'ı
- 🛑 Stop sequence'ların intelligent management'ı

### 4. `gemini_prompt_builder.dart`
**Prompt oluşturma işlemlerini centralize eder.**

**Önceki durum (dağınık promptlar):**
```dart
// Her yerde farklı prompt formatları
String prompt = "Sen bir uzman..."; // Her metotta tekrarlanıyor
```

**Yeni durum (centralized & consistent):**
```dart
// Görsel analizi için
final prompt = GeminiPromptBuilder.buildImageAnalysisPrompt(
  locationInfo: locationInfo,
  analysisType: GeminiAnalysisType.comprehensive,
  language: GeminiResponseLanguage.turkish,
);

// Bitki bakım tavsiyeleri için
final prompt = GeminiPromptBuilder.buildPlantCarePrompt(
  plantName: "Domates",
  language: GeminiResponseLanguage.turkish,
);
```

**Faydaları:**
- 📝 **DRY Principle**: Prompt'ların tek yerden yönetimi
- 🌍 **Multi-language**: Türkçe/İngilizce prompt desteği
- 📊 **Consistent JSON Schemas**: Standardize JSON output
- 🔧 **Easy Maintenance**: Prompt değişiklikleri tek yerden yapılır

### 5. `gemini_response_types.dart`
**Response tiplerini ve kalite metrikleri organize eder.**

**Response Status Tracking:**
```dart
enum GeminiResponseStatus {
  success, partialSuccess, apiKeyError, 
  apiRequestError, jsonParsingError, 
  emptyResponse, networkError, generalError
}
```

**Quality Metrics:**
```dart
class GeminiResponseQuality {
  final double completeness;  // Tamlık oranı
  final double accuracy;      // Doğruluk oranı
  final double relevance;     // İlgililik oranı 
  final double clarity;       // Netlik oranı
  
  double get overallScore;    // Genel kalite skoru
  bool get isHighQuality;     // Yüksek kaliteli mi?
}
```

**Unified Response Wrapper:**
```dart
class GeminiResponse<T> {
  final GeminiResponseStatus status;
  final GeminiResponseCategory category;
  final T? data;
  final GeminiResponseQuality? quality;
  final String? errorMessage;
  final Duration processingTime;
  
  bool get isSuccess;
  bool get isReliable;
}
```

## 🚀 Kullanım Örnekleri

### Service Locator ile Dependency Injection

```dart
// Service locator configuration (service_locator.dart)
_getIt.registerLazySingleton<GeminiServiceInterface>(
  () => GeminiServiceImpl(),
);

// Usage in widgets/cubits
class MyWidget extends StatelessWidget with ServiceLocatorMixin {
  @override
  Widget build(BuildContext context) {
    final geminiService = geminiServiceInterface; // Type-safe access
    // ...
  }
}
```

### Görsel Analizi

```dart
final response = await geminiService.analyzeImage(
  imageBytes,
  location: "Ankara/Çankaya",
  province: "Ankara", 
  district: "Çankaya",
  fieldName: "Domates Tarlası",
);

// Wrapped response ile detaylı kontrol
final wrappedResponse = GeminiResponse<String>.success(
  category: GeminiResponseCategory.imageAnalysis,
  data: response,
  quality: GeminiResponseQuality.defaultQuality(),
);

if (wrappedResponse.isHighQuality && wrappedResponse.isReliable) {
  // Yüksek kaliteli analiz sonucu
} else {
  // Düşük kaliteli sonuç - kullanıcıyı uyar
}
```

### Dil Değiştirme

```dart
final geminiService = serviceLocator<GeminiServiceInterface>() as GeminiServiceImpl;

// Türkçe'ye geç
geminiService.setLanguage(GeminiResponseLanguage.turkish);

// İngilizce'ye geç  
geminiService.setLanguage(GeminiResponseLanguage.english);
```

## 🧪 Test Edilebilirlik

### Mock Implementation

```dart
class MockGeminiService implements GeminiServiceInterface {
  @override
  bool get isInitialized => true;
  
  @override
  Future<String> analyzeImage(Uint8List imageBytes, {...}) async {
    return '''{"plantName": "Test Plant", "isHealthy": true}''';
  }
  
  // Diğer methodlar...
}

// Test setup
void main() {
  setUpAll(() {
    serviceLocator.registerFactory<GeminiServiceInterface>(
      () => MockGeminiService(),
    );
  });
}
```

### Integration Testing

```dart
void main() {
  group('Gemini Service Integration Tests', () {
    late GeminiServiceInterface geminiService;
    
    setUp(() {
      geminiService = GeminiServiceImpl();
    });
    
    test('should analyze image successfully', () async {
      final imageBytes = await loadTestImage();
      final result = await geminiService.analyzeImage(imageBytes);
      
      expect(result, isNotEmpty);
      expect(() => json.decode(result), returnsNormally);
    });
  });
}
```

## 🔄 Migration Guide

### Eski Koddan Yeni Koda Geçiş

**Eski kod:**
```dart
final geminiService = GeminiService();
final result = await geminiService.analyzeImage(imageBytes);
```

**Yeni kod:**
```dart
final geminiService = serviceLocator<GeminiServiceInterface>();
final result = await geminiService.analyzeImage(imageBytes);
```

### Gradual Migration Strategy

1. **Phase 1**: Yeni servisleri ekle (✅ Tamamlandı)
2. **Phase 2**: Service locator'ı güncelle (✅ Tamamlandı) 
3. **Phase 3**: Repository layer'ları güncelle (🔄 Şimdi)
4. **Phase 4**: Cubit'leri güncelle
5. **Phase 5**: Eski servisi kaldır

## 📊 Performance İyileştirmeleri

### Model Caching
- ✅ Her model tipi için lazy loading
- ✅ Memory efficient model management
- ✅ Automatic model reuse

### Image Optimization
- ✅ Automatic size reduction (300KB limit)
- ✅ Smart compression algorithms
- ✅ Bandwidth optimization

### Retry Mechanism
- ✅ Exponential backoff strategy
- ✅ Maximum 3 retry attempts
- ✅ Intelligent error categorization

### Response Quality Assessment
- ✅ Real-time quality scoring
- ✅ Reliability indicators
- ✅ User experience optimization

## 🛡️ Error Handling Improvements

### Detailed Error Categories
```dart
enum GeminiResponseStatus {
  apiKeyError,        // API anahtarı problemi
  apiRequestError,    // Rate limit, quota
  jsonParsingError,   // Parse hatası
  networkError,       // Ağ problemi
  emptyResponse,      // Boş yanıt
}
```

### Graceful Fallbacks
- ✅ API hatalarında kullanılabilir yanıtlar
- ✅ User-friendly error messages
- ✅ Partial success handling

## 🎯 Future Enhancements

### Planlanan İyileştirmeler
- [ ] **Response Caching**: Benzer istekleri cache'leme
- [ ] **Batch Processing**: Birden fazla image'ı paralel işleme  
- [ ] **Real-time Quality Feedback**: Kullanıcı feedback'i ile quality improvement
- [ ] **A/B Testing**: Farklı prompt strategy'leri test etme
- [ ] **Advanced Image Processing**: Gerçek image compression libraries
- [ ] **Multiple AI Provider Support**: OpenAI, Claude, vs. desteği

### Extensibility Points
- ✅ **Interface-based design**: Yeni provider'lar eklenebilir
- ✅ **Plugin architecture**: Yeni model tipleri desteklenebilir
- ✅ **Configuration-driven**: Ayarlar external config'den gelece

## 🏆 SOLID Principles Compliance

### Single Responsibility Principle (SRP)
- ✅ Her sınıf tek bir sorumluluk taşır
- ✅ Prompt building ↔ Service implementation ↔ Configuration ayrı

### Open/Closed Principle (OCP) 
- ✅ Yeni model tipleri eklenebilir (open for extension)
- ✅ Mevcut kod değiştirilmez (closed for modification)

### Liskov Substitution Principle (LSP)
- ✅ Interface implementasyonları birbiri yerine kullanılabilir
- ✅ Mock ve real implementation'lar seamless değiştirilebilir

### Interface Segregation Principle (ISP)
- ✅ Interface'ler specific ve focused
- ✅ Gereksiz dependency'ler yok

### Dependency Inversion Principle (DIP)
- ✅ High-level modules interface'lere depend eder
- ✅ Concrete implementation'lara değil abstraction'lara bağımlı

---

## 📞 Support & Maintenance

Bu refactor işlemi, kodun **maintainability**, **testability** ve **scalability**'sini önemli ölçüde artırmıştır. 

**Herhangi bir sorun veya iyileştirme önerisi için:**
- 🐛 Bug reports
- 💡 Feature requests  
- 📝 Documentation improvements
- 🧪 Test coverage enhancements

**geliştiricilerle iletişime geçebilirsiniz.** 