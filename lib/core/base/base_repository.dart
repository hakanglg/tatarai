import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/utils/error_handler.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/utils/network_util.dart';
import 'package:tatarai/core/services/firebase_manager.dart';

/// Tüm repository'ler için temel soyut sınıf
/// Bu sınıf, tüm repository'lerin ortak davranışlarını tanımlar
abstract class BaseRepository extends BaseService {
  /// Default constructor
  BaseRepository();

  /// Network utility instance
  final NetworkUtil _networkUtil = NetworkUtil();

  /// Genel hata yönetimi
  @override
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    final errorMessage = ErrorHandler.handleGeneralError(error);
    AppLogger.e(
        '$runtimeType - $operation hatası: $errorMessage', error, stackTrace);
    throw Exception(
        'İşlem sırasında bir hata oluştu: $operation - $errorMessage');
  }

  /// Firebase hata yönetimi (kullanıcı dostu mesaj için)
  String getFirebaseErrorMessage(dynamic error) {
    return ErrorHandler.handleGeneralError(error);
  }

  /// Firestore hatası mı kontrol et
  bool isFirestoreError(dynamic error) {
    return error.toString().contains('cloud_firestore') ||
        error.toString().contains('PERMISSION_DENIED') ||
        error.toString().contains('permission-denied');
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
    return _networkUtil.checkConnectivity();
  }

  /// API çağrısı yapar ve sonucu döndürür
  /// [apiCall] fonksiyonu verilmelidir
  /// [T] dönüş tipi
  Future<T?> apiCall<T>({
    required String operationName,
    required Future<T> Function() apiCall,
    bool throwError = false,
    bool ignoreConnectionCheck = false,
  }) async {
    try {
      // Bağlantı kontrolü yapılacaksa
      if (!ignoreConnectionCheck) {
        final hasConnection = await checkConnectivity();
        if (!hasConnection) {
          logWarning('İnternet bağlantısı yok', 'İşlem: $operationName');

          if (throwError) {
            throw Exception(
                'İnternet bağlantısı yok, işlem yapılamıyor: $operationName');
          }
          return null;
        }

        // Firebase bağlantı durumunu kontrol et
        final firebaseManager = FirebaseManager();

        // Önce Firebase Manager'ın başlatılmış olup olmadığını kontrol et
        if (!firebaseManager.isInitialized) {
          logWarning('Firebase henüz başlatılmamış', 'İşlem: $operationName');

          try {
            await firebaseManager.initialize();
          } catch (e) {
            logError('Firebase başlatılamadı', 'İşlem: $operationName - $e');
            if (throwError) {
              throw Exception('Firebase başlatılamadı: $e');
            }
            return null;
          }
        }

        // Firebase bağlantı durumunu kontrol et
        if (!firebaseManager.isConnected) {
          logWarning('Firebase bağlantısı yok', 'İşlem: $operationName');

          // Firebase bağlantısını tekrar kurmaya çalış
          try {
            await Future.delayed(const Duration(seconds: 1));

            // Hala bağlantı yoksa
            if (!firebaseManager.isConnected) {
              logWarning(
                  'Firebase bağlantısı kurulamadı, önbellek verileri kullanılacak',
                  'İşlem: $operationName');
              if (throwError) {
                throw Exception(
                    'Firebase bağlantısı kurulamadı: $operationName');
              }
              // Bağlantı yoksa null döndür, cache veri varsa üst sınıflar kullanabilir
              return null;
            }
          } catch (fbError) {
            logError('Firebase bağlantısı kurulamadı',
                'İşlem: $operationName - $fbError');
            if (throwError) {
              throw Exception('Firebase bağlantısı kurulamadı: $fbError');
            }
            return null;
          }
        }
      }

      // Zamanlamayı takip etmek için
      final startTime = DateTime.now();

      // API çağrısını yap
      final result = await apiCall();

      // İşlem süresini hesapla
      final duration = DateTime.now().difference(startTime);

      logSuccess('API çağrısı başarılı',
          'İşlem: $operationName (${duration.inMilliseconds}ms)');

      return result;
    } catch (e, stackTrace) {
      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission-denied')) {
        logError('Firestore repository veri çekerken yetki hatası',
            'İşlem: $operationName - Yetkilendirme eksik veya yetersiz. Firebase güvenlik kurallarını kontrol edin.');
      } else if (e.toString().contains('unavailable') ||
          e.toString().contains('network')) {
        logError('Firestore repository veri çekerken ağ hatası',
            'İşlem: $operationName - İnternet bağlantınızı kontrol edin.');
      } else if (e.toString().contains('not-found')) {
        logError('Firestore repository veri çekerken belge bulunamadı',
            'İşlem: $operationName - İstenilen belge bulunamadı.');
      } else if (e.toString().contains('cloud_firestore/unavailable')) {
        logError(
            'Firestore repository veri çekerken servis kullanılamaz hatası',
            'İşlem: $operationName - Servis geçici olarak kullanılamaz, lütfen biraz sonra tekrar deneyin.');
      } else {
        handleError('API çağrısı ($operationName)', e, stackTrace);
      }

      if (throwError) rethrow;
      return null;
    }
  }

  /// Depolama işlemi yapar ve sonucu döndürür
  /// [storageCall] fonksiyonu verilmelidir
  /// [T] dönüş tipi
  Future<T?> storageCall<T>({
    required String operationName,
    required Future<T> Function() storageCall,
    bool throwError = false,
    bool ignoreConnectionCheck = false,
  }) async {
    try {
      // Bağlantı kontrolü yapılacaksa
      if (!ignoreConnectionCheck) {
        final hasConnection = await checkConnectivity();
        if (!hasConnection) {
          logWarning('İnternet bağlantısı yok', 'İşlem: $operationName');

          if (throwError) {
            throw Exception(
                'İnternet bağlantısı yok, işlem yapılamıyor: $operationName');
          }
          return null;
        }
      }

      // Zamanlamayı takip etmek için
      final startTime = DateTime.now();

      // Storage çağrısını yap
      final result = await storageCall();

      // İşlem süresini hesapla
      final duration = DateTime.now().difference(startTime);

      logSuccess('Depolama işlemi başarılı',
          'İşlem: $operationName (${duration.inMilliseconds}ms)');

      return result;
    } catch (e, stackTrace) {
      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission-denied')) {
        logError('Firebase Storage işleminde yetki hatası',
            'İşlem: $operationName - Yetkilendirme eksik veya yetersiz. Firebase güvenlik kurallarını kontrol edin.');
      } else {
        handleError('Depolama işlemi ($operationName)', e, stackTrace);
      }

      if (throwError) rethrow;
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
