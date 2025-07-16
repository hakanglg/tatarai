import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/init/app_initializer.dart';
import 'package:tatarai/core/routing/route_paths.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/services/firestore/firestore_service.dart';
import 'package:tatarai/core/services/permission_service.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/splash/constants/splash_constants.dart';
import 'package:tatarai/features/update/views/force_update_screen.dart';

import '../../../core/init/app_initializer.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/semantic_version.dart';
import '../../../core/utils/version_util.dart';
import '../../auth/cubits/auth_cubit.dart';
import '../../auth/cubits/auth_state.dart';
import '../../navbar/navigation_manager.dart';
import '../constants/splash_constants.dart';

/// Splash screen business logic'ini yöneten service
///
/// Bu service, splash screen'de gerçekleşen tüm business operasyonları
/// yönetir. Clean Architecture prensiplerine uygun olarak UI'dan
/// ayrılmış business logic içerir.
///
/// Sorumluluklar:
/// - AppInitializer durum kontrolü
/// - Version checking ve update flow
/// - Authentication durumu kontrolü
/// - Navigation logic
/// - Onboarding kontrolü
class SplashService {
  SplashService._();

  /// Singleton instance
  static final SplashService _instance = SplashService._();
  static SplashService get instance => _instance;

  /// Navigation controller
  Timer? _timeoutTimer;
  bool _navigationStarted = false;

  /// AppInitializer hazır mı kontrol eder
  bool get isAppReady => AppInitializer.instance.isInitialized;

  /// Navigation başlatıldı mı kontrol eder
  bool get isNavigationStarted => _navigationStarted;

  /// Initialization timeout'unu başlatır
  void startInitializationTimeout({
    required VoidCallback onTimeout,
  }) {
    _timeoutTimer = Timer(SplashConstants.maxInitializationTimeout, () {
      AppLogger.w(
          '⏰ SplashService timeout - zorla ana sayfaya yönlendiriliyor');
      if (!_navigationStarted) {
        _navigationStarted = true;
        onTimeout();
      }
    });
  }

  /// Timeout'u iptal eder
  void cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Navigation'ı reset eder
  void resetNavigation() {
    _navigationStarted = false;
  }

  /// Versiyon kontrolü yapar ve uygun navigation'ı gerçekleştirir
  Future<SplashNavigationType> checkVersionAndGetNavigation({
    required String locale,
    required bool isAndroid,
  }) async {
    // Navigation zaten başlatıldıysa tekrar yapma
    if (_navigationStarted) {
      AppLogger.w('Navigation zaten başlatıldı, mevcut akışa devam ediliyor');
      return SplashNavigationType.continueFlow;
    }

    try {
      AppLogger.i('🔍 Versiyon kontrolü başlatılıyor...');

      // Debug mode test case kontrolü
      if (kDebugMode && SplashConstants.debugTestMode) {
        return _getDebugNavigationType();
      }

      // Package info al
      final packageInfo = await PackageInfo.fromPlatform();

      // Remote config'den update konfigürasyonunu al
      final config = RemoteConfigService().getUpdateConfig(
        isAndroid: isAndroid,
        locale: locale,
      );

      // Version karşılaştırması
      final currentVersion = SemanticVersion.fromString(packageInfo.version);
      final minVersion = SemanticVersion.fromString(config.minVersion);
      final latestVersion = SemanticVersion.fromString(config.latestVersion);

      final isForceRequired = VersionUtil.isForceUpdateRequired(
        current: currentVersion,
        minRequired: minVersion,
      );

      final isOptionalAvailable = VersionUtil.isOptionalUpdateAvailable(
        current: currentVersion,
        latest: latestVersion,
      );

      AppLogger.i(
        '📊 Versiyon analizi: current=$currentVersion, min=$minVersion, latest=$latestVersion'
        ', forceRequired: $isForceRequired, optionalAvailable: $isOptionalAvailable',
      );

      // Navigation tipini belirle
      if (isForceRequired) {
        AppLogger.w('⚠️ Zorunlu güncelleme gerekli');
        return SplashNavigationType.forceUpdate;
      }

      if (isOptionalAvailable) {
        AppLogger.i('📦 Opsiyonel güncelleme mevcut');
        return SplashNavigationType.optionalUpdate;
      }

      return SplashNavigationType.continueFlow;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Versiyon kontrolü hatası', e, stackTrace);
      return SplashNavigationType.continueFlow;
    }
  }

  /// Debug mode navigation tipini döner
  SplashNavigationType _getDebugNavigationType() {
    AppLogger.i('🐛 Debug mode test case: ${SplashConstants.debugTestCase}');

    switch (SplashConstants.debugTestCase) {
      case 1:
        return SplashNavigationType.forceUpdate;
      case 2:
        return SplashNavigationType.optionalUpdate;
      default:
        return SplashNavigationType.continueFlow;
    }
  }

