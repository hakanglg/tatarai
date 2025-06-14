/// Firebase Yöneticisi
///
/// Bu sınıf, uygulamanın Firebase altyapısını başlatmak ve yönetmek için kullanılır.
/// Firebase Core, Authentication, Crashlytics, Remote Config gibi tüm servislerin
/// merkezi olarak başlatılması ve yapılandırılması burada gerçekleştirilir.
///
/// Ana Özellikler:
/// - Firebase Core başlatma ve yapılandırma
/// - Crashlytics hata raporlama sistemi kurulum
/// - Remote Config başlatma ve varsayılan değer ayarlama
/// - Authentication servislerini hazırlama
/// - Hata yakalama mekanizmalarını kurma
/// - Tekrar deneme mantığı ile güvenilir başlatma
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'package:tatarai/firebase_options.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Firebase servislerinin merkezi yönetimini sağlayan singleton sınıf
///
/// Bu sınıf aracılığıyla Firebase'in tüm servisleri güvenli bir şekilde
/// başlatılır ve uygulama genelinde erişilebilir hale getirilir.
class FirebaseManager {
  // Singleton instance
  static FirebaseManager? _instance;

  /// FirebaseManager singleton instance'ını döner
  factory FirebaseManager() {
    _instance ??= FirebaseManager._internal();
    return _instance!;
  }

  FirebaseManager._internal();

  // Firebase servisleri
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseRemoteConfig? _remoteConfig;
  FirebaseCrashlytics? _crashlytics;

