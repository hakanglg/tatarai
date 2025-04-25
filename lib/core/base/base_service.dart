import 'package:logger/logger.dart';

/// Tüm servislerin temel sınıfı.
/// Loglama ve hata yönetimi için ortak metotlar içerir.
abstract class BaseService {
  final Logger _logger = Logger();

  /// Bilgi seviyesinde log mesajı
  void logInfo(String title, [String? message]) {
    _logger.i('$title${message != null ? ' - $message' : ''}');
  }

  /// Başarı seviyesinde log mesajı
  void logSuccess(String title, [String? message]) {
    _logger.i('✅ $title${message != null ? ' - $message' : ''}');
  }

  /// Uyarı seviyesinde log mesajı
  void logWarning(String title, [String? message]) {
    _logger.w('⚠️ $title${message != null ? ' - $message' : ''}');
  }

  /// Hata seviyesinde log mesajı
  void logError(String title, [String? message]) {
    _logger.e('❌ $title${message != null ? ' - $message' : ''}');
  }

  /// Debug seviyesinde log mesajı
  void logDebug(String title, [String? message]) {
    _logger.d('🔍 $title${message != null ? ' - $message' : ''}');
  }

  /// Ayrıntılı log mesajı
  void logVerbose(String title, [String? message]) {
    _logger.v('📝 $title${message != null ? ' - $message' : ''}');
  }

  /// Standart hata işleme metodu
  void handleError(String operation, dynamic error) {
    if (error is Exception || error is Error) {
      logError('$operation hatası', error.toString());
    } else {
      logError('$operation hatası', error?.toString() ?? 'Bilinmeyen hata');
    }
  }
}
