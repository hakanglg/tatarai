import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_manager.dart';
import 'firestore/firestore_service_interface.dart';
import 'firestore/firestore_service.dart';
import '../repositories/auth_repository.dart';
import '../../features/plant_analysis/services/gemini_service.dart';
import '../../features/plant_analysis/services/location_service.dart';
import '../../features/payment/cubits/payment_cubit.dart';
import '../../features/home/cubits/home_cubit.dart';
import '../utils/logger.dart';

/// Dependency injection için service locator
///
/// Tüm servislerin tek bir yerden yönetilmesini sağlar.
/// Clean Architecture prensiplerine uygun olarak interface'leri
/// concrete implementation'larla eşler.
///
/// Özellikler:
/// - GetIt tabanlı dependency injection
/// - Singleton pattern
/// - Interface-based dependency injection
/// - Lazy initialization
/// - Test environment desteği
/// - Service lifecycle yönetimi
class ServiceLocator {
  /// GetIt instance
  static final GetIt _getIt = GetIt.instance;

  /// Service locator başlatılmış mı?
  static bool _isInitialized = false;

  /// GetIt instance'ını döner
  static GetIt get locator => _getIt;

  /// Servisleri kayıt eder
  ///
  /// Bu method uygulama başlangıcında çağrılmalıdır.
  /// Tüm dependency'leri burada tanımlarız.
  static Future<void> setup() async {
    if (_isInitialized) {
      AppLogger.logWithContext(
          'ServiceLocator', 'ServiceLocator zaten başlatılmış');
      return;
    }

    AppLogger.logWithContext(
        'ServiceLocator', 'ServiceLocator başlatılıyor...');

    try {
      // Core Services
      await _registerCoreServices();

      // Feature Services
      await _registerFeatureServices();

      _isInitialized = true;
      AppLogger.successWithContext(
          'ServiceLocator', 'ServiceLocator başarıyla başlatıldı');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'ServiceLocator', 'ServiceLocator başlatma hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Core servisleri kayıt eder
  static Future<void> _registerCoreServices() async {
    // Firebase Services (External dependencies)
    _getIt.registerLazySingleton<FirebaseAuth>(
      () => FirebaseAuth.instance,
    );

    _getIt.registerLazySingleton<FirebaseFirestore>(
      () {
        // FirebaseManager'dan Firestore instance'ını al
        try {
          final firebaseManager = FirebaseManager();
          if (firebaseManager.isInitialized) {
            AppLogger.logWithContext('ServiceLocator',
                'FirebaseManager\'dan Firestore instance alınıyor');
            return firebaseManager.firestore;
          }
        } catch (e) {
          AppLogger.warnWithContext(
              'ServiceLocator', 'FirebaseManager\'dan Firestore alınamadı: $e');
        }

        // Fallback: Default instance
        AppLogger.logWithContext('ServiceLocator',
            'Fallback: Default Firestore instance kullanılıyor');
        return FirebaseFirestore.instance;
      },
    );

    _getIt.registerLazySingleton<FirebaseStorage>(
      () => FirebaseStorage.instance,
    );

    // Firestore Service
    _getIt.registerLazySingleton<FirestoreServiceInterface>(
      () => FirestoreService(),
    );

    // Location Service
    _getIt.registerLazySingleton<LocationService>(
      () => LocationService(),
    );

    // Gemini Service
    _getIt.registerLazySingleton<GeminiService>(
      () => GeminiService(),
    );

    AppLogger.logWithContext('ServiceLocator', 'Core servisler kayıt edildi');
  }

  /// Feature servisleri kayıt eder
  static Future<void> _registerFeatureServices() async {
    // Auth Repository
    _getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepository(
        firebaseAuth: _getIt<FirebaseAuth>(),
        firestoreService: _getIt<FirestoreServiceInterface>(),
      ),
    );

    // Payment Cubit
    _getIt.registerFactory<PaymentCubit>(
      () => PaymentCubit(),
    );

    // Home Cubit
    _getIt.registerFactory<HomeCubit>(
      () => HomeCubit(),
    );

    AppLogger.logWithContext(
        'ServiceLocator', 'Feature servisler kayıt edildi');
  }

  /// Test environment için setup
  ///
  /// Unit testlerde mock'lar kullanılabilir
  static Future<void> setupForTest({
    FirestoreServiceInterface? mockFirestoreService,
  }) async {
    // Test için tüm servisleri temizle
    await reset();

    // Mock servisler kayıt et
    if (mockFirestoreService != null) {
      _getIt.registerSingleton<FirestoreServiceInterface>(mockFirestoreService);
    }
  }

  /// Tüm servisleri temizler
  ///
  /// Test sonrası veya uygulama kapanırken kullanılır
  static Future<void> reset() async {
    await _getIt.reset();
  }

  /// Belirli bir servisi temizler
  ///
  /// [T] - Temizlenecek servis tipi
  static void unregister<T extends Object>() {
    if (_getIt.isRegistered<T>()) {
      _getIt.unregister<T>();
    }
  }

  /// Servisin kayıtlı olup olmadığını kontrol eder
  ///
  /// [T] - Kontrol edilecek servis tipi
  /// Returns: Servis kayıtlı mı?
  static bool isRegistered<T extends Object>() {
    return _getIt.isRegistered<T>();
  }

  /// Servisi alır
  ///
  /// [T] - Alınacak servis tipi
  /// Returns: Servis instance
  static T get<T extends Object>() {
    return _getIt.get<T>();
  }

  /// Servisi asenkron olarak alır
  ///
  /// [T] - Alınacak servis tipi
  /// Returns: Future<Servis instance>
  static Future<T> getAsync<T extends Object>() {
    return _getIt.getAsync<T>();
  }

  /// Servisi parametre ile alır
  ///
  /// [T] - Alınacak servis tipi
  /// [param1] - İlk parametre
  /// [param2] - İkinci parametre
  /// Returns: Servis instance
  static T getWithParam<T extends Object, P1, P2>(
    P1 param1, [
    P2? param2,
  ]) {
    return _getIt.get<T>(param1: param1, param2: param2);
  }

  /// Servis durumunu loglar
  ///
  /// Debug amaçlı tüm kayıtlı servisleri listeler
  static void logServiceStatus() {
    AppLogger.logWithContext(
        'ServiceLocator', '=== Service Locator Status ===');
    AppLogger.logWithContext(
        'ServiceLocator', 'İnitialize durumu: $_isInitialized');

    if (_getIt.isRegistered<FirestoreServiceInterface>()) {
      AppLogger.logWithContext(
          'ServiceLocator', '✓ FirestoreServiceInterface kayıtlı');
    } else {
      AppLogger.warnWithContext(
          'ServiceLocator', '✗ FirestoreServiceInterface kayıtlı DEĞİL');
    }

    if (_getIt.isRegistered<AuthRepository>()) {
      AppLogger.logWithContext('ServiceLocator', '✓ AuthRepository kayıtlı');
    } else {
      AppLogger.warnWithContext(
          'ServiceLocator', '✗ AuthRepository kayıtlı DEĞİL');
    }

    if (_getIt.isRegistered<FirebaseAuth>()) {
      AppLogger.logWithContext('ServiceLocator', '✓ FirebaseAuth kayıtlı');
    } else {
      AppLogger.warnWithContext(
          'ServiceLocator', '✗ FirebaseAuth kayıtlı DEĞİL');
    }

    AppLogger.logWithContext(
        'ServiceLocator', '===============================');
  }
}

/// Service locator helper extensions
///
/// Daha kısa syntax için extension methodlar
extension ServiceLocatorExtensions on Object {
  /// Servisi alır (extension method)
  T getService<T extends Object>() {
    return ServiceLocator.get<T>();
  }
}

/// Global service getter'lar
///
/// Hızlı erişim için global metodlar
class Services {
  /// Firestore service'ini döner
  static FirestoreServiceInterface get firestore =>
      ServiceLocator.get<FirestoreServiceInterface>();