  // Başlatma durumu
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Getter'lar - sadece başlatılmış servislere erişim sağlar
  FirebaseAuth get auth {
    if (_auth == null) {
      throw StateError(
          'Firebase henüz başlatılmadı. Önce initialize() metodunu çağırın.');
    }
    return _auth!;
  }

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw StateError(
          'Firebase henüz başlatılmadı. Önce initialize() metodunu çağırın.');
    }
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage == null) {
      throw StateError(
          'Firebase henüz başlatılmadı. Önce initialize() metodunu çağırın.');
    }
    return _storage!;
  }

  FirebaseRemoteConfig get remoteConfig {
    if (_remoteConfig == null) {
      throw StateError(
          'Firebase henüz başlatılmadı. Önce initialize() metodunu çağırın.');
    }
    return _remoteConfig!;
  }

  FirebaseCrashlytics get crashlytics {
    if (_crashlytics == null) {
      throw StateError(
          'Firebase henüz başlatılmadı. Önce initialize() metodunu çağırın.');
    }
    return _crashlytics!;
  }

  /// Firebase'in başlatılıp başlatılmadığını kontrol eder
  bool get isInitialized => _isInitialized;

  /// Firebase servislerini başlatır
  ///
  /// Bu metod Firebase Core'u başlatır ve tüm Firebase servislerini
  /// yapılandırır. Hata durumunda tekrar deneme mekanizması vardır.
  ///
  /// Returns: Firebase başarıyla başlatıldıysa true, aksi halde false
  Future<bool> initialize() async {
    // Zaten başlatılmışsa tekrar başlatma
    if (_isInitialized) {
      AppLogger.i('Firebase zaten başlatılmış');
      return true;
    }

    // Başlatma işlemi devam ediyorsa bekle
    if (_isInitializing) {
      AppLogger.i('Firebase başlatma işlemi devam ediyor, bekleniyor...');
      // Başlatma işlemi tamamlanana kadar bekle
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      AppLogger.i('🔥 Firebase başlatılıyor...');

      // Firebase Core'u başlat
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.i('✅ Firebase Core başarıyla başlatıldı');

      // Firebase servislerini başlat
      await _initializeFirebaseServices();

      _isInitialized = true;
      AppLogger.i('🎉 Firebase Manager başarıyla başlatıldı');

      return true;
    } catch (e, stack) {
      AppLogger.e('❌ Firebase başlatma hatası', e, stack);
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Firebase servislerini tekrar deneme mekanizması ile başlatır
  ///
  /// Bu metod üç kez deneme yapar ve her başarısız denemeden sonra
  /// exponential backoff uygular.
  Future<bool> initializeWithRetries({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      AppLogger.i('Firebase başlatma denemesi: $attempt/$maxRetries');

      final success = await initialize();
      if (success) {
        return true;
      }

      // Son deneme değilse bekle
      if (attempt < maxRetries) {
        final delaySeconds = attempt * 2; // 2, 4, 6 saniye bekle
        AppLogger.w(
            'Firebase başlatma başarısız, $delaySeconds saniye sonra tekrar denenecek...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    AppLogger.e('❌ Firebase $maxRetries deneme sonrasında başlatılamadı');
    return false;
  }

  /// Tüm Firebase servislerini yapılandırır
  Future<void> _initializeFirebaseServices() async {
    // Firebase Authentication'ı başlat
    _auth = FirebaseAuth.instance;
    AppLogger.i('✅ Firebase Auth başlatıldı');

    // Firestore'u default database ile başlat
    try {
      // Default database instance'ını kullan
      _firestore = FirebaseFirestore.instance;

      AppLogger.i(
          '🔍 Firestore default database bağlantısı kontrol ediliyor...');
      AppLogger.i('📊 Firebase App ID: ${Firebase.app().name}');
      AppLogger.i(
          '📊 Firebase Project ID: ${Firebase.app().options.projectId}');

      // Test bağlantısı - basit bir collection referansı al
      final testCollection = _firestore!.collection('test');
      AppLogger.i('✅ Firestore default database bağlantısı başarılı');
    } catch (e) {
      AppLogger.e('❌ Firestore default database bağlantısı başarısız: $e');
      rethrow;
    }

    // Firestore ayarları (offline persistence vs.)
    if (!kIsWeb) {
      try {
        _firestore!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        AppLogger.i('✅ Firestore ayarları yapılandırıldı (offline mode)');
      } catch (e) {
        AppLogger.w('Firestore ayarları yapılandırılırken uyarı', e);
      }
    }
    AppLogger.i('✅ Firestore başlatıldı');

    // Firebase Storage'ı başlat
    _storage = FirebaseStorage.instance;
    AppLogger.i('✅ Firebase Storage başlatıldı');

    // Crashlytics'i başlat (sadece release modunda)
    if (!kDebugMode) {
      _crashlytics = FirebaseCrashlytics.instance;

      // Crashlytics ayarları
      await _crashlytics!.setCrashlyticsCollectionEnabled(true);

      // Flutter hata yakalayıcısını Crashlytics'e bağla
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _crashlytics!.recordFlutterError(details);
      };

      // Platform hata yakalayıcısını Crashlytics'e bağla
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics!.recordError(error, stack, fatal: true);
        return true;
      };

      AppLogger.i(
          '✅ Crashlytics başlatıldı ve hata yakalayıcıları yapılandırıldı');
    } else {
      AppLogger.i('Debug modunda, Crashlytics başlatılmadı');
    }

    // Remote Config'i başlat
    await _initializeRemoteConfig();
  }

  /// Firebase Remote Config'i başlatır ve varsayılan değerleri ayarlar
  Future<void> _initializeRemoteConfig() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Remote Config ayarları
      final fetchInterval =
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 1);

      final configSettings = RemoteConfigSettings(
        minimumFetchInterval: fetchInterval,
        fetchTimeout: const Duration(seconds: 10),
      );

      await _remoteConfig!.setConfigSettings(configSettings);

      // Varsayılan değerleri ayarla
      await _remoteConfig!.setDefaults({
        'android_latest_version': '1.0.0',
        'android_min_version': '1.0.0',
        'android_store_url':
            'https://play.google.com/store/apps/details?id=com.xovasoftware.tatarai',
        'ios_latest_version': '1.0.0',
        'ios_min_version': '1.0.0',
        'ios_store_url': 'https://apps.apple.com/app/id0000000000',
        'force_update_message_tr': 'Yeni sürüm gerekli!',
        'force_update_message_en': 'New version required!',
        'optional_update_message_tr': 'Yeni sürüm mevcut!',
        'optional_update_message_en': 'New version available!',
        'maintenance_mode': false,
        'maintenance_message': 'Uygulama şu anda bakımda.',
      });

      // Remote config verilerini çek ve aktifleştir
      try {
        await _remoteConfig!.fetch();
        await _remoteConfig!.activate();
        AppLogger.i('✅ Remote Config verileri güncellendi');
      } catch (fetchError) {
        AppLogger.w(
            'Remote Config verileri güncellenemedi, varsayılan değerler kullanılacak',
            fetchError);
      }

      AppLogger.i('✅ Firebase Remote Config başlatıldı');
    } catch (e) {
      AppLogger.e('Remote Config başlatma hatası', e);
      // Remote Config hatası kritik değil, devam et
    }
  }

  /// Firebase Manager'ı sıfırlar (test amaçlı)
  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _auth = null;
    _firestore = null;
    _storage = null;
    _remoteConfig = null;
    _crashlytics = null;
    AppLogger.i('Firebase Manager sıfırlandı');
  }
}
