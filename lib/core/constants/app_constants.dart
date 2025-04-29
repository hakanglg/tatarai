import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Uygulama genelinde kullanılacak sabitler
class AppConstants {
  AppConstants._();

  // Uygulama bilgileri
  static const String appName = 'TatarAI';
  static const String appVersion = '1.0.0';

  // API Endpoint'leri

  // Gemini API
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Ücretsiz kullanıcı için analiz kredisi
  static const int FREE_ANALYSIS_CREDITS = 1;

  // Firebase collection isimleri
  static const String usersCollection = 'users';
  static const String paymentsCollection = 'payments';
  static const String settingsCollection = 'settings';

  /// Analizler koleksiyonu (ESKİ - flat yapı)
  /// [Geçiş sonrası kaldırılacak]
  static const String analysisCollection = 'analyses';

  /// Kullanıcının analizler alt koleksiyonu
  /// Yeni hiyerarşik yapı: users/{userId}/analyses/{analysisId}
  static const String userAnalysesCollection = 'analyses';

  // Önbellek süreleri (saniye cinsinden)
  static const int cacheDuration = 86400; // 24 saat

  // Dosya boyutu limitleri
  static const int maxImageSizeInBytes = 5 * 1024 * 1024; // 5 MB

  // Uygulama içi satın alma ürün ID'leri
  static const String subscriptionMonthlyId =
      'com.tatarai.subscription.monthly';
  static const String subscriptionYearlyId = 'com.tatarai.subscription.yearly';
  static const String tokenPackSmallId = 'com.tatarai.tokens.small';
  static const String tokenPackMediumId = 'com.tatarai.tokens.medium';
  static const String tokenPackLargeId = 'com.tatarai.tokens.large';

  // Resim sıkıştırma kalitesi (0-100)
  static const int imageQuality = 80;

  // Hata mesajları
  static const String errorGeneric = 'Bir hata oluştu. Lütfen tekrar deneyin.';
  static const String errorNoInternet = 'İnternet bağlantısı bulunamadı.';
  static const String errorTimeout = 'Bağlantı zaman aşımına uğradı.';
  static const String errorImageUpload = 'Resim yüklenirken bir hata oluştu.';
  static const String errorAnalysis = 'Analiz sırasında bir hata oluştu.';
  static const String errorAuthentication = 'Giriş yapılırken bir hata oluştu.';
  static const String errorPurchase =
      'Satın alma işlemi sırasında bir hata oluştu.';

  // Başarı mesajları
  static const String successAnalysis = 'Analiz başarıyla tamamlandı.';
  static const String successImageUpload = 'Resim başarıyla yüklendi.';
  static const String successAuthentication = 'Giriş başarıyla tamamlandı.';
  static const String successPurchase =
      'Satın alma işlemi başarıyla tamamlandı.';

  // Uyarı mesajları
  static const String warningImageQuality =
      'Daha iyi sonuçlar için net bir fotoğraf çekin.';
  static const String warningSubscriptionExpiring =
      'Aboneliğiniz yakında sona erecek.';
  static const String warningTokensLow = 'Token sayınız azalıyor.';

  // Animasyon süreleri (milisaniye cinsinden)
  static const int animationDurationFast = 200;
  static const int animationDurationMedium = 350;
  static const int animationDurationSlow = 500;
}
