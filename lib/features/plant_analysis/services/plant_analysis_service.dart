import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/validation_util.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';

/// Bitki analizi servisi
/// Kullanıcının analiz hakkı kontrolünü yaparak Gemini servisine yönlendirir
class PlantAnalysisService extends BaseService {
  final GeminiService _geminiService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final AuthService _authService;

  /// Servis oluşturulurken gerekli bağımlılıkları alır
  PlantAnalysisService({
    GeminiService? geminiService,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required AuthService authService,
  })  : _geminiService = geminiService ?? GeminiService(),
        _firestore = firestore,
        _storage = storage,
        _authService = authService;

  /// Bitki analizi yapar ve kullanıcı kredisini kontrol eder
  ///
  /// [imageBytes] analiz edilecek görselin bayt dizisi
  /// [userId] kullanıcı kimliği
  /// [prompt] analiz talimatları (opsiyonel)
  /// [location] Konum bilgisi (opsiyonel)
  /// [province] İl bilgisi (opsiyonel)
  /// [district] İlçe bilgisi (opsiyonel)
  /// [neighborhood] Mahalle bilgisi (opsiyonel)
  /// [fieldName] Tarla adı (opsiyonel)
  Future<AnalysisResponse> analyzePlant(
    Uint8List imageBytes,
    String userId, {
    String? prompt,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      logStart('analyzePlant',
          'Görsel boyutu: ${imageBytes.length} bayt, UserId: $userId');

      // 1. Kullanıcı kontrolü
      final user = _authService.currentUser;
      if (user == null) {
        logError('Kullanıcı oturum açmamış');
        return AnalysisResponse(
          success: false,
          message: 'Kullanıcı oturum açmamış',
        );
      }

      // 2. Bağlantı kontrolü
      final ValidationResult connectivityValidation =
          await ValidationUtil.checkConnectivity();
      if (!connectivityValidation.isValid) {
        logWarning(
            'Bağlantı kontrolü başarısız', connectivityValidation.message);
        return AnalysisResponse(
          success: false,
          message:
              connectivityValidation.message ?? 'İnternet bağlantısı hatası',
        );
      }

      // 3. Kullanıcı kredisi kontrolü
      final ValidationResult creditValidation =
          await ValidationUtil.checkUserCreditsFromFirestore(
              userId, _firestore);

      if (!creditValidation.isValid) {
        logWarning(
            'Kullanıcı kredisi kontrolü başarısız', creditValidation.message);
        return AnalysisResponse(
          success: false,
          message: creditValidation.message ?? 'Analiz hakkınız bulunmuyor.',
          needsPremium: creditValidation.needsPremium,
        );
      }

      // 4. Konum bilgisini hazırla
      final String locationInfo = _prepareLocationInfo(
          location: location,
          province: province,
          district: district,
          neighborhood: neighborhood);

      // 5. Analizi gerçekleştir
      try {
        logInfo('GeminiService.analyzeImage çağrılıyor',
            'Görsel boyutu: ${imageBytes.length} bayt');

        final result = await _geminiService.analyzeImage(
          imageBytes,
          prompt: prompt,
          location: locationInfo,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName,
        );

        // 6. Başarılı cevap işleme
        logSuccess('GeminiService işlemi başarılı',
            'Yanıt uzunluğu: ${result.length} karakter');

        // 7. Kredi güncelleme
        await _updateUserCredits(userId);

        // 8. Sonucu döndür
        logEnd('analyzePlant', 'userId: $userId');
        return AnalysisResponse(
          success: true,
          message: 'Analiz başarıyla tamamlandı.',
          result: result,
          location: locationInfo,
          fieldName: fieldName,
        );
      } catch (geminiError) {
        logError('GeminiService hatası', geminiError.toString());
        return _createErrorResponse(geminiError);
      }
    } catch (e) {
      logError('Bitki analizi genel hatası', e.toString());
      return AnalysisResponse(
        success: false,
        message:
            'Analiz sırasında bir hata oluştu: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}...',
      );
    }
  }

