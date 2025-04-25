import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Tüm repository'ler için temel soyut sınıf
/// Bu sınıf, tüm repository'lerin ortak davranışlarını tanımlar
abstract class BaseRepository extends BaseService {
  /// Default constructor
  BaseRepository();

  /// Genel hata yönetimi
  @override
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.e('$runtimeType - $operation hatası: $error', error, stackTrace);
    throw Exception('İşlem sırasında bir hata oluştu: $operation');
  }

  /// Başarılı işlemleri loglama
  @override
  void logSuccess(String operation, [String? details]) {
    AppLogger.i(
      '$runtimeType - $operation başarılı${details != null ? ': $details' : ''}',
    );
  }

  /// Uyarıları loglama
  @override
  void logWarning(String operation, [String? details]) {
    AppLogger.w(
      '$runtimeType - $operation uyarısı${details != null ? ': $details' : ''}',
    );
  }

  /// Debug bilgisi loglama
  @override
  void logDebug(String operation, [String? details]) {
    AppLogger.d(
      '$runtimeType - $operation${details != null ? ': $details' : ''}',
    );
  }

  /// İnternet bağlantısını kontrol eder
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      logError('Bağlantı kontrolü yapılırken hata oluştu', e.toString());
      return false;
    }
  }

  /// API çağrısı yapar ve sonucu döndürür
  /// [apiCall] fonksiyonu verilmelidir
  /// [T] dönüş tipi
  Future<T?> apiCall<T>({
    required String operationName,
    required Future<T> Function() apiCall,
  }) async {
    try {
      final hasConnection = await checkConnectivity();
      if (!hasConnection) {
        logWarning('İnternet bağlantısı yok', 'İşlem: $operationName');
        return null;
      }

      final result = await apiCall();
      logSuccess('API çağrısı başarılı', 'İşlem: $operationName');
      return result;
    } catch (e) {
      handleError('API çağrısı ($operationName)', e);
      return null;
    }
  }

  /// Depolama işlemi yapar ve sonucu döndürür
  /// [storageCall] fonksiyonu verilmelidir
  /// [T] dönüş tipi
  Future<T?> storageCall<T>({
    required String operationName,
    required Future<T> Function() storageCall,
  }) async {
    try {
      final result = await storageCall();
      logSuccess('Depolama işlemi başarılı', 'İşlem: $operationName');
      return result;
    } catch (e) {
      handleError('Depolama işlemi ($operationName)', e);
      return null;
    }
  }
}

/// Önbellekleme yetenekleri için mixin
/// Repository'ler bu mixin'i kullanarak önbellekleme işlevlerini elde edebilir
mixin CacheableMixin {
  /// Verileri önbellekleme
  Future<void> cacheData(String key, dynamic data);

  /// Önbellekten veri alma
  Future<dynamic> getCachedData(String key);

  /// Önbellekten veriyi silme
  Future<void> removeCachedData(String key);

  /// Tüm önbelleği temizleme
  Future<void> clearCache();
}
