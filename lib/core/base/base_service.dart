import 'package:tatarai/core/utils/logger.dart';

/// Tüm servislerin temel sınıfı.
/// Loglama ve hata yönetimi için ortak metotlar içerir.
abstract class BaseService {
  /// Servis sınıfının adını döndüren getter
  String get _serviceName => runtimeType.toString();

  /// Bilgi seviyesinde log mesajı
  void logInfo(String title, [String? message]) {
    AppLogger.logWithContext(_serviceName, title, message);
  }

  /// Başarı seviyesinde log mesajı
  void logSuccess(String title, [String? message]) {
    AppLogger.successWithContext(_serviceName, title, message);
  }

  /// Uyarı seviyesinde log mesajı
  void logWarning(String title, [String? message]) {
    AppLogger.warnWithContext(_serviceName, title, message);
  }

  /// Hata seviyesinde log mesajı
  void logError(String title, [String? message]) {
    AppLogger.errorWithContext(_serviceName, title, message);
  }

  /// Debug seviyesinde log mesajı
  void logDebug(String title, [String? message]) {
    AppLogger.d(
        '[$_serviceName] 🔍 $title${message != null ? ' - $message' : ''}');
  }

  /// Ayrıntılı log mesajı
  void logVerbose(String title, [String? message]) {
    AppLogger.v(
        '[$_serviceName] 📝 $title${message != null ? ' - $message' : ''}');
  }

  /// İşlem başlangıcını logla
  void logStart(String operation, [String? details]) {
    AppLogger.i(
        '[$_serviceName] 🚀 $operation başlatılıyor${details != null ? ' - $details' : ''}');
  }

  /// İşlem bitişini logla
  void logEnd(String operation, [String? details]) {
    AppLogger.i(
        '[$_serviceName] 🏁 $operation tamamlandı${details != null ? ' - $details' : ''}');
  }

  /// Standart hata işleme metodu
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.errorWithContext(_serviceName, operation, error, stackTrace);
  }
}
