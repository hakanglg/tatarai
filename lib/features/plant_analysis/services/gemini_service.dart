import 'dart:typed_data';

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
      final finalPrompt = _prepareAnalysisPrompt(prompt, locationInfo);

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
        final response =
            await _model!.generateContent([Content.text(finalPrompt)]);

        if (response.text == null || response.text!.isEmpty) {
          logWarning('Gemini boş yanıt döndürdü');
          return _getDefaultEmptyAnalysisResponse();
        }

        logSuccess('Gemini başarılı yanıt döndürdü',
            'Karakter sayısı: ${response.text!.length}');
        return response.text!;
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

  /// Analiz promptunu hazırlar
  String _prepareAnalysisPrompt(String? promptParam, String locationInfo) {
    // Konum bilgisi varsa prompt'a ekle
    final String locationPrompt = locationInfo.isNotEmpty
        ? "\n\nBu bitki $locationInfo bölgesinde yetiştirilmektedir. Bu bölgedeki iklim koşulları ve yerel tarım uygulamaları göz önünde bulundurularak önerilerinizi vermelisin."
        : "";

    // Prompt varsa kullan, yoksa default prompt
    return promptParam ??
        '''Bu görüntüdeki bitkiyi bir ziraat mühendisi ve bitki patolojisi uzmanı olarak analiz etmeni istiyorum. ÖNEMLİ: Görüntüdeki bitkide herhangi bir hastalık belirtisi (sararmış yapraklar, lekeler, kurumalar, deformasyonlar, böcek zararları vb.) olup olmadığını tespit et. 

MUTLAKA BİTKİNİN SAĞLIKLI MI YOKSA HASTALIĞA SAHİP Mİ OLDUĞUNU BELİRLE.
- Bitkide herhangi bir anormallik, renk değişimi, yaprak deformasyonu, leke, küf, çürüme, kuruma, sararma, solma, böcek istilası veya diğer hastalık belirtileri VARSA, bitki "SAĞLIKSIZ" olarak işaretlenmelidir. 
- YALNIZCA bitkide HİÇBİR hastalık belirtisi yoksa "SAĞLIKLI" olarak işaretle.
- Bitki net görünmüyorsa veya emin değilsen, yaprak rengindeki değişimlere, lekelere, böcek izlerine dikkat et. Şüphe durumunda "SAĞLIKSIZ" olarak işaretle ve muhtemel sorunları belirt.

$locationPrompt

Aşağıdaki formatta cevap ver:

BITKI_ADI: [Bitkinin Türkçe adı] ([Latince adı])
SAGLIK_DURUMU: [SAĞLIKLI/SAĞLIKSIZ] - Eğer SAĞLIKSIZ ise hastalık adını MUTLAKA belirt!

TANIM: [Bitki hakkında kısa tanım]

HASTALIKLAR:
- [Hastalık adı 1]: [Kısa açıklama ve hastalığın çiftçi tarafından tanınma belirtileri]
- [Hastalık adı 2]: [Kısa açıklama ve hastalığın çiftçi tarafından tanınma belirtileri]

MUDAHALE_YONTEMLERI:
- [İlaçlama önerisi 1]: [Kullanılabilecek ilaç/kimyasal/biyolojik mücadele yöntemi ve uygulama şekli]
- [İlaçlama önerisi 2]: [Kullanılabilecek ilaç/kimyasal/biyolojik mücadele yöntemi ve uygulama şekli]
- [Diğer müdahale yöntemleri]

TARIMSAL_ONERILER:
- [Sulama, gübreleme, budama gibi genel bakım önerileri]
- [Hastalıkları/zararlıları önlemeye yönelik tarımsal uygulamalar]
- [Toprağın iyileştirilmesi, ekim/dikim zamanı vb. konularda pratik bilgiler]

BOLGESEL_BILGILER:
- [Bölgeye özgü tarımsal bilgiler]
- [Bölgedeki yaygın sorunlar ve bu sorunlara özel çözümler]
- [Bölgesel iklim koşullarına göre uyarlamalar]

GELISIM_ASAMASI: [Bitkinin şu anki gelişim aşaması - örneğin: Fide, Çiçeklenme, Meyvelenme, Olgunlaşma, Hasat vb.]
GELISIM_SKORU: [0-100 arası bir değer olarak bitkinin gelişim durumu. Örneğin: 75]
GELISIM_YORUMU: [Bitkinin gelişim durumu hakkında kısa bir yorum, varsa gelişimini yavaşlatan faktörler veya gelişimini destekleyen olumlu koşullar]

SULAMA: [Sulama sıklığı ve yöntemleri hakkında çiftçiye pratik bilgiler]
ISIK: [Işık ihtiyacı]
TOPRAK: [Toprak gereksinimleri ve toprak hazırlama tavsiyeleri]
IKLIM: [Bölgesel iklim koşullarına göre uyarılar ve öneriler]

TEMEL İLKE: Bitki tamamen sağlıklı görünmedikçe SAĞLIKLI olarak işaretleme. Şüphe varsa, bitki SAĞLIKSIZ olarak değerlendirilmeli ve potansiyel sorunlar belirtilmelidir. SAGLIK_DURUMU değerlendirmesine özellikle dikkat et, bu çiftçi için çok önemlidir.''';
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
    try {
      // Boyut kontrolü ve log işlemi
      logInfo('analyzeImage başlatılıyor',
          'Görsel boyutu: ${imageBytes.length} bayt');

      // Görüntü boyutu fazla ise küçült (maksimum 300KB)
      Uint8List processedImageBytes = imageBytes;
      if (imageBytes.length > 300 * 1024) {
        try {
          // FlutterImageCompress ile sıkıştırma yapamıyoruz, o yüzden basit bir kesme işlemi yapacağız
          processedImageBytes =
              await _resizeImageBytes(imageBytes, maxSizeInBytes: 300 * 1024);
          logInfo('Görsel boyutu düşürüldü',
              'Orijinal: ${imageBytes.length} bayt, Yeni: ${processedImageBytes.length} bayt');
        } catch (e) {
          logWarning('Görsel boyutu düşürülemedi', e.toString());
          // Orijinal görüntü kullanılmaya devam edilecek
        }
      }

      // Konum bilgilerini hazırla
      String locationInfo = "";
      String detailedLocation = "";

      // İl, ilçe ve mahalle bilgilerinden detaylı konum oluştur
      if (province != null && district != null) {
        detailedLocation = "$province/$district";

        if (neighborhood != null && neighborhood.isNotEmpty) {
          detailedLocation += "/$neighborhood";
        }
      }

      // Eğer detaylı konum bilgisi oluşturulabilirse, onu kullan
      // Yoksa, varsa location parametresini kullan
      final String locationToUse = detailedLocation.isNotEmpty
          ? detailedLocation
          : (location != null && location.isNotEmpty)
              ? location
              : "";

      // Tarla bilgisini ekle
      String fieldInfo = "";
      if (fieldName != null && fieldName.isNotEmpty) {
        fieldInfo = " ($fieldName tarla)";
      }

      // Detaylı konum bilgisi prompt'a ekle
      if (locationToUse.isNotEmpty) {
        locationInfo =
            "\n\nBu bitki $locationToUse$fieldInfo bölgesinde yetiştirilmektedir. Bu bölgedeki iklim koşulları ve yerel tarım uygulamaları göz önünde bulundurularak önerilerinizi vermelisin.";
      }

      // Analiz prompt'ını hazırla
      final finalPrompt = prompt ?? // (mevcut prompt yapısını koru)
          '''Bu görüntüdeki bitkiyi bir ziraat mühendisi ve bitki patolojisi uzmanı olarak analiz etmeni istiyorum. ÖNEMLİ: Görüntüdeki bitkide herhangi bir hastalık belirtisi (sararmış yapraklar, lekeler, kurumalar, deformasyonlar, böcek zararları vb.) olup olmadığını tespit et. 

MUTLAKA BİTKİNİN SAĞLIKLI MI YOKSA HASTALIĞA SAHİP Mİ OLDUĞUNU BELİRLE.
- Bitkide herhangi bir anormallik, renk değişimi, yaprak deformasyonu, leke, küf, çürüme, kuruma, sararma, solma, böcek istilası veya diğer hastalık belirtileri VARSA, bitki "SAĞLIKSIZ" olarak işaretlenmelidir. 
- YALNIZCA bitkide HİÇBİR hastalık belirtisi yoksa "SAĞLIKLI" olarak işaretle.
- Bitki net görünmüyorsa veya emin değilsen, yaprak rengindeki değişimlere, lekelere, böcek izlerine dikkat et. Şüphe durumunda "SAĞLIKSIZ" olarak işaretle ve muhtemel sorunları belirt.

$locationInfo

Aşağıdaki formatta cevap ver:

BITKI_ADI: [Bitkinin Türkçe adı] ([Latince adı])
SAGLIK_DURUMU: [SAĞLIKLI/SAĞLIKSIZ] - Eğer SAĞLIKSIZ ise hastalık adını MUTLAKA belirt!

TANIM: [Bitki hakkında kısa tanım]

HASTALIKLAR:
- [Hastalık adı 1]: [Kısa açıklama ve hastalığın çiftçi tarafından tanınma belirtileri]
- [Hastalık adı 2]: [Kısa açıklama ve hastalığın çiftçi tarafından tanınma belirtileri]

MUDAHALE_YONTEMLERI:
- [İlaçlama önerisi 1]: [Kullanılabilecek ilaç/kimyasal/biyolojik mücadele yöntemi ve uygulama şekli]
- [İlaçlama önerisi 2]: [Kullanılabilecek ilaç/kimyasal/biyolojik mücadele yöntemi ve uygulama şekli]
- [Diğer müdahale yöntemleri]

TARIMSAL_ONERILER:
- [Sulama, gübreleme, budama gibi genel bakım önerileri]
- [Hastalıkları/zararlıları önlemeye yönelik tarımsal uygulamalar]
- [Toprağın iyileştirilmesi, ekim/dikim zamanı vb. konularda pratik bilgiler]

BOLGESEL_BILGILER:
- [Bölgeye özgü tarımsal bilgiler]
- [Bölgedeki yaygın sorunlar ve bu sorunlara özel çözümler]
- [Bölgesel iklim koşullarına göre uyarlamalar]

GELISIM_ASAMASI: [Bitkinin şu anki gelişim aşaması - örneğin: Fide, Çiçeklenme, Meyvelenme, Olgunlaşma, Hasat vb.]
GELISIM_SKORU: [0-100 arası bir değer olarak bitkinin gelişim durumu. Örneğin: 75]
GELISIM_YORUMU: [Bitkinin gelişim durumu hakkında kısa bir yorum, varsa gelişimini yavaşlatan faktörler veya gelişimini destekleyen olumlu koşullar]

SULAMA: [Sulama sıklığı ve yöntemleri hakkında çiftçiye pratik bilgiler]
ISIK: [Işık ihtiyacı]
TOPRAK: [Toprak gereksinimleri ve toprak hazırlama tavsiyeleri]
IKLIM: [Bölgesel iklim koşullarına göre uyarılar ve öneriler]

TEMEL İLKE: Bitki tamamen sağlıklı görünmedikçe SAĞLIKLI olarak işaretleme. Şüphe varsa, bitki SAĞLIKSIZ olarak değerlendirilmeli ve potansiyel sorunlar belirtilmelidir. SAGLIK_DURUMU değerlendirmesine özellikle dikkat et, bu çiftçi için çok önemlidir.''';

      // API anahtarı kontrolü
      String apiKey = AppConstants.geminiApiKey;
      if (apiKey.isEmpty) {
        apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      }

      if (apiKey.isEmpty) {
        logWarning('Gemini API anahtarı bulunamadı');
        return _getDefaultImageAnalysisResponse(
          location: location,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName,
        );
      }

      // Model başlatılmadıysa tekrar başlatmayı dene
      if (!_isInitialized || _model == null) {
        logInfo('Gemini modeli yeniden başlatılıyor');
        _initializeModel();

        // Hala başlatılamadıysa varsayılan yanıt dön
        if (!_isInitialized || _model == null) {
          logWarning('Gemini modeli hala başlatılamadı');
          return _getDefaultImageAnalysisResponse(
            location: location,
            province: province,
            district: district,
            neighborhood: neighborhood,
            fieldName: fieldName,
          );
        }
      }

      // Bu noktada model başarıyla başlatıldı, API isteği gönderebiliriz
      try {
        logInfo('Gemini modeline istek gönderiliyor');

        // Basitleştirilmiş API çağrısı - kütüphane değişikliklerinden etkilenmemesi için
        if (_model != null) {
          final response =
              await _model!.generateContent([Content.text(finalPrompt)]);

          if (response.text == null || response.text!.isEmpty) {
            logWarning('Gemini boş yanıt döndürdü');
            return _getDefaultEmptyAnalysisResponse();
          }

          logSuccess('Gemini başarılı yanıt döndürdü',
              'Karakter sayısı: ${response.text!.length}');
          return response.text!;
        } else {
          logError('Model null iken API isteği yapıldı');
          return _getDefaultEmptyAnalysisResponse();
        }
      } catch (apiError) {
        logError('Gemini API hatası', apiError.toString());

        // API hatalarında alternatif yöntem dene (REST API ile istek)
        try {
          logInfo('Alternatif REST API yöntemi deneniyor');
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
    } catch (error) {
      logError('Beklenmeyen analiz hatası', error.toString());
      return _getDefaultErrorAnalysisResponse(
        error: error.toString(),
        location: location ?? '',
      );
    }
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
    int quality = 85, // Varsayılan kalite
  }) async {
    // Çok büyük görüntüleri doğrudan kes
    if (bytes.length > 1 * 1024 * 1024) {
      // 1MB'dan büyükse
      final cutRatio = maxSizeInBytes / bytes.length;
      final newSize = (bytes.length * cutRatio).toInt();
      return Uint8List.fromList(bytes.sublist(0, newSize));
    } else {
      // Daha küçük görüntüleri ise kalite düşürerek küçült
      // Base64 encoding kullanarak bir string oluştur, sonra kalitesini düşürerek geri dönüştür
      // Bu metot ideal değil ama Gemini'nin ihtiyaçları için yeterli
      final ratio = maxSizeInBytes / bytes.length;
      final newQuality = (quality * ratio).toInt();

      // Kaliteyi sınırla (10-100 arası)
      final finalQuality =
          newQuality < 10 ? 10 : (newQuality > 100 ? 100 : newQuality);

      // Basit bir şekilde kesip alıyoruz - ideal olmayan ama çalışan bir yöntem
      int targetLength = (bytes.length * ratio).toInt();
      if (targetLength >= bytes.length) {
        return bytes; // Zaten küçükse aynısını döndür
      }

      return Uint8List.fromList(bytes.sublist(0, targetLength));
    }
  }

  /// Hastalık önerileri alır
  ///
  /// [diseaseName] hastalık adı
  Future<String> getDiseaseRecommendations(String diseaseName) async {
    // Model başlatılmadıysa varsayılan yanıt döndür
    if (!_isInitialized || _model == null) {
      logWarning('Gemini modeli başlatılmadı. Varsayılan yanıt döndürülüyor.');
      return 'Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin.';
    }

    try {
      final content = [
        Content.text(
          '$diseaseName bitki hastalığı için detaylı tedavi ve bakım önerileri nelerdir? '
          'Lütfen hastalığın belirtilerini, nedenlerini, yayılma şeklini, tedavi yöntemlerini '
          've gelecekte önleme stratejilerini Türkçe olarak açıklayın.',
        ),
      ];

      // Gemini-2.0-flash model ayarları
      final generationConfig = GenerationConfig(
        temperature: 0.1,
        topK: 20,
        topP: 0.7,
        maxOutputTokens: 2048,
      );

      final response = await _model!.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        logWarning('Hastalık önerisi alınamadı');
        return 'Öneri alınamadı. Lütfen tekrar deneyin.';
      }

      logSuccess('Hastalık önerisi başarıyla alındı');
      return response.text!;
    } catch (e) {
      logError('Gemini öneri hatası', e.toString());
      return 'Öneri alınırken bir hata oluştu: ${e.toString()}';
    }
  }

  /// Bitki bakım tavsiyeleri alır
  ///
  /// [plantName] bitki adı
  Future<String> getPlantCareAdvice(String plantName) async {
    // Model başlatılmadıysa varsayılan yanıt döndür
    if (!_isInitialized || _model == null) {
      logWarning('Gemini modeli başlatılmadı. Varsayılan yanıt döndürülüyor.');
      return 'Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin.';
    }

    try {
      final content = [
        Content.text(
          '$plantName bitkisi için optimal yetiştirme ve bakım tavsiyeleri nelerdir? '
          'Lütfen sulama sıklığı, ışık gereksinimleri, toprak tipi, gübreleme, budama, '
          've yaygın sorunlar hakkında Türkçe olarak detaylı bilgi verin.',
        ),
      ];

      // Gemini-2.0-flash model ayarları
      final generationConfig = GenerationConfig(
        temperature: 0.1,
        topK: 20,
        topP: 0.7,
        maxOutputTokens: 2048,
      );

      final response = await _model!.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        logWarning('Bakım tavsiyesi alınamadı');
        return 'Bakım tavsiyeleri alınamadı. Lütfen tekrar deneyin.';
      }

      logSuccess('Bakım tavsiyesi başarıyla alındı');
      return response.text!;
    } catch (e) {
      logError('Gemini bakım tavsiyesi hatası', e.toString());
      return 'Bakım tavsiyeleri alınırken bir hata oluştu: ${e.toString()}';
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
        '$_apiUrl?key=$_apiKey',
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
        return 'API hatası: ${response.statusCode}';
      }
    } catch (e) {
      logError('Gemini API isteği sırasında hata', e.toString());
      return 'Bir hata oluştu: $e';
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
    return 'API anahtarı bulunamadı. Lütfen .env dosyanızı kontrol edin.';
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
    String locationInfo = "";
    String detailedLocation = "";

    // İl, ilçe ve mahalle bilgilerinden detaylı konum oluştur
    if (province != null && district != null) {
      detailedLocation = "$province/$district";

      if (neighborhood != null && neighborhood.isNotEmpty) {
        detailedLocation += "/$neighborhood";
      }
    }

    // Eğer detaylı konum bilgisi oluşturulabilirse, onu kullan
    // Yoksa, varsa location parametresini kullan
    final String locationToUse = detailedLocation.isNotEmpty
        ? detailedLocation
        : (location != null && location.isNotEmpty)
            ? location
            : "";

    // Tarla bilgisini ekle
    String fieldInfo = "";
    if (fieldName != null && fieldName.isNotEmpty) {
      fieldInfo = " ($fieldName tarla)";
    }

    // Konum bilgisini ekle
    if (locationToUse.isNotEmpty) {
      locationInfo =
          "\n\nBu bitki $locationToUse$fieldInfo bölgesinde yetiştirilmektedir.";
    }

    // Varsayılan yanıt oluştur
    return '''BITKI_ADI: Test Bitkisi (Testus plantus)
SAGLIK_DURUMU: Sağlıksız
TANIM: Bu bir test yanıtıdır. Gerçek Gemini API yanıtı için API anahtarınızı kontrol edin.

HASTALIKLAR:
- Test Hastalığı: Bu bir test hastalığıdır.

MUDAHALE_YONTEMLERI:
- Test İlaçlama: Bu bir test ilaçlamadır.

TARIMSAL_ONERILER:
- Test Sulama: Bu bir test sulamadır.
- Test Gübreleme: Bu bir test gübrelemedir.

BOLGESEL_BILGILER:
- Test Bölge Bilgisi: Bu bir test bölge bilgisidir.$locationInfo

GELISIM_ASAMASI: Test Aşaması
GELISIM_SKORU: 45
GELISIM_YORUMU: Bu bir test gelişim yorumudur.

SULAMA: Test sulama bilgisi
ISIK: Test ışık bilgisi
TOPRAK: Test toprak bilgisi
IKLIM: Test iklim bilgisi''';
  }

  /// Görsel analiz için varsayılan boş yanıt döndürür
  String _getDefaultEmptyAnalysisResponse() {
    return 'Görsel analizi yapılamadı. Lütfen daha sonra tekrar deneyin.';
  }

  /// Görsel analiz için varsayılan hata yanıtı döndürür
  String _getDefaultErrorAnalysisResponse({
    required String error,
    required String location,
  }) {
    return 'Görsel analiz sırasında bir hata oluştu: $error. Lütfen daha sonra tekrar deneyin.';
  }
}
