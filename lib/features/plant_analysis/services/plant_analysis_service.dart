import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';

/// Bitki analizi servisi
/// Kullanıcının analiz hakkı kontrolünü yaparak Gemini servisine yönlendirir
class PlantAnalysisService {
  final GeminiService _geminiService;
  final FirebaseFirestore _firestore;

  /// Servis oluşturulurken gerekli bağımlılıkları alır
  PlantAnalysisService({
    GeminiService? geminiService,
    FirebaseFirestore? firestore,
  })  : _geminiService = geminiService ?? GeminiService(),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'tatarai',
            );

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
      // Eğer konum bilgisi verilmemişse varsayılan konumu kullan
      final String locationInfo = location ?? 'Tekirdağ/Tatarlı';

      // Kullanıcı kredi kontrolü
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final userData = userDoc.data();

      if (userData == null) {
        return AnalysisResponse(
          success: false,
          message: 'Kullanıcı bilgileri bulunamadı.',
        );
      }

      final int credits = userData['analysisCredits'] ?? 0;
      final bool isPremium = userData['isPremium'] ?? false;

      // Eğer kullanıcı premium değilse ve kredisi yoksa analiz yapılamaz
      if (credits <= 0 && !isPremium) {
        return AnalysisResponse(
          success: false,
          message:
              'Ücretsiz analiz hakkınızı kullandınız. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
          needsPremium: true,
        );
      }

      // Kredi var veya premium kullanıcı - analizi yap
      final result = await _geminiService.analyzeImage(
        imageBytes,
        prompt: prompt,
        location: locationInfo, // Konum bilgisini Gemini'ye ilet
        province: province, // İl bilgisi
        district: district, // İlçe bilgisi
        neighborhood: neighborhood, // Mahalle bilgisi
        fieldName: fieldName, // Tarla adı
      );

      // Premium değilse, krediyi azalt
      if (!isPremium) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({'analysisCredits': FieldValue.increment(-1)});

        // Kalan kredi sayısını log'la
        final int remainingCredits = credits - 1;
        AppLogger.i(
          'Kullanıcı kredisi düşürüldü. Kalan kredi: $remainingCredits',
        );
      }

      return AnalysisResponse(
        success: true,
        message: 'Analiz başarıyla tamamlandı.',
        result: result,
        location: locationInfo, // Konum bilgisini yanıta ekle
        fieldName: fieldName, // Tarla adını yanıta ekle
      );
    } catch (e) {
      AppLogger.e('Bitki analizi sırasında hata oluştu', e);
      return AnalysisResponse(
        success: false,
        message: 'Analiz sırasında bir hata oluştu: ${e.toString()}',
      );
    }
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
      // Kullanıcının premium olup olmadığını kontrol et
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final bool isPremium = userDoc.data()?['isPremium'] ?? false;

      // Bu özellik sadece premium kullanıcılar için
      if (!isPremium) {
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

      return AnalysisResponse(
        success: true,
        message: 'Hastalık önerileri başarıyla getirildi.',
        result: result,
      );
    } catch (e) {
      AppLogger.e('Hastalık önerileri alınırken hata oluştu', e);
      return AnalysisResponse(
        success: false,
        message: 'Öneriler alınırken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  /// Görsel olmadan bitki bakım tavsiyeleri alır
  ///
  /// [plantName] bitki adı
  /// [userId] kullanıcı kimliği
  Future<AnalysisResponse> getPlantCareAdvice(
    String plantName,
    String userId,
  ) async {
    try {
      // Kullanıcının premium olup olmadığını kontrol et
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final userData = userDoc.data();

      if (userData == null) {
        return AnalysisResponse(
          success: false,
          message: 'Kullanıcı bilgileri bulunamadı.',
        );
      }

      final int credits = userData['analysisCredits'] ?? 0;
      final bool isPremium = userData['isPremium'] ?? false;

      // Normal kullanıcılar için kredi kontrolü yap
      if (!isPremium && credits <= 0) {
        return AnalysisResponse(
          success: false,
          message:
              'Bakım tavsiyeleri almak için krediniz tükendi. Premium üyelik satın alarak sınırsız tavsiye alabilirsiniz.',
          needsPremium: true,
        );
      }

      // Bakım tavsiyesi al
      final result = await _geminiService.getPlantCareAdvice(plantName);

      // Premium değilse, krediyi azalt
      if (!isPremium) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({'analysisCredits': FieldValue.increment(-1)});
      }

      return AnalysisResponse(
        success: true,
        message: 'Bakım tavsiyeleri başarıyla getirildi.',
        result: result,
      );
    } catch (e) {
      AppLogger.e('Bakım tavsiyeleri alınırken hata oluştu', e);
      return AnalysisResponse(
        success: false,
        message: 'Tavsiyeler alınırken bir hata oluştu: ${e.toString()}',
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
      AppLogger.e('Dosyadan bayt dizisi oluşturma hatası', e);
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
