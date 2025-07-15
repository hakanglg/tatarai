import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Simple and effective Permission Service
///
/// This service handles camera and photo permissions in a straightforward way
/// that works reliably in both debug and production environments.
class PermissionService {
  factory PermissionService() => _instance;
  PermissionService._();
  static final PermissionService _instance = PermissionService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    AppLogger.i('🔐 PermissionService initializing...');
    
    try {
      // Simple initialization - just mark as ready
      _isInitialized = true;
      AppLogger.i('✅ PermissionService initialized successfully');
    } catch (e) {
      AppLogger.e('❌ PermissionService initialization failed', e);
      rethrow;
    }
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    AppLogger.i('📷 Requesting camera permission');
    
    try {
      final status = await Permission.camera.request();
      final granted = status.isGranted;
      
      AppLogger.i('📷 Camera permission result: $status (granted: $granted)');
      return granted;
    } catch (e) {
      AppLogger.e('❌ Camera permission request failed', e);
      return false;
    }
  }

  /// Request photos permission
  Future<bool> requestPhotosPermission() async {
    AppLogger.i('📸 Requesting photos permission');
    
    try {
      final status = await Permission.photos.request();
      final granted = status.isGranted || status.isLimited;
      
      AppLogger.i('📸 Photos permission result: $status (granted: $granted)');
      return granted;
    } catch (e) {
      AppLogger.e('❌ Photos permission request failed', e);
      return false;
    }
  }

  /// Check if camera permission is granted
  Future<bool> isCameraPermissionGranted() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.e('❌ Camera permission check failed', e);
      return false;
    }
  }

  /// Check if photos permission is granted
  Future<bool> isPhotosPermissionGranted() async {
    try {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    } catch (e) {
      AppLogger.e('❌ Photos permission check failed', e);
      return false;
    }
  }

  /// Check if permission is permanently denied
  Future<bool> isCameraPermissionPermanentlyDenied() async {
    try {
      final status = await Permission.camera.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      AppLogger.e('❌ Camera permission status check failed', e);
      return false;
    }
  }

  /// Check if photos permission is permanently denied
  Future<bool> isPhotosPermissionPermanentlyDenied() async {
    try {
      final status = await Permission.photos.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      AppLogger.e('❌ Photos permission status check failed', e);
      return false;
    }
  }

  /// Open app settings
  Future<bool> openSettings() async {
    try {
      AppLogger.i('⚙️ Opening app settings');
      return await openAppSettings();
    } catch (e) {
      AppLogger.e('❌ Failed to open app settings', e);
      return false;
    }
  }

  /// Register permissions with iOS (to make them appear in Settings)
  /// This should be called during app initialization
  Future<void> registerIOSPermissions() async {
    if (!Platform.isIOS) return;
    
    AppLogger.i('🍎 Registering iOS permissions for Settings visibility');
    
    try {
      // Check current permission statuses first
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      
      AppLogger.i('📷 Current camera status: $cameraStatus');
      AppLogger.i('📸 Current photos status: $photosStatus');
      
      // CRITICAL: In production iOS builds, permissions must be actually requested
      // to appear in Settings, not just declared in Info.plist
      
      // Only make actual requests in production or when permissions are not yet determined
      final bool shouldMakeRequests = !kDebugMode || 
          (cameraStatus != PermissionStatus.granted && cameraStatus != PermissionStatus.denied && cameraStatus != PermissionStatus.permanentlyDenied) || 
          (photosStatus != PermissionStatus.granted && photosStatus != PermissionStatus.denied && photosStatus != PermissionStatus.permanentlyDenied);
      
      if (shouldMakeRequests) {
        AppLogger.i('🚨 Making actual permission requests for iOS Settings registration');
        
        // Request camera permission if not yet determined
        if (cameraStatus != PermissionStatus.granted && cameraStatus != PermissionStatus.denied && cameraStatus != PermissionStatus.permanentlyDenied) {
          AppLogger.i('📷 Requesting camera permission for registration');
          final newCameraStatus = await Permission.camera.request();
          AppLogger.i('📷 Camera registration result: $newCameraStatus');
        }
        
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Request photos permission if not yet determined
        if (photosStatus != PermissionStatus.granted && photosStatus != PermissionStatus.denied && photosStatus != PermissionStatus.permanentlyDenied) {
          AppLogger.i('📸 Requesting photos permission for registration');
          final newPhotosStatus = await Permission.photos.request();
          AppLogger.i('📸 Photos registration result: $newPhotosStatus');
        }
        
        AppLogger.i('✅ iOS permissions actively registered - should appear in Settings');
      } else {
        AppLogger.i('ℹ️ iOS permissions already determined, no registration needed');
      }
      
    } catch (e) {
      AppLogger.e('❌ iOS permission registration failed', e);
    }
  }

  /// Force register permissions by making actual requests (for testing)
  /// This will show dialogs to user but ensure Settings toggles appear
  Future<void> forceRegisterIOSPermissions() async {
    if (!Platform.isIOS) return;
    
    AppLogger.i('🚨 FORCE registering iOS permissions - will show dialogs!');
    
    try {
      AppLogger.i('📷 Force requesting camera permission');
      final cameraResult = await Permission.camera.request();
      AppLogger.i('📷 Camera force result: $cameraResult');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger.i('📸 Force requesting photos permission');
      final photosResult = await Permission.photos.request();
      AppLogger.i('📸 Photos force result: $photosResult');
      
      AppLogger.i('✅ iOS permissions FORCE registered - should appear in Settings');
    } catch (e) {
      AppLogger.e('❌ iOS permission force registration failed', e);
    }
  }

  /// Aggressive iOS permission registration for production builds
  /// This method ensures permissions are registered with iOS Settings by making
  /// actual requests during app startup in production environment
  Future<void> aggressiveIOSPermissionRegistration() async {
    if (!Platform.isIOS) return;
    
    AppLogger.i('🚨 AGGRESSIVE iOS permission registration for production builds');
    
    try {
      // In production, always make requests to ensure Settings registration
      if (!kDebugMode) {
        AppLogger.i('🏭 Production mode - registering all permissions with iOS');
        
        // Request camera permission
        AppLogger.i('📷 Production: Requesting camera permission');
        final cameraResult = await Permission.camera.request();
        AppLogger.i('📷 Production camera result: $cameraResult');
        
        // Delay between requests
        await Future.delayed(const Duration(milliseconds: 600));
        
        // Request photos permission
        AppLogger.i('📸 Production: Requesting photos permission');
        final photosResult = await Permission.photos.request();
        AppLogger.i('📸 Production photos result: $photosResult');
        
        AppLogger.i('✅ Production iOS permissions registration complete');
      } else {
        AppLogger.i('🛠️ Debug mode - using regular registration');
        await registerIOSPermissions();
      }
    } catch (e) {
      AppLogger.e('❌ Aggressive iOS permission registration failed', e);
    }
  }

  /// Debug method to log all permission statuses
  Future<void> debugLogPermissions() async {
    if (!kDebugMode) return;
    
    AppLogger.i('🔍 DEBUG: Current permission statuses');
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      
      AppLogger.i('📷 Camera: $cameraStatus');
      AppLogger.i('📸 Photos: $photosStatus');
      AppLogger.i('🏗️ Platform: ${Platform.operatingSystem}');
      AppLogger.i('🐛 Debug Mode: $kDebugMode');
    } catch (e) {
      AppLogger.e('❌ Debug permission logging failed', e);
    }
  }
}