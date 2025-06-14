/// Home feature için sabit değerler
///
/// Bu dosya home screen animasyonları, UI boyutları ve
/// diğer konfigürasyonel değerleri içerir.
class HomeConstants {
  HomeConstants._();

  // ============================================================================
  // ANIMATION CONSTANTS
  // ============================================================================

  /// Ana animasyon süresi (milisaniye)
  static const int animationDurationMs = 800;

  /// Header animasyon gecikmesi
  static const Duration headerAnimationDelay = Duration(milliseconds: 100);

  /// Card animasyon gecikmesi
  static const Duration cardAnimationDelay = Duration(milliseconds: 200);

  /// Quick actions animasyon gecikmesi
  static const Duration quickActionsAnimationDelay =
      Duration(milliseconds: 300);

  // ============================================================================
  // UI CONSTANTS
  // ============================================================================

  /// Header gradient opacity (başlangıç)
  static const double headerGradientStartOpacity = 0.9;

  /// Header gradient opacity (bitiş)
  static const double headerGradientEndOpacity = 0.7;

  /// Header shadow opacity
  static const double headerShadowOpacity = 0.2;

  /// Header shadow blur radius
  static const double headerShadowBlurRadius = 10.0;

  /// Header shadow offset Y
  static const double headerShadowOffsetY = 4.0;

  /// Welcome text opacity
  static const double welcomeTextOpacity = 0.9;

  /// Header text shadow opacity
  static const double headerTextShadowOpacity = 0.1;

  /// Header text shadow blur radius
  static const double headerTextShadowBlurRadius = 2.0;

  // ============================================================================
  // LAYOUT CONSTANTS
  // ============================================================================

  /// Quick actions grid cross axis count
  static const int quickActionsGridCrossAxisCount = 2;

  /// Quick actions grid child aspect ratio
  static const double quickActionsGridAspectRatio = 1.5;

  /// Recent analyses maksimum gösterilecek sayı
  static const int maxRecentAnalysesCount = 3;

  /// Card border radius oranı
  static const double cardBorderRadiusRatio = 0.8;

  /// Quick action card elevation
  static const double quickActionCardElevation = 4.0;

  /// Analysis card elevation
  static const double analysisCardElevation = 2.0;

  // ============================================================================
  // NAVIGATION CONSTANTS
  // ============================================================================

  /// Analysis tab index
  static const int analysisTabIndex = 1;

  /// Profile tab index
  static const int profileTabIndex = 2;

  /// Home tab index
  static const int homeTabIndex = 0;

  // ============================================================================
  // REFRESH CONSTANTS
  // ============================================================================

  /// Pull to refresh trigger distance
  static const double refreshTriggerDistance = 120.0;

  /// Refresh completion delay
  static const Duration refreshCompletionDelay = Duration(milliseconds: 500);

  // ============================================================================
  // ERROR CONSTANTS
  // ============================================================================

  /// Max retry attempts for data loading
  static const int maxRetryAttempts = 3;

  /// Retry delay between attempts
  static const Duration retryDelay = Duration(seconds: 2);

  // ============================================================================
  // TEXT CONSTANTS
  // ============================================================================

  /// Header letter spacing
  static const double headerLetterSpacing = -0.5;

  /// Title letter spacing
  static const double titleLetterSpacing = -0.3;

  /// Welcome text letter spacing
  static const double welcomeTextLetterSpacing = 0.2;
}
