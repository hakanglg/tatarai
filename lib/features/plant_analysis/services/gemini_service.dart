import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Gemini 2.0 Flash AI modelini kullanarak görsel analiz ve önerileri yöneten servis
class GeminiService {
  late final GenerativeModel _model;

  /// Gemini servisini başlatır ve modeli yapılandırır
  GeminiService() {
    _initializeModel();
  }

  /// Gemini modelini yapılandırır
  void _initializeModel() {
    try {
      final apiKey = AppConstants.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception(
            'Gemini API anahtarı bulunamadı. Lütfen .env dosyasını kontrol edin.');
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
      );
      AppLogger.i('Gemini modeli başarıyla başlatıldı');
    } catch (e) {
      AppLogger.e('Gemini modeli başlatılamadı', e);
      rethrow;
    }
  }

  /// Bitki görselini analiz eder ve detaylı bilgi verir
  ///
  /// [imageBytes] analiz edilecek görselin bayt dizisi
  /// [prompt] analiz talimatları (opsiyonel, varsayılan talimatlara sahiptir)
  /// [location] Konum bilgisi, "Şehir/İlçe" formatında (opsiyonel)
  /// [province] İl bilgisi
  /// [district] İlçe bilgisi
  /// [neighborhood] Mahalle bilgisi
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
      final response = await _model.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        return 'Analiz sonucu alınamadı. Lütfen farklı bir görsel ile tekrar deneyin.';
      }

      return response.text!;
    } catch (e) {
      AppLogger.e('Gemini görsel analiz hatası', e);
      return 'Görsel analiz sırasında bir hata oluştu: ${e.toString()}';
    }
  }

  /// Belirli bir bitki hastalığı için detaylı tedavi ve bakım önerileri sunar
  ///
  /// [diseaseName] hastalık adı
  Future<String> getDiseaseRecommendations(String diseaseName) async {
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

      final response = await _model.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        return 'Öneri alınamadı. Lütfen tekrar deneyin.';
      }

      return response.text!;
    } catch (e) {
      AppLogger.e('Gemini öneri hatası', e);
      return 'Öneri alınırken bir hata oluştu: ${e.toString()}';
    }
  }

  /// Bitki yetiştirme ve bakım tavsiyeleri sunar
  ///
  /// [plantName] bitki adı
  Future<String> getPlantCareAdvice(String plantName) async {
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

      final response = await _model.generateContent(
        content,
        generationConfig: generationConfig,
      );

      if (response.text == null || response.text!.isEmpty) {
        return 'Bakım tavsiyeleri alınamadı. Lütfen tekrar deneyin.';
      }

      return response.text!;
    } catch (e) {
      AppLogger.e('Gemini bakım tavsiyesi hatası', e);
      return 'Bakım tavsiyeleri alınırken bir hata oluştu: ${e.toString()}';
    }
  }
}
