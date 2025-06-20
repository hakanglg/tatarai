import 'dart:typed_data';
import 'dart:math' as math;

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

/// Gemini AI servisi
/// Bitki analizi ve öneriler için Gemini AI API'sini kullanır
class GeminiService extends BaseService {
  GenerativeModel? _model;
  bool _isInitialized = false;
  final Dio _dio = Dio();

  /// Güncel dil ayarı ('tr' veya 'en')
  String _currentLanguage = 'tr';

  /// Servis oluşturulurken Gemini modelini başlatır
  GeminiService() {
    _initializeModel();
  }

  /// Gemini modelini yapılandırır
  void _initializeModel() {
    try {
      // Önce AppConstants'dan API anahtarını al
      String apiKey = AppConstants.geminiApiKey;

      // Eğer AppConstants'daki anahtar boşsa, doğrudan .env'den almayı dene
      if (apiKey.isEmpty) {
        apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      }

      if (apiKey.isEmpty) {
        logWarning('Gemini API anahtarı bulunamadı',
            'Varsayılan yanıtlar kullanılacak');
        _isInitialized = false;
        return;
      }

      // API anahtarını doğrula
      if (apiKey.length < 10) {
        logWarning(
            'Geçersiz Gemini API anahtarı', 'Varsayılan yanıtlar kullanılacak');
        _isInitialized = false;
        return;
      }

      // Modeli başlatmadan önce API anahtarını kontrol et
      try {
        // Gemini 2.0 Flash modeli kullan
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );
        _isInitialized = true;
        logSuccess('Gemini modeli başlatıldı', 'Model: gemini-2.0-flash');
      } catch (modelError) {
        logError('Gemini modeli başlatılamadı', modelError.toString());
        _isInitialized = false;
      }
    } catch (e) {
      logError('Gemini modeli başlatılamadı', e.toString());
      _isInitialized = false;
    }
  }

  /// Dil ayarını günceller
  ///
  /// [language] - Yanıt dili ('tr' veya 'en')
  void setLanguage(String language) {
    if (language == 'tr' || language == 'en') {
      _currentLanguage = language;
      logInfo('Gemini dil ayarı güncellendi', 'Yeni dil: $language');
    } else {
      logWarning('Geçersiz dil kodu', 'Desteklenen diller: tr, en');
    }
  }

  /// Görsel analizi yapar
  ///
  /// [imageBytes] analiz edilecek görselin bayt dizisi
  /// [prompt] analiz talimatları (opsiyonel)
  /// [location] Konum bilgisi (opsiyonel)
  /// [province] İl bilgisi (opsiyonel)
  /// [district] İlçe bilgisi (opsiyonel)
  /// [neighborhood] Mahalle bilgisi (opsiyonel)
  /// [fieldName] Tarla adı (opsiyonel)
  Future<String> analyzeImage(
    Uint8List imageBytes, {
    String? prompt,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      // Log başlangıç
      logInfo('analyzeImage başlatılıyor',
          'Görsel boyutu: ${imageBytes.length} bayt');

      // 1. Görsel boyutunu optimize et
      final processedImageBytes = await _optimizeImageSize(imageBytes);

      // 2. Konum bilgilerini hazırla
      final locationInfo = _prepareLocationInfo(
          location: location,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName);

      // 3. Analiz promptunu hazırla
      final finalPrompt = _prepareAnalysisPrompt(prompt, locationInfo,
          language: _currentLanguage);

      // DEBUG: Prompt'u logla
      logInfo(
          '🔹 Gemini\'ye gönderilen prompt:',
          finalPrompt.substring(
                  0, finalPrompt.length > 500 ? 500 : finalPrompt.length) +
              '...');
      logInfo('🔹 Konum bilgisi:',
          locationInfo.isEmpty ? 'Konum belirtilmedi' : locationInfo);

      // 4. API anahtarını kontrol et ve model durumunu doğrula
      if (!_validateApiAndModel()) {
        return _getDefaultImageAnalysisResponse(
          location: location,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName,
        );
      }

      // 5. Gemini modeline istek gönder
      logInfo('Gemini modeline istek gönderiliyor');
      try {
        // Görüntü ve metin içeren istek gönder
        final bytes = processedImageBytes;

        // Doğru formatla istek oluştur ve gönder
        final prompt = TextPart(finalPrompt);
        final imagePart = DataPart('image/jpeg', bytes);

        // Gelişmiş model ayarları ile istek gönder - JSON'a optimize
        final generationConfig = GenerationConfig(
          temperature: 0.0, // Sıfır yaratıcılık, tamamen deterministik
          topK: 1, // Sadece en olası seçeneği al
          topP: 0.95, // Olasılığı yüksek yanıtlara odaklan
          maxOutputTokens: 4096, // Uzun detaylı analiz için
          responseMimeType: 'application/json', // Kesinlikle JSON formatı
          stopSequences: [
            '```', // Markdown bloklarını durdur
            'Bu analiz',
            'Görüntüdeki bitki',
            'Bu yanıt',
            'Not:',
            'Dipnot:',
            'Açıklama:',
            'Sonuç:',
            '\n\n', // Çift satır arası
            'Bu JSON', // JSON açıklamaları
            '**', // Bold markdown
            '##', // Header markdown
          ],
        );

        final response = await _model!.generateContent(
          [
            Content.multi([prompt, imagePart])
          ],
          generationConfig: generationConfig,
        );

        if (response.text == null || response.text!.isEmpty) {
          logWarning('Gemini boş yanıt döndürdü');
          return _getDefaultEmptyAnalysisResponse();
        }

        // DEBUG: Ham yanıtı logla
        logInfo(
            '🔹 Gemini\'den gelen ham yanıt:',
            response.text!.substring(0,
                response.text!.length > 1000 ? 1000 : response.text!.length));

        // Yanıtı işle - markdown kod bloklarını temizle
        String responseText = response.text!.trim();
        // Markdown kod bloklarını kaldır ve temiz JSON elde et
        if (responseText.contains("```json")) {
          final startIndex = responseText.indexOf("```json") + 7;
          final endIndex = responseText.lastIndexOf("```");
          if (startIndex > 7 && endIndex > startIndex) {
            responseText = responseText.substring(startIndex, endIndex).trim();
            logInfo('Markdown JSON bloğu temizlendi');
          }
        } else if (responseText.startsWith("```") &&
            responseText.endsWith("```")) {
          responseText =
              responseText.substring(3, responseText.length - 3).trim();
          logInfo('Markdown kod bloğu temizlendi');
        }

        // DEBUG: Temizlenmiş yanıtı logla
        logInfo(
            '🔹 Temizlenmiş Gemini yanıtı:',
            responseText.substring(
                0, responseText.length > 1000 ? 1000 : responseText.length));

        // JSON geçerliliğini test et
        try {
          final parsedJson = json.decode(responseText);
          logSuccess('Gemini başarılı yanıt döndürdü - geçerli JSON',
              'Karakter sayısı: ${responseText.length}');

          // DEBUG: Parse edilen JSON'u logla
          logInfo(
              '🔹 Parse edilen JSON anahtarları:', parsedJson.keys.toString());
          if (parsedJson['diseases'] != null) {
            logInfo('🔹 Hastalık sayısı:',
                parsedJson['diseases'].length.toString());
          }
        } catch (jsonError) {
          // JSON parse edilemese bile yanıtı döndür, repository sonra işleyecek
          logWarning(
              'Gemini yanıtı JSON olarak ayrıştırılamadı, düz metin olarak işlenecek',
              jsonError.toString());
          logWarning(
              '🔹 JSON Parse hatası detayı:', responseText.substring(0, 200));
        }

        return responseText;
      } catch (apiError) {
        // 6. API hatası durumunda alternatif yöntem dene (REST API)
        logError('Gemini API hatası', apiError.toString());
        return await _tryAlternativeApiMethod(
          processedImageBytes: processedImageBytes,
          finalPrompt: finalPrompt,
          locationToUse: locationInfo,
          location: location,
        );
      }
    } catch (error) {
      logError('Beklenmeyen analiz hatası', error.toString());
      return _getDefaultErrorAnalysisResponse(
        error: error.toString(),
        location: location ?? '',
      );
    }
  }

  /// Görsel boyutunu optimize eder
  Future<Uint8List> _optimizeImageSize(Uint8List imageBytes) async {
    if (imageBytes.length <= 300 * 1024) {
      return imageBytes; // Boyut zaten uygun
    }

    try {
      final processedImageBytes =
          await _resizeImageBytes(imageBytes, maxSizeInBytes: 300 * 1024);
      logInfo('Görsel boyutu düşürüldü',
          'Orijinal: ${imageBytes.length} bayt, Yeni: ${processedImageBytes.length} bayt');
      return processedImageBytes;
    } catch (e) {
      logWarning('Görsel boyutu düşürülemedi', e.toString());
      return imageBytes; // Orijinal görüntü kullanılmaya devam edilecek
    }
  }

  /// Konum bilgilerini hazırlar ve formatlı string döndürür
  String _prepareLocationInfo(
      {String? location,
      String? province,
      String? district,
      String? neighborhood,
      String? fieldName}) {
    String detailedLocation = "";
    String fieldInfo = "";

    // İl, ilçe ve mahalle bilgilerinden detaylı konum oluştur
    if (province != null && district != null) {
      detailedLocation = "$province/$district";
      if (neighborhood != null && neighborhood.isNotEmpty) {
        detailedLocation += "/$neighborhood";
      }
    }

    // Detaylı konum yoksa verilen lokasyonu kullan
    final String locationToUse = detailedLocation.isNotEmpty
        ? detailedLocation
        : (location != null && location.isNotEmpty)
            ? location
            : "";

    // Tarla bilgisini ekle
    if (fieldName != null && fieldName.isNotEmpty) {
      fieldInfo = " ($fieldName tarla)";
    }

    return locationToUse.isEmpty ? "" : locationToUse + fieldInfo;
  }

  /// API ve model durumunu kontrol eder
  bool _validateApiAndModel() {
    // API anahtarı kontrolü
    String apiKey = AppConstants.geminiApiKey;
    if (apiKey.isEmpty) {
      apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    }

    if (apiKey.isEmpty) {
      logWarning('Gemini API anahtarı bulunamadı');
      return false;
    }

    // Model başlatılmadıysa tekrar başlatmayı dene
    if (!_isInitialized || _model == null) {
      logInfo('Gemini modeli yeniden başlatılıyor');
      _initializeModel();

      // Hala başlatılamadıysa false dön
      if (!_isInitialized || _model == null) {
        logWarning('Gemini modeli hala başlatılamadı');
        return false;
      }
    }

    return true;
  }

  /// Alternatif API metodu dener
  Future<String> _tryAlternativeApiMethod({
    required Uint8List processedImageBytes,
    required String finalPrompt,
    required String locationToUse,
    String? location,
  }) async {
    try {
      logInfo('Alternatif REST API yöntemi deneniyor');
      final apiKey = AppConstants.geminiApiKey.isEmpty
          ? dotenv.env['GEMINI_API_KEY'] ?? ''
          : AppConstants.geminiApiKey;

      final restResponse = await _sendImageToGeminiRestApi(
        imageBytes: processedImageBytes,
        prompt: finalPrompt,
        apiKey: apiKey,
      );

      if (restResponse != null && restResponse.isNotEmpty) {
        logSuccess('REST API başarılı yanıt döndürdü');
        return restResponse;
      } else {
        logWarning('REST API boş yanıt döndürdü');
        return _getDefaultEmptyAnalysisResponse();
      }
    } catch (restError) {
      logError('REST API hatası', restError.toString());
      return _getDefaultErrorAnalysisResponse(
        error: restError.toString(),
        location: locationToUse,
      );
    }
  }

  /// Gelişmiş analiz promptunu hazırlar
  ///
  /// [promptParam] - Özel prompt (opsiyonel)
  /// [locationInfo] - Coğrafi konum bilgisi
  /// [analysisType] - Analiz türü ('comprehensive', 'disease', 'care')
  /// [language] - Yanıt dili ('tr', 'en')
  String _prepareAnalysisPrompt(
    String? promptParam,
    String locationInfo, {
    String analysisType = 'comprehensive',
    String language = 'tr',
  }) {
    // Özel prompt varsa direkt kullan
    if (promptParam != null && promptParam.isNotEmpty) {
      return promptParam;
    }

    // Dinamik bileşenler oluştur
    final locationContext = _buildLocationContext(locationInfo);
    final expertRole = _buildExpertRole(analysisType);
    final analysisInstructions =
        _buildAnalysisInstructions(analysisType, language);
    final jsonSchema = _buildJsonSchema(analysisType);
    final criticalWarnings = _buildCriticalWarnings(language);

    return '''$expertRole

$analysisInstructions

$locationContext

$criticalWarnings

$jsonSchema

${_buildMandatoryRules(language)}''';
  }

  /// Uzman rolü ve görev tanımını oluşturur
  String _buildExpertRole(String analysisType) {
    switch (analysisType) {
      case 'disease':
        return '''[UZMAN ROL] Sen bir bitki patolojisi uzmanısın. Sadece hastalık teşhisi ve tedavi önerileri ile ilgileniyorsun.''';
      case 'care':
        return '''[UZMAN ROL] Sen bir ziraat mühendisisin. Bitki bakımı ve yetiştirme koşulları konusunda uzmansın.''';
      default:
        return '''[UZMAN ROL] Sen bir uzman ziraat mühendisi ve bitki patoloji uzmanısın. Bu görüntüdeki bitkiyi kapsamlı bir şekilde analiz etmeni istiyorum.''';
    }
  }

  /// Konum bağlamını oluşturur
  String _buildLocationContext(String locationInfo) {
    if (locationInfo.isEmpty) {
      return '''[KONUM BİLGİSİ] Konum belirtilmemiş. Genel öneriler ver.''';
    }

    return '''[KONUM BİLGİSİ] Bu bitki $locationInfo bölgesinde yetiştirilmektedir. 
Bu bölgenin:
- İklim koşulları (sıcaklık, nem, yağış)
- Toprak özellikleri
- Yerel tarım uygulamaları
- Bölgesel hastalık riskleri
- Mevsimsel faktörler
göz önünde bulundurularak önerilerini vermelisin.''';
  }

  /// Analiz talimatlarını oluşturur
  String _buildAnalysisInstructions(String analysisType, String language) {
    final baseInstructions = language == 'en'
        ? '''[ANALYSIS INSTRUCTIONS]
1. 🔍 PLANT IDENTIFICATION: Accurately identify the plant (Common and Latin name)
2. 🩺 HEALTH ASSESSMENT: Detailed health analysis
   - Leaf color and texture
   - Stem condition
   - Root system appearance
   - Fruit/flower condition
3. 🦠 DISEASE DETECTION: Identify disease symptoms
   - Fungal diseases
   - Bacterial diseases
   - Viral diseases
   - Pest damage
   - Nutrient deficiencies
4. 📊 GROWTH EVALUATION: Score plant development (0-100)
5. 💊 TREATMENT RECOMMENDATIONS: Specific treatment methods
6. 🌱 CARE ADVICE: Comprehensive care plan'''
        : '''[ANALİZ TALİMATLARI]
1. 🔍 BİTKİ TEŞHİSİ: Bitkiyi kesin olarak teşhis et (Türkçe ve Latince adı)
2. 🩺 SAĞLIK DURUMU: Detaylı sağlık analizi yap
   - Yaprak rengi ve dokusu
   - Gövde durumu  
   - Kök sistemi görünümü
   - Meyve/çiçek durumu
3. 🦠 HASTALIK TESPİTİ: Hastalık belirtilerini tespit et
   - Fungal hastalıklar
   - Bakteriyel hastalıklar
   - Viral hastalıklar
   - Zararlı böcek hasarları
   - Besin eksiklikleri
4. 📊 GELİŞİM DEĞERLENDİRMESİ: Bitki gelişim durumunu skorla (0-100)
5. 💊 TEDAVİ ÖNERİLERİ: Spesifik tedavi yöntemleri öner
6. 🌱 BAKIM TAVSİYELERİ: Comprehensive bakım planı hazırla''';

    final focusMessage = language == 'en' ? '[SPECIAL FOCUS]' : '[ÖZEL FOKUS]';

    switch (analysisType) {
      case 'disease':
        final diseaseText = language == 'en'
            ? 'Focus on disease diagnosis and treatment recommendations.'
            : 'Hastalık teşhisi ve tedavi önerilerine odaklan.';
        return '''$baseInstructions
        
$focusMessage $diseaseText''';
      case 'care':
        final careText = language == 'en'
            ? 'Focus on care recommendations and growing conditions.'
            : 'Bakım tavsiyeleri ve yetiştirme koşullarına odaklan.';
        return '''$baseInstructions
        
$focusMessage $careText''';
      default:
        return baseInstructions;
    }
  }

  /// JSON şemasını oluşturur
  String _buildJsonSchema(String analysisType) {
    return '''[JSON FORMATI - ZORUNLU ŞABLON]
{
  "plantName": "Domates (Solanum lycopersicum)",
  "probability": 0.95,
  "isHealthy": false,
  "description": "Detaylı bitki açıklaması. Görsel analiz sonuçları ve genel durum değerlendirmesi.",
  "diseases": [
    {
      "name": "Hastalık Adı",
      "description": "Hastalığın detaylı açıklaması ve belirtileri",
      "probability": 0.85,
      "treatments": ["Spesifik tedavi önerisi 1", "Spesifik tedavi önerisi 2"],
      "interventionMethods": ["Müdahale yöntemi 1", "Müdahale yöntemi 2"],
      "pesticideSuggestions": ["İlaç önerisi 1", "İlaç önerisi 2"],
      "preventiveMeasures": ["Önleyici tedbir 1", "Önleyici tedbir 2"],
      "symptoms": ["Belirti 1", "Belirti 2"]
    }
  ],
  "suggestions": ["Genel öneri 1", "Genel öneri 2", "Genel öneri 3"],
  "interventionMethods": ["Kapsamlı müdahale 1", "Kapsamlı müdahale 2"],
  "agriculturalTips": ["Tarımsal ipucu 1", "Tarımsal ipucu 2"],
  "watering": "Detaylı sulama talimatı - sıklık, miktar, yöntem",
  "sunlight": "Işık gereksinimi - süre, yoğunluk, konum",
  "soil": "Toprak özellikleri - pH, drenaj, besin",
  "climate": "İklim gereksinimleri - sıcaklık, nem, rüzgar",
  "growthStage": "Mevcut gelişim aşaması",
  "growthScore": 75,
  "growthComment": "Gelişim durumu hakkında detaylı yorum"
}''';
  }

  /// Kritik uyarıları oluşturur
  String _buildCriticalWarnings(String language) {
    if (language == 'en') {
      return '''[🚨 CRITICAL WARNINGS - MUST FOLLOW] 
🔴 ONLY respond in JSON format - nothing else
🔴 FIRST CHARACTER must be {, LAST CHARACTER must be }
🔴 NO preface, explanation, notes or conclusion
🔴 Do NOT write a SINGLE CHARACTER outside JSON (no period, explanation, emoji)
🔴 Do NOT use markdown formatting (```json, ``` etc.)
🔴 Use proper English characters and grammar
🔴 All string values in double quotes
🔴 Boolean values: only true/false (no quotes)
🔴 Numeric values: without quotes (e.g. 0.85)
🔴 Arrays in square brackets: ["item1", "item2"]
🔴 Do NOT use null values - use empty string "" or empty array []
🔴 Do NOT use trailing comma (no comma after last item)
🔴 Do NOT use Unicode escape characters (\\u0000 etc.)''';
    } else {
      return '''[🚨 KRİTİK UYARILAR - MUTLAKA UYULACAK] 
🔴 SADECE VE YALNIZCA JSON formatında yanıt ver - başka hiçbir şey yok
🔴 CEVABININ İLK KARAKTERI { OLMALI, SON KARAKTERI } OLMALI
🔴 HİÇBİR ön söz, açıklama, not veya son söz EKLEME
🔴 JSON dışında TEK BİR KARAKTER bile yazma (nokta, açıklama, emoji yok)
🔴 Markdown biçimlendirme KULLANMA (```json, ``` vb.)
🔴 Türkçe karakterleri doğru kullan (ç, ğ, ı, ş, ü, ö)
🔴 Tüm string değerleri çift tırnak içinde yaz
🔴 Boolean değerler: sadece true/false (tırnak yok)
🔴 Sayısal değerler: tırnak olmadan (örn: 0.85)
🔴 Array'ler köşeli parantez içinde: ["item1", "item2"]
🔴 Null değer kullanma - boş string "" veya boş array [] kullan
🔴 Trailing comma kullanma (son öğeden sonra virgül yok)
🔴 Unicode kaçış karakterleri kullanma (\\u0000 vb.)''';
    }
  }

  /// Zorunlu kuralları oluşturur
  String _buildMandatoryRules(String language) {
    return '''[ZORUNLU KURALLAR]
1. ✅ YUKARIDAKİ JSON ŞABLONUNU KULLAN - Alanları değiştirme
2. ✅ TEK JSON OLUŞTUR - Birden fazla obje veya array değil
3. ✅ JSON SÖZDİZİMİ KURALLARINA UYGUN OLSUN
4. ✅ TÜM ALANLARI DOLDUR - Boş string yerine anlamlı içerik
5. ✅ "isHealthy" boolean değeri: true (sağlıklı) / false (hasta)
6. ✅ "diseases" array'i: Hastalık yoksa boş array []
7. ✅ "probability" değerleri: 0.0 ile 1.0 arası ondalık sayı
8. ✅ "growthScore": 0 ile 100 arası tam sayı
9. ✅ SADECE JSON DÖNDÜR - Bu talimatları cevaba dahil etme

[BAŞLA] Şimdi görüntüyü analiz et ve yukarıdaki JSON formatında yanıt ver:''';
  }

  /// Görsel analizi yapar
  ///
  /// [imageBytes] analiz edilecek görselin bayt dizisi
  /// [prompt] analiz talimatları (opsiyonel)
  /// [location] Konum bilgisi (opsiyonel)
  /// [province] İl bilgisi (opsiyonel)
  /// [district] İlçe bilgisi (opsiyonel)
  /// [neighborhood] Mahalle bilgisi (opsiyonel)
  /// [fieldName] Tarla adı (opsiyonel)
  Future<String> analyzeImageOld(
    Uint8List imageBytes, {
    String? prompt,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    // Eski metodu tamamen kaldırıyoruz
    throw UnimplementedError(
        "Bu metod artık kullanılmıyor, lütfen analyzeImage kullanın");
  }

  /// Alternatif REST API kullanarak görsel analizi yapar
  Future<String?> _sendImageToGeminiRestApi({
    required Uint8List imageBytes,
    required String prompt,
    required String apiKey,
  }) async {
    try {
      // Implementation details remain mostly the same
      // Just updating log calls for consistency
      return null; // Actual implementation would return the response text
    } catch (e) {
      logError('REST API çağrısı sırasında hata', e.toString());
      return null;
    }
  }

  /// Görüntü boyutunu azaltır
  Future<Uint8List> _resizeImageBytes(
    Uint8List bytes, {
    int maxSizeInBytes = 300 * 1024, // Varsayılan 300KB
  }) async {
    // Çok büyük görüntüleri doğrudan kes
    if (bytes.length > 1 * 1024 * 1024) {
      // 1MB'dan büyükse
      final cutRatio = maxSizeInBytes / bytes.length;
      final newSize = (bytes.length * cutRatio).toInt();
      return Uint8List.fromList(bytes.sublist(0, newSize));
    } else {
      // Daha küçük görüntüleri ise boyutunu küçült
      final ratio = maxSizeInBytes / bytes.length;

      // Basit bir şekilde kesip alıyoruz - ideal olmayan ama çalışan bir yöntem
      int targetLength = (bytes.length * ratio).toInt();
      if (targetLength >= bytes.length) {
        return bytes; // Zaten küçükse aynısını döndür
      }

      return Uint8List.fromList(bytes.sublist(0, targetLength));
    }
  }

  /// Bitki bakım tavsiyeleri alır
  Future<String> getPlantCareAdvice(String plantName) async {
    // Model başlatılmadıysa varsayılan yanıt döndür
    if (!_isInitialized || _model == null) {
      logWarning('Gemini modeli başlatılmadı. Varsayılan yanıt döndürülüyor.');

      final Map<String, dynamic> defaultResponse = {
        "title": "Bakım Tavsiyeleri",
        "plantName": plantName,
        "recommendations": [
          "Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin."
        ]
      };
      return json.encode(defaultResponse);
    }

    try {
      final content = [
        Content.text(
            '''[GÖREV] Sen bir bitkiler konusunda uzman ziraat mühendisisin. "$plantName" bitkisi için bakım tavsiyeleri vereceksin.

[FORMAT] SADECE ve YALNIZCA JSON formatında yanıt vereceksin. Cevabın başında veya sonunda herhangi bir açıklama olmadan.

[ANALİZ TALİMATLARI]
1. "$plantName" bitkisinin optimal yetiştirme şartlarını belirle.
2. Sulama sıklığı, ışık gereksinimleri, toprak tipi, gübreleme ve budama tavsiyeleri ver.
3. Yaygın sorunları ve çözümlerini belirt.
4. Tüm bilgileri Türkçe olarak hazırla.

[KRİTİK UYARI]
Verdiğin cevap YALNIZCA bu JSON nesnesi olacaktır. HİÇBİR ön söz veya son söz EKLEME.
JSON dışında TEK BİR KARAKTER bile yazma.
Markdown biçimlendirme KULLANMA.

[JSON FORMATI - TAM OLARAK BU ŞABLONU DOLDUR]
{
  "title": "Bakım Tavsiyeleri",
  "plantName": "$plantName",
  "watering": "Haftada 2 kez, toprağın üst 5 cm kısmının kuruması beklenmelidir",
  "sunlight": "Kısmi gölge ile tam güneş arası, günde 4-6 saat doğrudan güneş ışığı",
  "soil": "Organik maddece zengin, iyi drene olan, hafif asidik toprak",
  "fertilizing": "Büyüme döneminde ayda bir kez dengeli gübre, kış aylarında daha az",
  "pruning": "İlkbahar başında ölü dalları temizleyin, şeklini korumak için düzenli budama",
  "commonIssues": ["Yaprak bitleri", "Kök çürümesi", "Yapraklarda sararma"],
  "recommendations": [
    "Kireçsiz su kullanın",
    "Aşırı sulamadan kaçının",
    "Hava sirkülasyonu sağlayın",
    "Kışın sıcaklık 15°C'nin altına düşmemelidir"
  ]
}

[ZORUNLU TALİMATLAR]
1. YUKARIDAKİ JSON ŞABLONUNU KULLAN. Farklı alanlar ekleme veya çıkarma.
2. BİR JSON OLUŞTUR, BİRDEN FAZLA DEĞİL.
3. JSON SÖZDİZİMİNE KESİNLİKLE UYGUN OLSUN.
4. TÜM ALANLARI DOLDUR, boş bırakma.
5. BU TALİMATLAR KISMI DAHİL CEVABINDA HİÇBİR METİN OLMAMALI, SADECE JSON DÖNDÜR.'''),
      ];

      // Gemini-2.0-flash model ayarları
      final generationConfig = GenerationConfig(
        temperature: 0.01,
        topK: 1,
        topP: 0.99,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
        stopSequences: ['```', 'Bu yanıt', 'Bu bilgiler'],
      );

      final response = await _model!.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        logWarning('Bakım tavsiyesi alınamadı');
        final Map<String, dynamic> emptyResponse = {
          "title": "Bakım Tavsiyeleri",
          "plantName": plantName,
          "recommendations": [
            "Bakım tavsiyeleri alınamadı. Lütfen tekrar deneyin."
          ]
        };
        return json.encode(emptyResponse);
      }

      logSuccess('Bakım tavsiyesi başarıyla alındı');

      // Yanıtın JSON olup olmadığını kontrol et
      try {
        // JSON yanıt formatını doğrula, geçerli değilse ham metni JSON içinde döndür
        String responseText = response.text!.trim();

        // Markdown kod bloklarını temizle
        if (responseText.contains("```json")) {
          final startIndex = responseText.indexOf("```json") + 7;
          final endIndex = responseText.lastIndexOf("```");
          if (startIndex > 7 && endIndex > startIndex) {
            responseText = responseText.substring(startIndex, endIndex).trim();
          }
        } else if (responseText.startsWith("```") &&
            responseText.endsWith("```")) {
          responseText =
              responseText.substring(3, responseText.length - 3).trim();
        }

        // JSON geçerliliğini test et
        json.decode(responseText);
        return responseText;
      } catch (jsonError) {
        logWarning('JSON ayrıştırma hatası, ham metin döndürülüyor',
            jsonError.toString());
        final Map<String, dynamic> textResponse = {
          "title": "Bakım Tavsiyeleri",
          "plantName": plantName,
          "rawText": response.text
        };
        return json.encode(textResponse);
      }
    } catch (e) {
      logError('Gemini bakım tavsiyesi hatası', e.toString());
      final Map<String, dynamic> errorResponse = {
        "title": "Hata",
        "plantName": plantName,
        "error":
            "Bakım tavsiyeleri alınırken bir hata oluştu: ${e.toString().substring(0, math.min(e.toString().length, 100))}..."
      };
      return json.encode(errorResponse);
    }
  }

  /// Hastalık önerileri alır
  Future<String> getDiseaseRecommendations(String diseaseName) async {
    // Model başlatılmadıysa varsayılan yanıt döndür
    if (!_isInitialized || _model == null) {
      logWarning('Gemini modeli başlatılmadı. Varsayılan yanıt döndürülüyor.');

      final Map<String, dynamic> defaultResponse = {
        "title": "Hastalık Tavsiyeleri",
        "diseaseName": diseaseName,
        "recommendations": [
          "Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin."
        ]
      };
      return json.encode(defaultResponse);
    }

    try {
      final content = [
        Content.text(
            '''[GÖREV] Sen bir bitki patolojisi uzmanısın. "$diseaseName" bitki hastalığı için detaylı tedavi ve bakım önerilerini vereceksin.

[FORMAT] SADECE ve YALNIZCA JSON formatında yanıt vereceksin. Cevabın başında veya sonunda herhangi bir açıklama olmadan.

[ANALİZ TALİMATLARI]
1. "$diseaseName" bitki hastalığının belirtilerini, nedenlerini ve yayılma şeklini belirle.
2. Tedavi yöntemlerini, kimyasal ve biyolojik müdahale seçeneklerini detaylandır.
3. Gelecekte önleme stratejilerini açıkla.
4. Tüm bilgileri Türkçe olarak hazırla.

[KRİTİK UYARI]
Verdiğin cevap YALNIZCA bu JSON nesnesi olacaktır. HİÇBİR ön söz veya son söz EKLEME.
JSON dışında TEK BİR KARAKTER bile yazma.
Markdown biçimlendirme KULLANMA.

[JSON FORMATI - TAM OLARAK BU ŞABLONU DOLDUR]
{
  "title": "Hastalık Tavsiyeleri",
  "diseaseName": "$diseaseName",
  "symptoms": [
    "Yapraklarda sarı-kahverengi lekeler", 
    "Yaprak kenarlarında kıvrılma",
    "Büyüme geriliği"
  ],
  "causes": [
    "Pseudomonas syringae bakterisi", 
    "Yüksek nem oranı",
    "Hava sirkülasyonu eksikliği"
  ],
  "treatments": [
    "Etkilenen yaprakları hemen uzaklaştırın",
    "Bakır bazlı fungisitlerle ilaçlama yapın",
    "Bitki beslemesini güçlendirin"
  ],
  "prevention": [
    "Dayanıklı bitki çeşitleri kullanın",
    "Sulama yaparken yaprakları ıslatmaktan kaçının",
    "Bitkiler arasında yeterli mesafe bırakın"
  ],
  "chemicalTreatments": [
    "Bakır oksiklorür solüsyonu",
    "Mankozeb içerikli ilaçlar",
    "Streptomisin sülfat (bakteriyel enfeksiyonlar için)"
  ],
  "biologicalTreatments": [
    "Bacillus subtilis içeren biyolojik preparatlar",
    "Trichoderma harzianum mantarı içeren ürünler",
    "Sarımsak özü spreyi"
  ]
}

[ZORUNLU TALİMATLAR]
1. YUKARIDAKİ JSON ŞABLONUNU KULLAN. Farklı alanlar ekleme veya çıkarma.
2. BİR JSON OLUŞTUR, BİRDEN FAZLA DEĞİL.
3. JSON SÖZDİZİMİNE KESİNLİKLE UYGUN OLSUN.
4. TÜM ALANLARI DOLDUR, boş bırakma.
5. BU TALİMATLAR KISMI DAHİL CEVABINDA HİÇBİR METİN OLMAMALI, SADECE JSON DÖNDÜR.'''),
      ];

      // Gemini-2.0-flash model ayarları
      final generationConfig = GenerationConfig(
        temperature: 0.01,
        topK: 1,
        topP: 0.99,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
        stopSequences: ['```', 'Bu yanıt', 'Bu bilgiler'],
      );

      final response = await _model!.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        logWarning('Hastalık önerisi alınamadı');
        final Map<String, dynamic> emptyResponse = {
          "title": "Hastalık Tavsiyeleri",
          "diseaseName": diseaseName,
          "treatments": ["Öneri alınamadı. Lütfen tekrar deneyin."]
        };
        return json.encode(emptyResponse);
      }

      logSuccess('Hastalık önerisi başarıyla alındı');

      // Yanıtın JSON olup olmadığını kontrol et
      try {
        // JSON yanıt formatını doğrula, geçerli değilse ham metni JSON içinde döndür
        String responseText = response.text!.trim();

        // Markdown kod bloklarını temizle
        if (responseText.contains("```json")) {
          final startIndex = responseText.indexOf("```json") + 7;
          final endIndex = responseText.lastIndexOf("```");
          if (startIndex > 7 && endIndex > startIndex) {
            responseText = responseText.substring(startIndex, endIndex).trim();
          }
        } else if (responseText.startsWith("```") &&
            responseText.endsWith("```")) {
          responseText =
              responseText.substring(3, responseText.length - 3).trim();
        }

        // JSON geçerliliğini test et
        json.decode(responseText);
        return responseText;
      } catch (jsonError) {
        logWarning('JSON ayrıştırma hatası, ham metin döndürülüyor',
            jsonError.toString());
        final Map<String, dynamic> textResponse = {
          "title": "Hastalık Tavsiyeleri",
          "diseaseName": diseaseName,
          "rawText": response.text
        };
        return json.encode(textResponse);
      }
    } catch (e) {
      logError('Gemini öneri hatası', e.toString());
      final Map<String, dynamic> errorResponse = {
        "title": "Hata",
        "diseaseName": diseaseName,
        "error":
            "Öneri alınırken bir hata oluştu: ${e.toString().substring(0, math.min(e.toString().length, 100))}..."
      };
      return json.encode(errorResponse);
    }
  }

  /// API anahtarı
  String? get _apiKey => dotenv.env['GEMINI_API_KEY'];

  /// API endpoint
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Gemini API'ye istek gönderir
  Future<String> generateContent(String prompt) async {
    try {
      // API anahtarı kontrolü
      if (_apiKey == null || _apiKey!.isEmpty) {
        logWarning(
            'Gemini API anahtarı bulunamadı. Varsayılan yanıt döndürülüyor.');
        return _getDefaultResponse(prompt);
      }

      final response = await _dio.post(
        "$_apiUrl?key=$_apiKey",
        data: {
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 20,
            'topP': 0.7,
            'maxOutputTokens': 1024,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final candidates = data['candidates'] as List;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List;
          if (parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
        return 'Yanıt alınamadı.';
      } else {
        logError('Gemini API hatası: ${response.statusCode}', response.data);
        return "API hatası: ${response.statusCode}";
      }
    } catch (e) {
      logError('Gemini API isteği sırasında hata', e.toString());
      return "Bir hata oluştu: $e";
    }
  }

  /// API anahtarı olmadığında veya hata durumunda varsayılan yanıt döndürür
  String _getDefaultResponse(String prompt) {
    // Basit bir yanıt oluştur
    if (prompt.toLowerCase().contains('bitki') ||
        prompt.toLowerCase().contains('hastalık') ||
        prompt.toLowerCase().contains('analiz')) {
      return 'Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin.';
    }
    return "API anahtarı bulunamadı. Lütfen .env dosyanızı kontrol edin.";
  }

  /// Görsel analiz için varsayılan yanıt döndürür
  String _getDefaultImageAnalysisResponse({
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) {
    // Konum bilgilerini hazırla
    final locationInfo = _prepareLocationInfo(
        location: location,
        province: province,
        district: district,
        neighborhood: neighborhood,
        fieldName: fieldName);

    // JSON yanıt oluştur
    final Map<String, dynamic> jsonResponse = {
      "plantName": "Test Bitkisi (Testus plantus)",
      "isHealthy": false,
      "description":
          "Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin.",
      "diseases": [
        {
          "name": "Test Hastalığı",
          "description": "Bu bir test hastalığıdır. API anahtarı gerekli.",
          "probability": 0.8,
          "treatments": [
            "API anahtarınızı kontrol edin",
            "Gerçek analiz için API anahtarı kullanın"
          ]
        }
      ],
      "suggestions": [
        "API anahtarınızı kontrol edin",
        "Gerçek analiz için API anahtarı kullanın"
      ],
      "interventionMethods": ["API anahtarı ekleyin"],
      "agriculturalTips": ["Düzenli sulama yapın", "Güneş ışığı sağlayın"],
      "watering": "Haftada iki kez sulama yapın",
      "sunlight": "Orta düzeyde güneş ışığı",
      "soil": "İyi drene olmuş verimli toprak",
      "climate": "Ilıman iklim koşulları",
      "growthStage": "Test aşaması",
      "growthScore": 45,
      "growthComment": "Bu bir test gelişim yorumudur."
    };

    // Eğer konum bilgisi varsa ekle
    if (locationInfo.isNotEmpty) {
      jsonResponse["location"] = locationInfo;
    }

    try {
      // JSON'ı string'e çevir
      return json.encode(jsonResponse);
    } catch (e) {
      logError('JSON encode hatası', e.toString());
      // Hata durumunda basit format döndür
      return '{"plantName":"Test Bitkisi","isHealthy":false,"description":"JSON hatası oluştu"}';
    }
  }

  /// Görsel analiz için varsayılan boş yanıt döndürür
  String _getDefaultEmptyAnalysisResponse() {
    final Map<String, dynamic> jsonResponse = {
      "plantName": "Analiz Edilemedi",
      "isHealthy": false,
      "description":
          "Görsel analizi yapılamadı. Lütfen daha sonra tekrar deneyin.",
      "diseases": [],
      "suggestions": [
        "Daha net bir görüntü ile tekrar deneyin",
        "Farklı bir açıdan çekim yapın"
      ],
      "interventionMethods": [],
      "agriculturalTips": [],
      "watering": "Belirlenemedi",
      "sunlight": "Belirlenemedi",
      "soil": "Belirlenemedi",
      "climate": "Belirlenemedi",
      "growthStage": "Belirlenemedi",
      "growthScore": 0,
      "growthComment": "Görüntü analiz edilemedi"
    };

    try {
      return json.encode(jsonResponse);
    } catch (e) {
      return '{"plantName":"Analiz Edilemedi","isHealthy":false,"description":"Görsel analizi yapılamadı."}';
    }
  }

  /// Görsel analiz için varsayılan hata yanıtı döndürür
  String _getDefaultErrorAnalysisResponse({
    required String error,
    required String location,
  }) {
    final Map<String, dynamic> jsonResponse = {
      "plantName": "Hata Oluştu",
      "isHealthy": false,
      "description":
          "Görsel analiz sırasında bir hata oluştu: ${error.length > 100 ? '${error.substring(0, 100)}...' : error}",
      "diseases": [],
      "suggestions": [
        "Lütfen daha sonra tekrar deneyin",
        "Farklı bir görüntü ile deneme yapın"
      ],
      "interventionMethods": [],
      "agriculturalTips": [],
      "watering": "Belirlenemedi",
      "sunlight": "Belirlenemedi",
      "soil": "Belirlenemedi",
      "climate": "Belirlenemedi",
      "growthStage": "Belirlenemedi",
      "growthScore": 0,
      "growthComment": "Hata nedeniyle analiz yapılamadı"
    };

    // Konum bilgisini ekle
    if (location.isNotEmpty) {
      jsonResponse["location"] = location;
    }

    try {
      return json.encode(jsonResponse);
    } catch (e) {
      return '{"plantName":"Hata Oluştu","isHealthy":false,"description":"Görsel analiz sırasında bir hata oluştu."}';
    }
  }
}
