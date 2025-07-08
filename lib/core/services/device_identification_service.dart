import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/logger.dart';

/// Cihaz tanımlama ve fingerprinting servisi
///
/// Bu servis her cihaz için benzersiz bir tanımlayıcı oluşturur ve
/// kullanıcıların cihaz değişimi durumunda kredilerini korumalarını sağlar.
/// Anonimlik korunarak cihaz tabanlı kullanıcı yönetimi yapar.
///
/// Özellikler:
/// - Platform bağımsız cihaz tanımlama
/// - Güvenli fingerprint oluşturma
/// - Local storage ile persistency
/// - Privacy-friendly implementation
class DeviceIdentificationService {
  /// DeviceInfo Plus instance
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// SharedPreferences key for device fingerprint
  static const String _deviceFingerprintKey = 'device_fingerprint';

  /// Service adı (logging için)
  static const String _serviceName = 'DeviceIdentificationService';

  /// Singleton instance
  static DeviceIdentificationService? _instance;

  /// Cached device fingerprint
  String? _cachedFingerprint;

  /// Singleton constructor
  DeviceIdentificationService._internal();

  /// Get singleton instance
  static DeviceIdentificationService get instance {
    _instance ??= DeviceIdentificationService._internal();
    return _instance!;
  }

  /// Cihazın benzersiz fingerprint'ini alır
  ///
  /// Önce cache'ten kontrol eder, sonra SharedPreferences'ten,
  /// en son olarak yeni bir fingerprint oluşturur.
  Future<String> getDeviceFingerprint() async {
    try {
      // Cache'te varsa direkt döndür
      if (_cachedFingerprint != null) {
        AppLogger.logWithContext(
          _serviceName,
          'Device fingerprint cache\'ten alındı',
          _cachedFingerprint!.substring(0, 8),
        );
        return _cachedFingerprint!;
      }

      // SharedPreferences'te var mı kontrol et
      final prefs = await SharedPreferences.getInstance();
      final savedFingerprint = prefs.getString(_deviceFingerprintKey);

      if (savedFingerprint != null && savedFingerprint.isNotEmpty) {
        _cachedFingerprint = savedFingerprint;
        AppLogger.logWithContext(
          _serviceName,
          'Device fingerprint SharedPreferences\'ten alındı',
          savedFingerprint.substring(0, 8),
        );
        return savedFingerprint;
      }

      // Yeni fingerprint oluştur
      final fingerprint = await _generateDeviceFingerprint();
      
      // Cache'e kaydet
      _cachedFingerprint = fingerprint;
      
      // SharedPreferences'e kaydet
      await prefs.setString(_deviceFingerprintKey, fingerprint);

      AppLogger.successWithContext(
        _serviceName,
        'Yeni device fingerprint oluşturuldu ve kaydedildi',
        fingerprint.substring(0, 8),
      );

      return fingerprint;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Device fingerprint alma hatası',
        e,
        stackTrace,
      );
      
      // Fallback: Timestamp based unique ID
      final fallbackId = _generateFallbackId();
      AppLogger.warnWithContext(
        _serviceName,
        'Fallback device ID oluşturuldu',
        fallbackId.substring(0, 8),
      );
      
      return fallbackId;
    }
  }

  /// Platform bazlı cihaz fingerprint'i oluşturur
  Future<String> _generateDeviceFingerprint() async {
    try {
      AppLogger.logWithContext(_serviceName, 'Device fingerprint oluşturuluyor');

      final Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        deviceData.addAll(await _getAndroidDeviceData());
      } else if (Platform.isIOS) {
        deviceData.addAll(await _getIOSDeviceData());
      } else {
        // Diğer platformlar için fallback
        deviceData.addAll(await _getGenericDeviceData());
      }

      // Device data'yı JSON string'e çevir
      final jsonString = json.encode(deviceData);
      
      // SHA-256 hash oluştur
      final bytes = utf8.encode(jsonString);
      final digest = sha256.convert(bytes);
      final fingerprint = digest.toString();

      AppLogger.logWithContext(
        _serviceName,
        'Device fingerprint başarıyla oluşturuldu',
        'Platform: ${Platform.operatingSystem}, Hash: ${fingerprint.substring(0, 8)}...',
      );

      return fingerprint;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Device fingerprint oluşturma hatası',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Android cihaz verilerini alır
  Future<Map<String, dynamic>> _getAndroidDeviceData() async {
    final androidInfo = await _deviceInfo.androidInfo;
    
    return {
      'platform': 'android',
      'model': androidInfo.model,
      'manufacturer': androidInfo.manufacturer,
      'product': androidInfo.product,
      'brand': androidInfo.brand,
      'device': androidInfo.device,
      'fingerprint': androidInfo.fingerprint,
      'id': androidInfo.id,
      'bootloader': androidInfo.bootloader,
      'board': androidInfo.board,
      'hardware': androidInfo.hardware,
      // androidId kullanıyoruz ama null check yapıyoruz
      'androidId': androidInfo.id,
    };
  }

  /// iOS cihaz verilerini alır
  Future<Map<String, dynamic>> _getIOSDeviceData() async {
    final iosInfo = await _deviceInfo.iosInfo;
    
    return {
      'platform': 'ios',
      'model': iosInfo.model,
      'name': iosInfo.name,
      'systemName': iosInfo.systemName,
      'systemVersion': iosInfo.systemVersion,
      'localizedModel': iosInfo.localizedModel,
      'identifierForVendor': iosInfo.identifierForVendor,
      'isPhysicalDevice': iosInfo.isPhysicalDevice,
      'utsname': {
        'machine': iosInfo.utsname.machine,
        'sysname': iosInfo.utsname.sysname,
        'release': iosInfo.utsname.release,
        'version': iosInfo.utsname.version,
      },
    };
  }

  /// Generic platform cihaz verilerini alır (fallback)
  Future<Map<String, dynamic>> _getGenericDeviceData() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Fallback ID oluşturur (son çare)
  String _generateFallbackId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final platform = Platform.operatingSystem;
    
    final fallbackString = '$platform-$timestamp-$random';
    final bytes = utf8.encode(fallbackString);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Device fingerprint'i sıfırlar (debugging için)
  Future<void> clearDeviceFingerprint() async {
    try {
      AppLogger.logWithContext(_serviceName, 'Device fingerprint temizleniyor');
      
      _cachedFingerprint = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceFingerprintKey);
      
      AppLogger.successWithContext(
        _serviceName,
        'Device fingerprint başarıyla temizlendi',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Device fingerprint temizleme hatası',
        e,
        stackTrace,
      );
    }
  }

  /// Cihaz bilgilerini detaylı log'lar (debugging için)
  Future<void> logDeviceInfo() async {
    try {
      AppLogger.logWithContext(_serviceName, 'Cihaz bilgileri alınıyor');
      
      final fingerprint = await getDeviceFingerprint();
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        AppLogger.logWithContext(
          _serviceName,
          'Android Cihaz Bilgileri',
          'Model: ${androidInfo.model}, '
          'Manufacturer: ${androidInfo.manufacturer}, '
          'Fingerprint: ${fingerprint.substring(0, 8)}...',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        AppLogger.logWithContext(
          _serviceName,
          'iOS Cihaz Bilgileri',
          'Model: ${iosInfo.model}, '
          'Name: ${iosInfo.name}, '
          'IdentifierForVendor: ${iosInfo.identifierForVendor}, '
          'Fingerprint: ${fingerprint.substring(0, 8)}...',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Cihaz bilgileri alma hatası',
        e,
        stackTrace,
      );
    }
  }
}