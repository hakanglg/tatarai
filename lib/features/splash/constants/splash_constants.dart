/// Splash screen için sabit değerler
///
/// Bu dosya splash screen animasyonları, timing'ler ve
/// diğer konfigürasyonel değerleri içerir.
class SplashConstants {
  SplashConstants._();

  // ============================================================================
  // ANIMATION CONSTANTS
  // ============================================================================

  /// Ana animasyon süresi (milisaniye)
  static const int animationDurationMs = 1000;

  /// Logo scale animasyon süresi
  static const Duration logoAnimationDuration =
      Duration(milliseconds: animationDurationMs);

  /// Logo maksimum genişlik oranı (ekran genişliğine göre)
  static const double logoMaxWidthRatio = 0.8;

  /// Logo boyutu
  static const double logoSize = 120.0;

  /// Logo icon boyutu
  static const double logoIconSize = 70.0;

  /// Logo opacity değeri
  static const double logoBackgroundOpacity = 0.2;

  // ============================================================================
  // TIMING CONSTANTS
  // ============================================================================

  /// Maximum initialization timeout süresi
  static const Duration maxInitializationTimeout = Duration(seconds: 3);

  /// Version check timeout süresi
  static const Duration versionCheckTimeout = Duration(seconds: 5);

  /// Navigation retry delay
  static const Duration navigationRetryDelay = Duration(seconds: 2);

  // ============================================================================
  // LAYOUT CONSTANTS
  // ============================================================================

  /// Logo altındaki boşluk
  static const double spaceBelowLogo = 24.0;

  /// Subtitle altındaki boşluk
  static const double spaceBelowSubtitle = 8.0;

  /// Loading indicator üstündeki boşluk
  static const double spaceAboveLoader = 48.0;

  /// Minimum logo genişliği
  static const double logoMinWidth = 10.0;

  // ============================================================================
  // SHARED PREFERENCES KEYS
  // ============================================================================

  /// Onboarding completed key
  static const String onboardingCompletedKey = 'onboarding_completed';

  // ============================================================================
  // DEBUG CONSTANTS
  // ============================================================================

  /// Debug test mode flag
  static const bool debugTestMode = false;

  /// Debug test case (1: force update, 2: optional update)
  static const int debugTestCase = 2;
}