  /// Onboarding durumunu kontrol eder
  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed =
          prefs.getBool(SplashConstants.onboardingCompletedKey) ?? false;
      AppLogger.i('📋 Onboarding durumu: $completed');
      return completed;
    } catch (e) {
      AppLogger.e('❌ Onboarding durum kontrolü hatası', e);
      return false;
    }
  }

  /// Authentication durumunu kontrol eder ve navigation tipini döner
  Future<SplashNavigationType> checkAuthAndGetNavigation(
      AuthState authState) async {
    try {
      AppLogger.i('🔐 Auth durumu kontrol ediliyor: ${authState.runtimeType}');

      // Navigation flag'ini kontrol et
      if (_navigationStarted) {
        AppLogger.w('Navigation zaten başlatıldı, auth kontrolü atlanıyor');
        return SplashNavigationType.wait;
      }

      // Auth error durumu
      if (authState is AuthError) {
        AppLogger.w('⚠️ Auth hatası tespit edildi: ${authState.errorMessage}');

        // Kritik hata değilse anonim giriş dene
        if (!authState.isCritical) {
          return SplashNavigationType.signInAnonymously;
        } else {
          // Kritik hata ise home'a git (fallback)
          AppLogger.e('Kritik auth hatası, zorla home\'a yönlendiriliyor');
          return SplashNavigationType.home;
        }
      }

      // Authenticated durumu
      if (authState is AuthAuthenticated) {
        AppLogger.i('✅ Kullanıcı authenticated: ${authState.user.id}');
        return SplashNavigationType.home;
      }

      // Unauthenticated durumu
      if (authState is AuthUnauthenticated) {
        AppLogger.i('🔓 Kullanıcı unauthenticated, anonim giriş yapılacak');
        return SplashNavigationType.signInAnonymously;
      }

      // Loading veya diğer durumlar - sadece kısa süre bekle
      if (authState is AuthLoading) {
        AppLogger.i('⏳ Auth loading durumu, bekleniyor...');
        return SplashNavigationType.wait;
      }

      // Initial state - anonim giriş başlat
      if (authState is AuthInitial) {
        AppLogger.i('🚀 Auth initial state, anonim giriş başlatılacak');
        return SplashNavigationType.signInAnonymously;
      }

      AppLogger.w('⚠️ Bilinmeyen auth state: ${authState.runtimeType}');
      return SplashNavigationType.signInAnonymously;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Auth durum kontrolü hatası', e, stackTrace);
      return SplashNavigationType.signInAnonymously;
    }
  }

  /// NavigationManager'ı başlatır
  void initializeNavigationManager() {
    try {
      if (NavigationManager.instance == null) {
        NavigationManager.initialize(initialIndex: 0);
        AppLogger.i('🧭 NavigationManager başlatıldı');
      }
    } catch (e) {
      AppLogger.e('❌ NavigationManager başlatma hatası', e);
    }
  }

  /// iOS permissions'ları başlatır ki Settings'de görünebilsinler
  ///
  /// Bu metot iOS'ta kamera ve galeri izinlerinin Settings > TatarAI
  /// bölümünde görünmesini sağlar. Kullanıcı henüz bu özellikleri
  /// kullanmasa bile izinleri iOS ayarlarında yönetebilir.
  ///
  /// iOS 14+ için enhanced permission handling ile limited photo access desteği.
  Future<void> initializePermissions() async {
    try {
      AppLogger.i('🔐 iOS permissions başlatılıyor...');
      await PermissionService().registerIOSPermissions();
      AppLogger.i('✅ iOS permissions başarıyla başlatıldı');
    } catch (e) {
      AppLogger.e('❌ iOS permissions başlatma hatası', e);
      // Permission hatası uygulamanın çalışmasını engellemez
    }
  }

  /// Debug için force permission initialization
  ///
  /// Bu metot debug/test durumlarında permission sorunlarını
  /// çözmek için kullanılabilir. Settings sayfasından çağrılabilir.
  Future<void> debugInitializePermissions() async {
    try {
      AppLogger.i('🔧 DEBUG: iOS permissions force başlatılıyor...');
      await PermissionService().debugLogPermissions();
      AppLogger.i('✅ DEBUG: iOS permissions force başarıyla tamamlandı');
    } catch (e) {
      AppLogger.e('❌ DEBUG: iOS permissions force başlatma hatası', e);
      rethrow; // Debug'da hata fırlatmasına izin ver
    }
  }

  /// Debug için permission durumlarını test eder
  ///
  /// Bu metot mevcut permission durumlarını kontrol eder ve
  /// log'lar. Sorun tespiti için kullanılabilir.
  Future<void> debugTestPermissions() async {
    try {
      AppLogger.i('🔬 DEBUG: Permission durumları test ediliyor...');
      await PermissionService().debugLogPermissions();
      AppLogger.i('✅ DEBUG: Permission test tamamlandı');
    } catch (e) {
      AppLogger.e('❌ DEBUG: Permission test hatası', e);
    }
  }

  /// Force navigation - son çare
  void forceNavigateToHome(GoRouter router) {
    try {
      AppLogger.i('🏠 Zorla ana sayfaya yönlendiriliyor');
      initializeNavigationManager();
      router.go(RoutePaths.home);
    } catch (e) {
      AppLogger.e('❌ Zorla yönlendirme hatası', e);
    }
  }

  /// Service'i temizle
  void dispose() {
    cancelTimeout();
    resetNavigation();
    AppLogger.i('🧹 SplashService temizlendi');
  }

  /// Navigation başlatma flag'ini set eder (sadece son navigation için)
  void setNavigationStarted() {
    _navigationStarted = true;
    AppLogger.i('🧭 Navigation başlatıldı olarak işaretlendi');
  }
}

/// Splash navigation tipleri
enum SplashNavigationType {
  /// Ana sayfaya git
  home,

  /// Onboarding'e git
  onboarding,

  /// Zorunlu güncelleme ekranına git
  forceUpdate,

  /// Opsiyonel güncelleme dialog'u göster
  optionalUpdate,

  /// Flow'a devam et (normal akış)
  continueFlow,

  /// Anonim giriş yap
  signInAnonymously,

  /// Bekle (loading durumu)
  wait,
}
