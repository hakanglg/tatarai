import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tatarai/core/utils/logger.dart';

/// 🔐 Manages all application permissions from a central location.
///
/// This service is initialized on the splash screen and uses the singleton
/// pattern to ensure a single instance throughout the app.
class PermissionService {
  factory PermissionService() {
    return _instance;
  }

  PermissionService._();

  static final PermissionService _instance = PermissionService._();

  /// A cache for permission statuses to avoid redundant checks.
  final Map<Permission, PermissionStatus> _permissionCache = {};

  /// Tracks whether the service has been initialized.
  bool _isInitialized = false;

  /// iOS version information for permission handling
  int? _iosVersion;

  /// Returns true if the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns true if running on iOS 14+
  bool get _isIOS14Plus {
    if (!Platform.isIOS) return false;
    return (_iosVersion ?? 0) >= 14;
  }

  /// Checks if running on iOS Simulator
  bool get _isIOSSimulator {
    if (!Platform.isIOS) return false;
    if (!kDebugMode) return false;

    // In iOS simulator, permission dialogs often don't work properly
    // This is a common issue in development environment
    return true;
  }

  /// Initializes the service. This should be called on app startup.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    AppLogger.i('🔐 Initializing Permission Service...');

    if (_isIOSSimulator) {
      AppLogger.i('📱 iOS Simulator detected - using mock permissions');
    }

    try {
      // Get iOS version if on iOS
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        _iosVersion = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
        AppLogger.i('📱 iOS Version: $_iosVersion');
      }

