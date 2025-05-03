import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Doğrulama işlemleri için yardımcı sınıf
/// Projede tekrar eden doğrulama işlemlerini merkezi olarak yönetir
class ValidationUtil {
  ValidationUtil._();

  /// Kullanıcının analiz kredisini kontrol eder
  ///
  /// @param user - Kullanıcı modeli
  /// @return ValidationResult - Doğrulama sonucu
  static Future<ValidationResult> checkUserCredits(UserModel? user) async {
    try {
      AppLogger.i('Kullanıcı kredi kontrolü yapılıyor', 'UserID: ${user?.id}');

      if (user == null) {
        AppLogger.e('Kullanıcı oturum açmamış');
        return ValidationResult(
          isValid: false,
          message: 'Kullanıcı oturum açmamış',
        );
      }

      // Eğer kullanıcı premium ise veya kredisi varsa analiz yapılabilir
      if (user.isPremium || user.hasAnalysisCredits) {
        AppLogger.i('Kullanıcı analiz yapabilir',
            'Premium: ${user.isPremium}, Kalan kredi: ${user.analysisCredits}');
        return ValidationResult(isValid: true);
      }

      // Kredisi yoksa ve premium değilse hata mesajı göster
      AppLogger.w('Kullanıcının analiz kredisi yok',
          'Premium: ${user.isPremium}, Kalan kredi: ${user.analysisCredits}');

      return ValidationResult(
        isValid: false,
        message:
            'Ücretsiz analiz hakkınızı kullandınız. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
        needsPremium: true,
      );
    } catch (error) {
      AppLogger.e('Kredi kontrolü sırasında hata oluştu', error);

      // Hata durumunda analiz yapmaya izin verme
      return ValidationResult(
        isValid: false,
        message:
            'Kullanıcı bilgileriniz yüklenirken bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Firestore'dan en güncel kullanıcı bilgilerini alarak kredi kontrolü yapar
  ///
  /// @param userId - Kullanıcı ID'si
  /// @param firestore - Firestore örneği
  /// @return ValidationResult - Doğrulama sonucu
  static Future<ValidationResult> checkUserCreditsFromFirestore(
    String userId,
    FirebaseFirestore firestore,
  ) async {
    try {
      AppLogger.i('Firestore\'dan kullanıcı kredi kontrolü yapılıyor',
          'UserID: $userId');

      final userDocRef = await firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      final userDataMap = userDocRef.data();

      if (userDataMap == null) {
        AppLogger.w('Kullanıcı bilgileri bulunamadı', 'userId: $userId');
        return ValidationResult(
          isValid: false,
          message: 'Kullanıcı bilgileri bulunamadı.',
        );
      }

      final int userCredits = userDataMap['analysisCredits'] ?? 0;
      final bool isPremium = userDataMap['isPremium'] ?? false;

      // Eğer kullanıcı premium ise veya kredisi varsa analiz yapılabilir
      if (isPremium || userCredits > 0) {
        AppLogger.i('Kullanıcı analiz yapabilir',
            'Premium: $isPremium, Kalan kredi: $userCredits');
        return ValidationResult(isValid: true);
      }

      // Kredisi yoksa ve premium değilse hata mesajı göster
      AppLogger.w('Kullanıcının kredisi yok',
          'credits: $userCredits, isPremium: $isPremium');

      return ValidationResult(
        isValid: false,
        message:
            'Analiz yapmak için yeterli krediniz bulunmuyor. Premium üyelik satın alarak veya kredi yükleyerek analizlere devam edebilirsiniz.',
        needsPremium: true,
      );
    } catch (e) {
      AppLogger.e('Firestore\'dan kredi kontrolü sırasında hata oluştu', e);
      return ValidationResult(
        isValid: false,
        message:
            'Kullanıcı bilgileriniz yüklenirken bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Analiz görüntü dosyasını doğrular
  ///
  /// @param imageFile - Görüntü dosyası
  /// @return ValidationResult - Doğrulama sonucu
  static Future<ValidationResult> validateImageFile(File? imageFile) async {
    // 1. Dosya kontrolü
    if (imageFile == null || !imageFile.existsSync()) {
      AppLogger.e('Analiz için geçerli bir görüntü dosyası mevcut değil');
      return ValidationResult(
        isValid: false,
        message: 'Lütfen geçerli bir bitki fotoğrafı seçin.',
        errorType: 'image',
      );
    }

    // 2. Dosya boyutu kontrolü (20MB'den büyük olmamalı)
    final fileSize = await imageFile.length();
    if (fileSize > 20 * 1024 * 1024) {
      // 20MB
      AppLogger.e(
          'Dosya boyutu çok büyük: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB');
      return ValidationResult(
        isValid: false,
        message:
            'Seçilen fotoğraf çok büyük. Lütfen 20MB\'den küçük bir fotoğraf seçin.',
        errorType: 'image',
      );
    }

    AppLogger.i('Görüntü dosyası doğrulandı',
        'Boyut: ${(fileSize / 1024).toStringAsFixed(2)} KB');
    return ValidationResult(isValid: true);
  }

  /// İnternet bağlantısını kontrol eder
  ///
  /// @return ValidationResult - Doğrulama sonucu
  static Future<ValidationResult> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isConnected = connectivityResult != ConnectivityResult.none;

      if (!isConnected) {
        AppLogger.w('Ağ bağlantısı bulunamadı');
        return ValidationResult(
          isValid: false,
          message:
              'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
          errorType: 'network',
        );
      }

      AppLogger.i('Ağ bağlantısı mevcut', 'Bağlantı türü: $connectivityResult');
      return ValidationResult(isValid: true);
    } catch (e) {
      AppLogger.w('Bağlantı durumu kontrol edilirken hata oluştu', e);
      // Bağlantı kontrolünde hata olsa bile devam etmeye çalışalım
      return ValidationResult(isValid: true);
    }
  }
}

/// Doğrulama sonucu sınıfı
class ValidationResult {
  /// Doğrulama başarılı mı
  final bool isValid;

  /// Hata mesajı (geçersiz durumlarda)
  final String? message;

  /// Premium gerekiyor mu
  final bool needsPremium;

  /// Hata türü (image, network, auth, vs.)
  final String? errorType;

  ValidationResult({
    required this.isValid,
    this.message,
    this.needsPremium = false,
    this.errorType,
  });
}
