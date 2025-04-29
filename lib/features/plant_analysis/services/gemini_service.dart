import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

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
        logWarning(
            'Gemini API anahtarı bulunamadı. Varsayılan yanıtlar kullanılacak.');
        _isInitialized = false;
        return;
      }

      // API anahtarını doğrula
      if (apiKey.length < 10) {
        logWarning(
            'Geçersiz Gemini API anahtarı. Varsayılan yanıtlar kullanılacak.');
        _isInitialized = false;
        return;
      }

      // Modeli başlatmadan önce API anahtarını kontrol et
      try {
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );
        _isInitialized = true;
        logSuccess('Gemini modeli başlatıldı');
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
    // Model başlatılmadıysa varsayılan yanıt döndür
    if (!_isInitialized || _model == null) {
      logWarning('Gemini modeli başlatılmadı. Varsayılan yanıt döndürülüyor.');
      return _getDefaultImageAnalysisResponse(
        location: location,
        province: province,
        district: district,
        neighborhood: neighborhood,
        fieldName: fieldName,
      );
    }

    try {
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

      final finalPrompt = prompt ??
          '''Sen uzman bir ziraat mühendisi ve çiftçilere tarımsal danışmanlık yapan bir uzmansın. Bu bitki görselini analiz et ve çiftçinin doğrudan kullanabileceği pratik bilgiler ver.$locationInfo

Lütfen cevabını şu formatta yapılandır:

BITKI_ADI: [Bitkinin Türkçe adı] ([Latince adı])
SAGLIK_DURUMU: [Sağlıklı/Sağlıksız]
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

Lütfen tüm bilgileri Türkçe ve çiftçinin kolayca anlayabileceği şekilde, teknik terimlerden mümkün olduğunca kaçınarak ver. MUDAHALE_YONTEMLERI bölümünde mutlaka ilaçlama, gübreleme veya diğer somut çözümler öner. Hastalık yoksa HASTALIKLAR ve MUDAHALE_YONTEMLERI bölümlerini boş bırak ve SAGLIK_DURUMU'nu "Sağlıklı" olarak belirt. Her ana başlık (örn. BITKI_ADI:) tam olarak belirtilen formatta olmalıdır.

GELISIM_ASAMASI, GELISIM_SKORU ve GELISIM_YORUMU bölümlerini mutlaka doldur. Gelişim skoru için 0-100 arası sayısal bir değer ver. Gelişim aşaması için bitkinin şu anki durumunu (fide, çiçeklenme, meyve verme vs) belirt. Yorumda ise bitkinin neden bu gelişim skoruna sahip olduğunu ve gelişimini olumlu/olumsuz etkileyen faktörleri açıkla.

Eğer konum bilgisi verilmişse, BOLGESEL_BILGILER bölümünde o bölge için özel tavsiyelerde bulun. Bölgeye uygun ilaçlar, yerel tarım uygulamaları ve iklim koşullarına göre özel öneriler sun.''';

      // Gemini 2.0 için content oluştur
      final content = [
        Content.multi([
          TextPart(finalPrompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      // Gemini-2.0-flash model ayarları
      final generationConfig = GenerationConfig(
        temperature: 0.2, // Daha yapılandırılmış çıktı için düşük sıcaklık
        topK: 32,
        topP: 1,
        maxOutputTokens: 2048,
      );

      // Genişletilmiş ayarlarla içerik oluştur
      final response = await _model!.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        logWarning('Analiz sonucu alınamadı');
        return 'Analiz sonucu alınamadı. Lütfen farklı bir görsel ile tekrar deneyin.';
      }

      logSuccess('Görsel analiz başarılı');
      return response.text!;
    } catch (e) {
      logError('Gemini görsel analiz hatası', e.toString());
      return 'Görsel analiz sırasında bir hata oluştu: ${e.toString()}';
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
        temperature: 0.4,
        topK: 32,
        topP: 1,
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
        temperature: 0.4,
        topK: 32,
        topP: 1,
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
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

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
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
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
SAGLIK_DURUMU: Sağlıklı
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
GELISIM_SKORU: 75
GELISIM_YORUMU: Bu bir test gelişim yorumudur.

SULAMA: Test sulama bilgisi
ISIK: Test ışık bilgisi
TOPRAK: Test toprak bilgisi
IKLIM: Test iklim bilgisi''';
  }
}
