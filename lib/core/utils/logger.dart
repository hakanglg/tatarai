import 'package:logger/logger.dart';

/// Uygulamanın loglama servisi
/// Hata ayıklama ve izleme için kullanılır
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

  /// Basit print yerine kullanılacak log
  /// Print görüldüğünde logger ile değiştirilmeli
  static void log(String message) {
    _logger.i('LOG: $message');
  }
}