  /// Auth repository'yi döner
  static AuthRepository get authRepository =>
      ServiceLocator.get<AuthRepository>();

  /// Firebase Auth'u döner
  static FirebaseAuth get firebaseAuth => ServiceLocator.get<FirebaseAuth>();

  /// Firebase Firestore'u döner
  static FirebaseFirestore get firebaseFirestore =>
      ServiceLocator.get<FirebaseFirestore>();

  /// Firebase Storage'ı döner
  static FirebaseStorage get firebaseStorage =>
      ServiceLocator.get<FirebaseStorage>();

  /// Location service'ini döner
  static LocationService get locationService =>
      ServiceLocator.get<LocationService>();

  /// Gemini service'ini döner
  static GeminiService get geminiService => ServiceLocator.get<GeminiService>();

  /// Payment cubit'ini döner (Factory)
  static PaymentCubit get paymentCubit => ServiceLocator.get<PaymentCubit>();

  /// Home cubit'ini döner (Factory)
  static HomeCubit get homeCubit => ServiceLocator.get<HomeCubit>();
}

/// Service locator mixin
///
/// Widget'lara veya class'lara mixin olarak eklenebilir
mixin ServiceLocatorMixin {
  /// Servisi alır
  T getService<T extends Object>() {
    return ServiceLocator.get<T>();
  }

  /// Firestore service
  FirestoreServiceInterface get firestoreService =>
      getService<FirestoreServiceInterface>();

  /// Auth repository
  AuthRepository get authRepository => getService<AuthRepository>();

  /// Firebase Auth
  FirebaseAuth get firebaseAuth => getService<FirebaseAuth>();

  /// Firebase Firestore
  FirebaseFirestore get firebaseFirestore => getService<FirebaseFirestore>();

  /// Firebase Storage
  FirebaseStorage get firebaseStorage => getService<FirebaseStorage>();

  /// Location service
  LocationService get locationService => getService<LocationService>();

  /// Gemini service
  GeminiService get geminiService => getService<GeminiService>();
}