  /// Kullanıcı kredisini günceller
  Future<void> _updateUserCredits(String userId) async {
    try {
      // Kullanıcı verilerini al
      final userDocRef = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final userDataMap = userDocRef.data();
      final bool isPremium = userDataMap?['isPremium'] ?? false;

      // Premium değilse, krediyi azalt
      if (!isPremium) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({'analysisCredits': FieldValue.increment(-1)});

        // Kalan kredi sayısını log'la
        final int userCredits = userDataMap?['analysisCredits'] ?? 0;
        final int remainingCredits = userCredits - 1;
        logInfo(
            'Kullanıcı kredisi düşürüldü', 'Kalan kredi: $remainingCredits');
      }
    } catch (e) {
      logWarning('Kredi güncellemesi yapılamadı', e.toString());
      // Kredi güncellemesi yapılamazsa hata fırlatma, işleme devam et
    }
  }

  /// Konum bilgisini hazırlar
  String _prepareLocationInfo(
      {String? location,
      String? province,
      String? district,
      String? neighborhood}) {
    String detailedLocation = "";

    // İl, ilçe ve mahalle bilgilerinden detaylı konum oluştur
    if (province != null && district != null) {
      detailedLocation = "$province/$district";
      if (neighborhood != null && neighborhood.isNotEmpty) {
        detailedLocation += "/$neighborhood";
      }
    }

    // Detaylı konum yoksa verilen lokasyonu kullan
    return detailedLocation.isNotEmpty
        ? detailedLocation
        : (location != null && location.isNotEmpty)
            ? location
            : "Tekirdağ/Tatarlı";
  }

  /// API hatası için yanıt oluşturur
  AnalysisResponse _createErrorResponse(dynamic geminiError) {
    String errorMessage =
        'Analiz sırasında bir hata oluştu: ${geminiError.toString()}';

    if (geminiError.toString().contains('API anahtarı')) {
      errorMessage =
          'API anahtarı hatası: Lütfen daha sonra tekrar deneyin veya destek ile iletişime geçin.';
    } else if (geminiError.toString().contains('Network')) {
      errorMessage =
          'Ağ hatası: İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (geminiError.toString().contains('403')) {
      errorMessage = 'Yetkilendirme hatası: Gemini API erişimi sağlanamadı.';
    }

    return AnalysisResponse(
      success: false,
      message: errorMessage,
    );
  }

  /// Görsel olmadan hastalık önerisi alır
  ///
  /// [diseaseName] hastalık adı
  /// [userId] kullanıcı kimliği
  Future<AnalysisResponse> getDiseaseAdvice(
    String diseaseName,
    String userId,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        logError('Kullanıcı oturum açmamış');
        return AnalysisResponse(
          success: false,
          message: 'Kullanıcı oturum açmamış',
        );
      }

      // ValidationUtil ile premium kullanıcı kontrolü
      final ValidationResult creditValidation =
          await ValidationUtil.checkUserCreditsFromFirestore(
              userId, _firestore);
      final userDocRef = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final userDataMap = userDocRef.data();
      final bool isPremium = userDataMap?['isPremium'] ?? false;

      // Bu özellik sadece premium kullanıcılar için
      if (!isPremium) {
        logWarning('Premium olmayan kullanıcı hastalık önerisi istedi',
            'userId: $userId');
        return AnalysisResponse(
          success: false,
          message:
              'Detaylı hastalık önerileri sadece premium kullanıcılar için sunulmaktadır.',
          needsPremium: true,
        );
      }

      // Premium kullanıcı - öneri al
      final result = await _geminiService.getDiseaseRecommendations(
        diseaseName,
      );

      logSuccess('Hastalık önerileri başarıyla getirildi',
          'userId: $userId, disease: $diseaseName');
      return AnalysisResponse(
        success: true,
        message: 'Hastalık önerileri başarıyla getirildi.',
        result: result,
      );
    } catch (e) {
      logError('Hastalık önerileri alınırken hata oluştu', e.toString());
      return AnalysisResponse(
        success: false,
        message: 'Öneriler alınırken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  /// Görsel olmadan bitki bakım tavsiyeleri alır
  ///
  /// [plantId] bitki adı
  /// [userId] kullanıcı kimliği
  Future<AnalysisResponse> getPlantCareAdvice(
    String plantId,
    String userId,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        logError('Kullanıcı oturum açmamış');
        throw Exception('Kullanıcı oturum açmamış');
      }

      // Kullanıcının premium olup olmadığını kontrol et
      final userDocRef = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final userDataMap = userDocRef.data();
      final bool isPremium = userDataMap?['isPremium'] ?? false;

      // Bu özellik sadece premium kullanıcılar için
      if (!isPremium) {
        logWarning('Premium olmayan kullanıcı bakım önerisi istedi',
            'userId: $userId');
        return AnalysisResponse(
          success: false,
          message:
              'Detaylı bakım önerileri sadece premium kullanıcılar için sunulmaktadır.',
          needsPremium: true,
        );
      }

      logInfo('Bitki bakım önerisi alınıyor...');

      // Premium kullanıcı - öneri al
      final result = await _geminiService.getPlantCareAdvice(
        plantId,
      );

      logSuccess('Bitki bakım önerileri başarıyla getirildi',
          'userId: $userId, plantId: $plantId');
      return AnalysisResponse(
        success: true,
        message: 'Bitki bakım önerileri başarıyla getirildi.',
        result: result,
      );
    } catch (e) {
      logError('Bitki bakım önerisi alınırken hata oluştu', e.toString());
      return AnalysisResponse(
        success: false,
        message:
            'Bitki bakım önerisi alınırken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  /// Dosyadan bayt dizisi oluşturur
  ///
  /// [file] dosya
  Future<Uint8List> fileToBytes(File file) async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      logError('Dosyadan bayt dizisi oluşturma hatası', e.toString());
      rethrow;
    }
  }
}

/// Analiz cevabı için model sınıfı
class AnalysisResponse {
  /// İşlem başarılı mı
  final bool success;

  /// Kullanıcıya gösterilecek mesaj
  final String message;

  /// Analiz sonucu (varsa)
  final String? result;

  /// Premium özellik gerektiriyor mu
  final bool needsPremium;

  /// Konum bilgisi (opsiyonel)
  final String? location;

  /// Tarla adı (opsiyonel)
  final String? fieldName;

  /// Analiz cevabı oluşturur
  AnalysisResponse({
    required this.success,
    required this.message,
    this.result,
    this.needsPremium = false,
    this.location,
    this.fieldName,
  });
}
