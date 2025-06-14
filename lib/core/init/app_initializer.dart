import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/core/services/remote_config_service.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/utils/network_util.dart';

/// TatarAI uygulamasının başlatma sürecini yöneten Initializer class'ı
///
/// Bu class, uygulamanın ihtiyaç duyduğu tüm core servislerin
/// başlatılmasından sorumludur. Clean Architecture prensiplerine
/// uygun olarak, main.dart'dan initialize sorumluluklarını ayırır.
///
/// Singleton pattern kullanarak tek instance garantisi sağlar.
class AppInitializer {
  AppInitializer._();

  /// Singleton instance
  static final AppInitializer _instance = AppInitializer._();

  /// AppInitializer instance'ına erişim
  static AppInitializer get instance => _instance;

  /// Initialization durumları
  bool _isInitialized = false;
  String? _lastError;

  /// Initialization tamamlandı mı?
  bool get isInitialized => _isInitialized;

  /// Son initialization hatası
  String? get lastError => _lastError;

  /// Uygulamanın tüm core servislerini başlatır
  ///
  /// [forceReinitialize] - Daha önce başlatılmış olsa bile yeniden başlat
  ///
  /// Returns: Başlatma başarılı olursa true
  Future<bool> initializeApplication({bool forceReinitialize = false}) async {
    // Duplicate initialization'ı önle
    if (_isInitialized && !forceReinitialize) {
      AppLogger.i('✅ Application zaten başlatılmış, atlanıyor');
      return true;
    }

    try {
      AppLogger.i('🚀 AppInitializer başlatılıyor...');
      _lastError = null;

      // 1. Environment variables
      await _loadEnvironmentVariables();

      // 2. Network monitoring
      _startNetworkMonitoring();

      // 3. Localization
      await _initializeLocalization();

      // 4. Firebase services
      final bool firebaseSuccess = await _initializeFirebase();

      // 5. Remote Config (Firebase'e bağımlı)
      if (firebaseSuccess) {
        await _initializeRemoteConfig();
      }

      // 6. RevenueCat
      await _initializeRevenueCat();

      // 7. Service Locator (Firebase'e bağımlı)
      if (firebaseSuccess) {
        await _initializeServiceLocator();
      }

      _isInitialized = true;
      AppLogger.i('🎉 AppInitializer başarıyla tamamlandı');
      return true;
    } catch (e, stackTrace) {
      _lastError = e.toString();
      _isInitialized = false;
      AppLogger.e('❌ AppInitializer hatası', e, stackTrace);
      return false;
    }
  }

  /// Sistem ayarlarını yapılandırır
  ///
  /// - Device orientation settings
  /// - System UI preferences
  Future<void> configureSystemSettings() async {
    try {
      AppLogger.i('🔧 Sistem ayarları yapılandırılıyor...');

      // Sadece portrait orientasyon
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      AppLogger.i('✅ Sistem ayarları yapılandırıldı');
    } catch (e) {
      AppLogger.e('❌ Sistem ayarları yapılandırılamadı', e);
    }
  }

  /// Debug ayarlarını yapılandırır
  ///
  /// - Debug paint settings
  /// - Custom debug print
  /// - Development-only configurations
  void configureDebugSettings() {
    if (!kDebugMode) return;

    try {
      AppLogger.i('🔧 Debug ayarları yapılandırılıyor...');

      // Debug paint ayarları
      debugPaintSizeEnabled = false;
      debugPaintBaselinesEnabled = false;
      debugPaintLayerBordersEnabled = false;
      debugPaintPointersEnabled = false;

      // Custom debug print
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          AppLogger.d(message);
        }
      };