      await _cacheEssentialPermissions();
      if (Platform.isIOS) {
        final photoStatus = await Permission.photos.status;
        AppLogger.i('  📸 Initial iOS Photos permission status: $photoStatus');

        if (_isIOS14Plus) {
          AppLogger.i(
            '  📸 iOS 14+ detected - using enhanced photo permission handling',
          );
        }
      }
      _isInitialized = true;
      AppLogger.i('✅ Permission Service initialized successfully.');
    } catch (e) {
      AppLogger.e('❌ Failed to initialize Permission Service.', e);
      rethrow;
    }
  }

  /// Caches the status of essential permissions on startup.
  Future<void> _cacheEssentialPermissions() async {
    AppLogger.i('🗂️ Caching essential permissions...');
    final essentialPermissions = [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ];

    for (final permission in essentialPermissions) {
      try {
        PermissionStatus status;

        if (_isIOSSimulator) {
          // For iOS simulator, mock permissions as granted
          status = PermissionStatus.granted;
          AppLogger.i(
            '  🤖 Simulator: Mocking ${permission.toString()} as granted',
          );
        } else {
          status = await permission.status;
        }

        _permissionCache[permission] = status;
        AppLogger.i('  📋 Cached ${permission.toString()}: $status');
      } catch (e) {
        AppLogger.e('  ❌ Error caching ${permission.toString()}', e);
      }
    }
  }

  /// Returns the cached status for a given permission.
  PermissionStatus? getCachedPermissionStatus(Permission permission) {
    return _permissionCache[permission];
  }

  /// Refreshes and returns the current status for a given permission.
  Future<PermissionStatus> refreshPermissionStatus(
    Permission permission,
  ) async {
    try {
      PermissionStatus status;

      if (_isIOSSimulator) {
        // For iOS simulator, always return granted
        status = PermissionStatus.granted;
        AppLogger.i(
          '🤖 Simulator: Returning granted for ${permission.toString()}',
        );
      } else {
        status = await permission.status;
      }

      _permissionCache[permission] = status;
      return status;
    } catch (e) {
      AppLogger.e('🔄 Failed to refresh permission status', e);
      return PermissionStatus.denied;
    }
  }

  /// Requests a single permission and handles the result.
  Future<PermissionRequestResult> request(
    Permission permission, {
    required BuildContext context,
  }) async {
    AppLogger.i(
      '🙋‍♂️ Requesting permission: [38;5;12m${permission.toString()}[0m',
    );

    try {
      // Special handling for iOS Simulator
      if (_isIOSSimulator) {
        AppLogger.i(
          '🤖 iOS Simulator detected - granting permission automatically',
        );
        _permissionCache[permission] = PermissionStatus.granted;
        return PermissionRequestResult.granted;
      }

      final currentStatus = await refreshPermissionStatus(permission);

      if (currentStatus.isGranted || currentStatus.isLimited) {
        AppLogger.i('✅ Permission already granted: $currentStatus');
        return PermissionRequestResult.granted;
      }

      // Check if permission is permanently denied BEFORE making request
      if (currentStatus.isPermanentlyDenied) {
        AppLogger.w(
          '🚫 Permission was already permanently denied: $permission',
        );
        return PermissionRequestResult.permanentlyDenied;
      }

      // Request permission if it's denied OR not determined (first time)
      // Note: On iOS, permissions start as 'denied' when not yet requested
      if (currentStatus.isDenied) {
        AppLogger.i('📝 Permission needs to be requested (status: $currentStatus)');
        final requestedStatus = await permission.request();
        _permissionCache[permission] = requestedStatus;
        AppLogger.i('📝 Permission request result: $requestedStatus');

        return _mapStatusToResult(requestedStatus);
      }

      // Handle other status cases (restricted, etc.)
      return _mapStatusToResult(currentStatus);
    } catch (e) {
      AppLogger.e('❌ Error requesting permission', e);
      return PermissionRequestResult.error;
    }
  }

  /// Requests camera permission specifically for taking photos.
  Future<PermissionRequestResult> requestCameraPermission({
    required BuildContext context,
  }) async {
    AppLogger.i('📷 Requesting camera permission');

    // Special handling for iOS Simulator
    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator: Auto-granting camera permission');
      _permissionCache[Permission.camera] = PermissionStatus.granted;
      return PermissionRequestResult.granted;
    }

    return await request(Permission.camera, context: context);
  }

  /// Requests photo library permission specifically for gallery access.
  Future<PermissionRequestResult> requestPhotosPermission({
    required BuildContext context,
  }) async {
    AppLogger.i('📸 Requesting photos permission');

    // Special handling for iOS Simulator
    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator: Auto-granting photos permission');
      _permissionCache[Permission.photos] = PermissionStatus.granted;
      return PermissionRequestResult.granted;
    }

    // Enhanced handling for iOS 14+ with limited photo access
    if (_isIOS14Plus) {
      AppLogger.i('📸 iOS 14+ photo permission request');

      final currentStatus = await Permission.photos.status;
      AppLogger.i('📸 Current photo permission status: $currentStatus');

      // For iOS 14+, limited access is considered acceptable
      if (currentStatus.isGranted || currentStatus.isLimited) {
        AppLogger.i('✅ Photos permission already granted/limited');
        _permissionCache[Permission.photos] = currentStatus;
        return PermissionRequestResult.granted;
      }

      // If permanently denied, direct to settings
      if (currentStatus.isPermanentlyDenied) {
        AppLogger.w('🚫 Photos permission permanently denied');
        return PermissionRequestResult.permanentlyDenied;
      }

      // Request permission
      final requestedStatus = await Permission.photos.request();
      _permissionCache[Permission.photos] = requestedStatus;

      AppLogger.i('📸 Photo permission request result: $requestedStatus');

      // For iOS 14+, both granted and limited are acceptable
      if (requestedStatus.isGranted || requestedStatus.isLimited) {
        if (requestedStatus.isLimited) {
          AppLogger.i(
            '📸 Limited photo access granted - user can manage selection',
          );
        }
        return PermissionRequestResult.granted;
      }

      return _mapStatusToResult(requestedStatus);
    }

    return await request(Permission.photos, context: context);
  }

  /// Requests camera and photo permissions for media selection.
  ///
  /// This method is kept for backward compatibility but now has a more
  /// user-friendly approach where permissions are handled individually.
  Future<MediaPermissionResult> requestMediaPermissions({
    required BuildContext context,
  }) async {
    AppLogger.i('📸 Requesting media permissions (Camera & Photos)');

    // Special handling for iOS Simulator
    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator: Auto-granting media permissions');
      _permissionCache[Permission.camera] = PermissionStatus.granted;
      _permissionCache[Permission.photos] = PermissionStatus.granted;
      return MediaPermissionResult.allGranted;
    }

    // For real devices, we'll be more intelligent about permission requests
    // Instead of requesting both permissions upfront, we'll let the user choose
    // their preferred method first, then request only the necessary permission

    // Check current status of both permissions
    final cameraStatus = await refreshPermissionStatus(Permission.camera);
    final photosStatus = await refreshPermissionStatus(Permission.photos);

    // If both are already granted, great!
    if ((cameraStatus.isGranted || cameraStatus.isLimited) &&
        (photosStatus.isGranted || photosStatus.isLimited)) {
      return MediaPermissionResult.allGranted;
    }

    // If one is granted, that's enough for basic functionality
    if ((cameraStatus.isGranted || cameraStatus.isLimited) ||
        (photosStatus.isGranted || photosStatus.isLimited)) {
      return MediaPermissionResult.partiallyGranted;
    }

    // If both are permanently denied, inform user about settings
    if (cameraStatus.isPermanentlyDenied && photosStatus.isPermanentlyDenied) {
      return MediaPermissionResult.permanentlyDenied;
    }

    // Neither permission is granted, but not permanently denied
    // This is actually okay - we'll request permissions individually when needed
    return MediaPermissionResult.needsRequest;
  }

  /// To be called when the app resumes to refresh permission states.
  Future<void> onAppResume() async {
    AppLogger.i('🔄 App resumed, refreshing permission cache...');
    await _cacheEssentialPermissions();
  }

  /// Initializes iOS permissions to make them appear in Settings.
  ///
  /// Bu metot iOS'ta izinlerin Settings > App Name bölümünde görünmesini sağlar.
  /// Her izni en az bir kere request etmemiz gerekiyor ki iOS ayarlarında gösterebilsin.
  ///
  /// Splash screen'de çağrılmalı ki kullanıcılar özelliği kullanmadan önce
  /// izinleri iOS ayarlarından yönetebilsinler.
  ///
  /// iOS 14+ için enhanced handling ile limited photo access desteği içerir.
  Future<void> initializeIOSPermissions() async {
    if (!Platform.isIOS) {
      AppLogger.i('📱 Not iOS, skipping permission initialization');
      return;
    }

    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator, skipping permission initialization');
      return;
    }

    AppLogger.i('🍎 iOS permissions başlatılıyor...');
    if (_isIOS14Plus) {
      AppLogger.i('📱 iOS 14+ enhanced permission initialization');
    }

    try {
      // İzin durumlarını kontrol et
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;

      AppLogger.i('📸 Mevcut kamera durumu: $cameraStatus');
      AppLogger.i('🖼️ Mevcut galeri durumu: $photosStatus');

      // iOS ayarlarında görünmesi için permission'ları kesinlikle request et
      // İlk kez app açıldığında tüm izinleri request et ki iOS Settings'te görünsün
      AppLogger.i('🔐 iOS ayarları için izinler kesinlikle başlatılıyor...');

      // Kamera izni - iOS ayarlarında görünmesi için
      // iOS'ta Settings'te görünmesi için en az bir kere request edilmeli
      if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied) {
        try {
          AppLogger.i('📷 Kamera izni iOS Settings için kaydediliyor...');
          final cameraResult = await Permission.camera.request();
          AppLogger.i('✅ Kamera izni sonucu: $cameraResult');
        } catch (e) {
          AppLogger.e('❌ Kamera izni kayıt hatası', e);
        }
      } else {
        AppLogger.i('📷 Kamera izni durumu: $cameraStatus');
      }

      // Galeri izni - iOS ayarlarında görünmesi için  
      // iOS'ta Settings'te görünmesi için en az bir kere request edilmeli
      if (!photosStatus.isGranted && !photosStatus.isPermanentlyDenied && !photosStatus.isLimited) {
        try {
          AppLogger.i('📸 Galeri izni iOS Settings için kaydediliyor...');
          final photosResult = await Permission.photos.request();
          AppLogger.i('✅ Galeri izni sonucu: $photosResult');

          // iOS 14+ için limited access bilgisi
          if (_isIOS14Plus && photosResult.isLimited) {
            AppLogger.i('📸 iOS 14+ Limited photo access enabled');
          }
        } catch (e) {
          AppLogger.e('❌ Galeri izni kayıt hatası', e);
        }
      } else {
        AppLogger.i('📸 Galeri izni durumu: $photosStatus');
      }

      // Cache'i güncelle
      await _cacheEssentialPermissions();
      AppLogger.i('✅ iOS permissions başarıyla başlatıldı');
    } catch (e) {
      AppLogger.e('❌ iOS permissions başlatma hatası', e);
      // Permission hatası app'i crash etmesin
    }
  }

  /// Opens the application's settings screen.
  Future<bool> openApplicationSettings() async {
    try {
      AppLogger.i('⚙️ Opening application settings...');
      return await openAppSettings();
    } catch (e) {
      AppLogger.e('⚙️ Failed to open application settings', e);
      return false;
    }
  }

  /// Debug için iOS permissions'ları force initialize eder
  ///
  /// Bu metot production'da kullanılmamalı! Sadece development/test için.
  /// Tüm izinleri tekrar iOS'a kaydetmeye çalışır.
  Future<void> debugForceInitializeIOSPermissions() async {
    if (!Platform.isIOS) {
      AppLogger.i('📱 Not iOS, skipping debug permission initialization');
      return;
    }

    // Simulator'da da test etmeye izin ver (debug için)
    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator BYPASS: Force testing permissions...');
      // Continue instead of returning
    }

    AppLogger.i('🔧 DEBUG: iOS permissions force başlatılıyor...');

    try {
      // Force request camera permission
      try {
        AppLogger.i('🔧 DEBUG: Kamera izni force başlatılıyor...');
        final cameraResult = await Permission.camera.request();
        AppLogger.i('🔧 DEBUG: Kamera izni sonucu: $cameraResult');
      } catch (e) {
        AppLogger.e('🔧 DEBUG: Kamera izni hatası', e);
      }

      // Force request photos permission
      try {
        AppLogger.i('🔧 DEBUG: Galeri izni force başlatılıyor...');
        final photosResult = await Permission.photos.request();
        AppLogger.i('🔧 DEBUG: Galeri izni sonucu: $photosResult');
      } catch (e) {
        AppLogger.e('🔧 DEBUG: Galeri izni hatası', e);
      }

      // Update cache (force real permissions in debug mode)
      if (_isIOSSimulator) {
        // In debug mode, don't use simulator mocks - show real permission states
        AppLogger.i('🔧 DEBUG: Cache güncelleniyor - gerçek durumlarla');
        await _cacheEssentialPermissionsReal();
      } else {
        await _cacheEssentialPermissions();
      }
      AppLogger.i('✅ DEBUG: iOS permissions force başlatma tamamlandı');
    } catch (e) {
      AppLogger.e('❌ DEBUG: iOS permissions force başlatma hatası', e);
    }
  }

  /// Debug için - Simulator'da da gerçek permission durumlarını cache'le
  Future<void> _cacheEssentialPermissionsReal() async {
    AppLogger.i('🔧 DEBUG: Gerçek permission durumları cache\'leniyor...');
    final essentialPermissions = [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ];

    for (final permission in essentialPermissions) {
      try {
        // Simulator'da bile gerçek durumu al (debug için)
        final status = await permission.status;
        _permissionCache[permission] = status;
        AppLogger.i('  🔧 DEBUG: Cached ${permission.toString()}: $status');
      } catch (e) {
        AppLogger.e('  ❌ Error caching ${permission.toString()}', e);
      }
    }
  }

  /// Debug için - iOS permissions'ları test eder ve durumlarını log'lar
  ///
  /// Bu metot mevcut permission durumlarını detaylı şekilde log'lar
  /// ve iOS ayarlarında görünür olup olmadığını test eder.
  Future<void> debugTestPermissions() async {
    AppLogger.i('🔬 DEBUG: Permission durumları test ediliyor...');

    if (!Platform.isIOS) {
      AppLogger.i('📱 Not iOS, permission test skipped');
      return;
    }

    try {
      AppLogger.i('📱 iOS Version: $_iosVersion');
      AppLogger.i('📱 iOS 14+ Support: $_isIOS14Plus');
      AppLogger.i('📱 iOS Simulator: $_isIOSSimulator');
      AppLogger.i('📱 Service Initialized: $_isInitialized');

      // Test all essential permissions
      final permissions = [
        Permission.camera,
        Permission.photos,
        Permission.storage,
        Permission.notification,
      ];

      for (final permission in permissions) {
        final status = await permission.status;
        final cached = _permissionCache[permission];

        AppLogger.i('🔍 $permission:');
        AppLogger.i('  - Current Status: $status');
        AppLogger.i('  - Cached Status: $cached');
        AppLogger.i('  - Is Granted: ${status.isGranted}');
        AppLogger.i('  - Is Denied: ${status.isDenied}');
        AppLogger.i('  - Is Permanently Denied: ${status.isPermanentlyDenied}');
        AppLogger.i('  - Is Limited: ${status.isLimited}');
        AppLogger.i('  - Is Restricted: ${status.isRestricted}');
        AppLogger.i('  ---');
      }

      AppLogger.i('✅ DEBUG: Permission test completed');
    } catch (e) {
      AppLogger.e('❌ DEBUG: Permission test failed', e);
    }
  }

  /// Basit test: Sadece Camera ve Photos permission request et
  /// iOS Settings'te görünmesi için kesinlikle request et
  Future<void> debugSimplePermissionTest() async {
    if (!Platform.isIOS) {
      AppLogger.i('📱 Not iOS, skipping simple permission test');
      return;
    }

    if (_isIOSSimulator) {
      AppLogger.i('🤖 iOS Simulator, skipping simple permission test');
      return;
    }

    AppLogger.i('🧪 DEBUG: Basit permission test başlatılıyor...');

    try {
      // Camera permission test
      AppLogger.i('📷 Camera permission test...');
      final cameraStatus = await Permission.camera.status;
      AppLogger.i('📷 Camera permission mevcut durum: $cameraStatus');
      
      if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied) {
        AppLogger.i('📷 Camera permission request ediliyor...');
        final cameraResult = await Permission.camera.request();
        AppLogger.i('📷 Camera permission sonuç: $cameraResult');
      }

      // Photos permission test
      AppLogger.i('📸 Photos permission test...');
      final photosStatus = await Permission.photos.status;
      AppLogger.i('📸 Photos permission mevcut durum: $photosStatus');
      
      if (!photosStatus.isGranted && !photosStatus.isPermanentlyDenied && !photosStatus.isLimited) {
        AppLogger.i('📸 Photos permission request ediliyor...');
        final photosResult = await Permission.photos.request();
        AppLogger.i('📸 Photos permission sonuç: $photosResult');
      }

      AppLogger.i('✅ DEBUG: Basit permission test tamamlandı');
    } catch (e) {
      AppLogger.e('❌ DEBUG: Basit permission test hatası', e);
    }
  }

  // ========== Private Helper Methods ==========

  PermissionRequestResult _mapStatusToResult(PermissionStatus status) {
    if (status.isGranted) {
      return PermissionRequestResult.granted;
    }
    if (status.isDenied) {
      return PermissionRequestResult.denied;
    }
    if (status.isPermanentlyDenied) {
      return PermissionRequestResult.permanentlyDenied;
    }
    if (status.isRestricted) {
      return PermissionRequestResult.restricted;
    }
    if (status.isLimited) {
      return PermissionRequestResult.granted; // Treat limited as granted
    }
    return PermissionRequestResult.denied;
  }

}

/// Represents the result of a permission request.
enum PermissionRequestResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  error,
}

/// Represents the result of a request for media permissions.
enum MediaPermissionResult {
  allGranted,
  partiallyGranted,
  denied,
  permanentlyDenied,
  needsRequest,
}
