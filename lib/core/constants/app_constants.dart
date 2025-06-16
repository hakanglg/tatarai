import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Uygulama genelinde kullanılacak sabitler
class AppConstants {
  AppConstants._();

  // Uygulama bilgileri
  static const String appName = 'TatarAI';
  static const String appVersion = '1.0.1';

  // API Endpoint'leri

  // Gemini API
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // RevenueCat API anahtarları ve sabitleri
  static String get revenueiOSApiKey =>
      dotenv.env['REVENUECAT_IOS_API_KEY'] ?? '';
  // static String get revenueAndroidApiKey => dotenv.env['REVENUECAT_API_KEY'] ?? '';
  static const String entitlementId = 'premium';

  // Ücretsiz kullanıcı için analiz kredisi
  static const int FREE_ANALYSIS_CREDITS = 5;

  // Firebase collection isimleri
  static const String usersCollection = 'users';
  static const String paymentsCollection = 'payments';
  static const String settingsCollection = 'settings';

  /// Kullanıcının analizler alt koleksiyonu
  /// Yeni hiyerarşik yapı: users/{userId}/analyses/{analysisId}
  static const String userAnalysesCollection = 'analyses';

  // Önbellek süreleri (saniye cinsinden)
  static const int cacheDuration = 86400; // 24 saat

  // Dosya boyutu limitleri
  static const int maxImageSizeInBytes = 5 * 1024 * 1024; // 5 MB

  // Uygulama içi satın alma ürün ID'leri
  static const String subscriptionMonthlyId = 'tatarai_premium_monthly';
  static const String subscriptionYearlyId = 'tatarai_premium_yearly';
  static const String subscriptionLifetimeId = 'tatarai_premium_lifetime';

  // Resim sıkıştırma kalitesi (0-100)
  static const int imageQuality = 80;

  // Animasyon süreleri (milisaniye cinsinden)
  static const int animationDurationFast = 200;
  static const int animationDurationMedium = 350;
  static const int animationDurationSlow = 500;

  // Analiz Kredileri
  static const int PREMIUM_MONTHLY_CREDITS = 100; // Premium aylık kredi
  static const int PREMIUM_YEARLY_CREDITS = 1200; // Premium yıllık kredi
  static const int PREMIUM_LIFETIME_CREDITS = -1; // Sınırsız (Lifetime)

  // UI Boyutları ve Spacing'ler
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeXL = 32.0;

  // Progress Bar ve Score Ayarları
  static const int maxGrowthScore = 100;
  static const double progressBarHeight = 8.0;
  static const double progressBarRadius = 4.0;

  // Font Size Multipliers
  static const double fontSizeMultiplierSmall = 0.9;
  static const double fontSizeMultiplierLarge = 1.05;

  // Border Width ve Opacity Değerleri
  static const double borderWidthThin = 0.5;
  static const double borderWidthDefault = 1.0;
  static const double opacityLight = 0.1;
  static const double opacityMedium = 0.3;
  static const double opacityHeavy = 0.8;

  // Timeout Değerleri
  static const int connectionTimeoutSeconds = 5;
  static const int firebaseTimeoutSeconds = 5;
  static const int uploadTimeoutSeconds = 30;

  // Retry Ayarları
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2;

  static const double MINIMUM_IDENTIFICATION_PROBABILITY =
      0.4; // Tanımlama için minimum olasılık
}