      AppLogger.i('✅ Debug ayarları yapılandırıldı');
    } catch (e) {
      AppLogger.e('❌ Debug ayarları yapılandırılamadı', e);
    }
  }

  /// Global hata işleme
  ///
  /// Yakalanmamış hataları işler ve Crashlytics'e rapor eder
  void handleGlobalError(dynamic error, StackTrace stackTrace) {
    AppLogger.e('💥 Global hata yakalandı', error, stackTrace);

    try {
      final firebaseManager = FirebaseManager();
      if (firebaseManager.isInitialized) {
        firebaseManager.crashlytics.recordError(
          error,
          stackTrace,
          reason: 'Global uncaught error',
          fatal: true,
        );
      }
    } catch (e) {
      AppLogger.e('❌ Crashlytics hata bildirimi başarısız', e);
    }
  }

  /// Initialization durumunu sıfırlar
  ///
  /// Test ortamları için kullanılır
  void reset() {
    _isInitialized = false;
    _lastError = null;
    AppLogger.i('🔄 AppInitializer reset edildi');
  }

  /// Initialization durumu hakkında detaylı bilgi
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'lastError': _lastError,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================================
  // PRIVATE METHODS - Initialize İşlemleri
  // ============================================================================

  /// Environment variables (.env) yükleme
  Future<void> _loadEnvironmentVariables() async {
    try {
      await dotenv.load(fileName: ".env");
      AppLogger.i('✅ Environment variables yüklendi');
    } catch (e) {
      AppLogger.e('❌ Environment variables yüklenemedi', e);
      if (kDebugMode) {
        _showEnvironmentWarning();
      }
    }
  }

  /// Network connection monitoring başlatma
  void _startNetworkMonitoring() {
    try {
      NetworkUtil().startMonitoring();
      AppLogger.i('✅ Network monitoring başlatıldı');
    } catch (e) {
      AppLogger.e('❌ Network monitoring başlatılamadı', e);
    }
  }

  /// Lokalizasyon sistemi başlatma
  Future<void> _initializeLocalization() async {
    try {
      await LocalizationManager.init();
      AppLogger.i('✅ Localization başlatıldı');
    } catch (e) {
      AppLogger.e('❌ Localization başlatılamadı', e);
      rethrow;
    }
  }

  /// Firebase servislerini başlatma
  Future<bool> _initializeFirebase() async {
    try {
      final firebaseManager = FirebaseManager();
      final bool success = await firebaseManager.initializeWithRetries();

      if (success) {
        AppLogger.i('✅ Firebase başarıyla başlatıldı');
      } else {
        AppLogger.e('❌ Firebase başlatılamadı');
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Firebase başlatma hatası', e, stackTrace);
      return false;
    }
  }

  /// Remote Config servisini başlatma
  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfigService = RemoteConfigService();
      await remoteConfigService.initialize();
      AppLogger.i('✅ Remote Config başlatıldı');
    } catch (e) {
      AppLogger.e('❌ Remote Config başlatılamadı', e);
    }
  }

  /// RevenueCat ödeme sistemi başlatma
  Future<void> _initializeRevenueCat() async {
    try {
      AppLogger.i('🔧 RevenueCat başlatılıyor...');

      // Platform-specific API key
      String? apiKey;
      if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_IOS_API_KEY'];
      } else if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_API_KEY'];
      }

      if (apiKey == null || apiKey.isEmpty) {
        if (kDebugMode) {
          _showRevenueCatWarning(Platform.operatingSystem);
        }
        return;
      }

      // RevenueCat configuration
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(apiKey));

      // Firebase user sync
      await _syncRevenueCatWithFirebase();

      AppLogger.i('✅ RevenueCat başarıyla başlatıldı');
    } catch (e, stackTrace) {
      AppLogger.e('❌ RevenueCat başlatma hatası', e, stackTrace);
    }
  }

  /// Service Locator (Dependency Injection) başlatma
  Future<void> _initializeServiceLocator() async {
    try {
      await ServiceLocator.setup();
      ServiceLocator.logServiceStatus();
      AppLogger.i('✅ Service Locator başarıyla başlatıldı');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Service Locator başlatma hatası', e, stackTrace);
      rethrow;
    }
  }

  /// RevenueCat'i Firebase kullanıcısı ile senkronize et
  Future<void> _syncRevenueCatWithFirebase() async {
    try {
      final firebaseManager = FirebaseManager();
      if (!firebaseManager.isInitialized) return;

      final currentUser = firebaseManager.auth.currentUser;
      if (currentUser != null) {
        await Purchases.logIn(currentUser.uid);
        AppLogger.i(
            '✅ RevenueCat Firebase user sync tamamlandı: ${currentUser.uid}');
      } else {
        AppLogger.i('ℹ️ Firebase user yok, RevenueCat sync atlanıyor');
      }
    } catch (e) {
      AppLogger.w('⚠️ RevenueCat Firebase sync hatası', e);
    }
  }

  // ============================================================================
  // WARNING METHODS - Development Uyarı Mesajları
  // ============================================================================

  /// Environment variables eksik uyarısı
  void _showEnvironmentWarning() {
    AppLogger.w('=' * 60);
    AppLogger.w('⚠️ ENVIRONMENT VARIABLES UYARISI ⚠️');
    AppLogger.w('.env dosyası bulunamadı veya yüklenemedi!');
    AppLogger.w('Bazı özellikler düzgün çalışmayabilir.');
    AppLogger.w(
        'Lütfen .env dosyasını oluşturun ve gerekli anahtarları ekleyin.');
    AppLogger.w('=' * 60);
  }

  /// RevenueCat API key eksik uyarısı
  void _showRevenueCatWarning(String platform) {
    AppLogger.w('=' * 60);
    AppLogger.w('⚠️ REVENUECAT API KEY UYARISI ⚠️');
    AppLogger.w('$platform için RevenueCat API key bulunamadı!');
    AppLogger.w('Ödeme özellikleri çalışmayacak.');
    AppLogger.w('Lütfen .env dosyasına uygun API key\'i ekleyin.');
    AppLogger.w('=' * 60);
  }
}
