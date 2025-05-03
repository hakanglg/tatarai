import 'package:logger/logger.dart';

/// Uygulamanın merkezi loglama servisi
/// Tüm uygulama bileşenleri için tutarlı loglama sağlar
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.verbose,
    output: ConsoleOutput(),
  );

  /// Verbose seviyesinde log
  /// Detaylı geliştirme bilgileri için
  static void v(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  /// Debug seviyesinde log
  /// Geliştirme sürecinde yardımcı olacak bilgiler için
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info seviyesinde log
  /// Bilgilendirme amaçlı mesajlar için
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning seviyesinde log
  /// Potansiyel tehlike oluşturabilecek durumlar için
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error seviyesinde log
  /// Hata durumları için
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal seviyesinde log
  /// Kritik hatalar için
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Başarı mesajı için özel log
  /// Başarılı işlemler için özel emoji ile log
  static void success(String message, [dynamic details]) {
    _logger.i('✅ $message${details != null ? ' - $details' : ''}');
  }

  /// Sınıf bağlamı ile loglama (Cubit/Service için)
  /// @param context - Sınıf adı veya bağlam (örn: 'AuthCubit', 'PlantAnalysisService')
  /// @param message - Log mesajı
  /// @param details - Ek detaylar (opsiyonel)
  /// @param error - Hata nesnesi (opsiyonel)
  /// @param stackTrace - Yığın izi (opsiyonel)
  static void logWithContext(String context, String message,
      [dynamic details, dynamic error, StackTrace? stackTrace]) {
    final formattedMessage =
        '[$context] $message${details != null ? ' - $details' : ''}';
    if (error != null) {
      _logger.i(formattedMessage, error: error, stackTrace: stackTrace);
    } else {
      _logger.i(formattedMessage);
    }
  }

  /// Uyarı mesajını bağlam ile logla
  static void warnWithContext(String context, String message,
      [dynamic details]) {
    final formattedMessage =
        '[$context] ⚠️ $message${details != null ? ' - $details' : ''}';
    _logger.w(formattedMessage);
  }

  /// Hata mesajını bağlam ile logla
  static void errorWithContext(String context, String operation,
      [dynamic error, StackTrace? stackTrace]) {
    final formattedMessage = '[$context] ❌ $operation hatası';
    _logger.e(formattedMessage, error: error, stackTrace: stackTrace);
  }

  /// Başarı mesajını bağlam ile logla
  static void successWithContext(String context, String message,
      [dynamic details]) {
    final formattedMessage =
        '[$context] ✅ $message${details != null ? ' - $details' : ''}';
    _logger.i(formattedMessage);
  }

  /// Debug mesajını bağlam ile logla
  static void debugWithContext(String context, String message,
      [dynamic details]) {
    final formattedMessage =
        '[$context] 🔍 $message${details != null ? ' - $details' : ''}';
    _logger.d(formattedMessage);
  }

  /// Verbose mesajını bağlam ile logla
  static void verboseWithContext(String context, String message,
      [dynamic details]) {
    final formattedMessage =
        '[$context] 📝 $message${details != null ? ' - $details' : ''}';
    _logger.v(formattedMessage);
  }

  /// İşlem başlangıcı loglama
  static void startOperation(String context, String operation,
      [dynamic details]) {
    final formattedMessage =
        '[$context] 🚀 $operation başlatılıyor${details != null ? ' - $details' : ''}';
    _logger.i(formattedMessage);
  }

  /// İşlem bitişi loglama
  static void endOperation(String context, String operation,
      [dynamic details]) {
    final formattedMessage =
        '[$context] 🏁 $operation tamamlandı${details != null ? ' - $details' : ''}';
    _logger.i(formattedMessage);
  }

  /// Basit print yerine kullanılacak log
  /// Print görüldüğünde logger ile değiştirilmeli
  static void log(String message) {
    _logger.i('LOG: $message');
  }
}
