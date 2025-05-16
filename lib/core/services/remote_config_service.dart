// lib/core/services/remote_config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:tatarai/core/utils/update_config.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService._()
      : _remoteConfig = FirebaseRemoteConfig.instance; // MODIFIED

  static RemoteConfigService? _instance; // NEW
  factory RemoteConfigService() => _instance ??= RemoteConfigService._(); // NEW

  final FirebaseRemoteConfig _remoteConfig;

  bool _initialized = false;

  // Başlatma işlemini basitleştirelim
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.i('Remote Config zaten başlatılmış');
      return;
    }

    try {
      // Debug modunda daha hızlı güncellemeler için
      final fetchInterval =
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 1);

      // Tüm ek parametreleri kaldırıp sadece minimumFetchInterval'i kullanalım
      final configSettings = RemoteConfigSettings(
        minimumFetchInterval: fetchInterval,
        fetchTimeout: const Duration(seconds: 10),
      );

      await _remoteConfig.setConfigSettings(configSettings);
      AppLogger.i('Remote Config ayarları başarıyla yapılandırıldı');

      // Default değerleri ayarla
      await _remoteConfig.setDefaults({
        'android_latest_version': '1.0.0',
        'android_min_version': '1.0.0',
        'android_store_url':
            'https://play.google.com/store/apps/details?id=com.example.app',
        'ios_latest_version': '1.0.0',
        'ios_min_version': '1.0.0',
        'ios_store_url': 'https://apps.apple.com/app/id0000000000',
        'force_update_message_tr': 'Yeni sürüm gerekli!',
        'force_update_message_en': 'New version required!',
        'optional_update_message_tr': 'Yeni sürüm mevcut!',
        'optional_update_message_en': 'New version available!',
      });
      AppLogger.i('Remote Config varsayılan değerleri ayarlandı');

      // Uzak yapılandırmayı getir ve aktifleştir
      try {
        await _remoteConfig.fetch();
        await _remoteConfig.activate();
        AppLogger.i(
            'Remote Config verileri başarıyla alındı ve aktifleştirildi');
      } catch (fetchError) {
        AppLogger.w(
            'Remote Config verilerini güncellerken hata: $fetchError. Varsayılan değerler kullanılacak.');
        // Hata durumunda varsayılan değerleri kullan, hatayı yukarı fırlatma
      }

      _initialized = true;
    } catch (e) {
      AppLogger.e('Remote Config başlatma hatası', e);
      rethrow;
    }
  }

  UpdateConfig getUpdateConfig(
      {required bool isAndroid, required String locale}) {
    try {
      // Varsayılan dil kontrolü
      String actualLocale = locale.toLowerCase();
      if (actualLocale != 'tr' && actualLocale != 'en') {
        actualLocale = 'en'; // Varsayılan olarak İngilizce
      }

      // Parametreleri güvenli bir şekilde al
      final latestVersion = _safeGetString(
          isAndroid ? 'android_latest_version' : 'ios_latest_version', '1.0.0');

      final minVersion = _safeGetString(
          isAndroid ? 'android_min_version' : 'ios_min_version', '1.0.0');

      final storeUrl =
          _safeGetString(isAndroid ? 'android_store_url' : 'ios_store_url', '');

      final forceMessage = _safeGetString(
          'force_update_message_$actualLocale', 'Yeni sürüm gerekli!');

      final optionalMessage = _safeGetString(
          'optional_update_message_$actualLocale', 'Yeni sürüm mevcut!');

      // Firebase'den alınan değerleri detaylı logla
      AppLogger.i('Remote Config değerleri (${isAndroid ? 'Android' : 'iOS'}): ' +
          'latestVersion=$latestVersion, ' +
          'minVersion=$minVersion, ' +
          'storeUrl=$storeUrl, ' +
          'forceMsg=${forceMessage.length > 20 ? forceMessage.substring(0, 20) + "..." : forceMessage}, ' +
          'optionalMsg=${optionalMessage.length > 20 ? optionalMessage.substring(0, 20) + "..." : optionalMessage}');

      return UpdateConfig(
        latestVersion: latestVersion,
        minVersion: minVersion,
        storeUrl: storeUrl,
        forceUpdateMessage: forceMessage,
        optionalUpdateMessage: optionalMessage,
      );
    } catch (e) {
      AppLogger.e('Remote Config değerleri alınırken hata', e);
      return _getDefaultConfig();
    }
  }

  // Güvenli string alma yöntemi
  String _safeGetString(String key, String defaultValue) {
    try {
      final value = _remoteConfig.getString(key);
      return value.isNotEmpty ? value : defaultValue;
    } catch (e) {
      AppLogger.w('$key değeri alınırken hata: $e');
      return defaultValue;
    }
  }

  UpdateConfig _getDefaultConfig() {
    return UpdateConfig(
      latestVersion: '1.0.0',
      minVersion: '1.0.0',
      storeUrl: '',
      forceUpdateMessage: 'Yeni sürüm gerekli!',
      optionalUpdateMessage: 'Yeni sürüm mevcut!',
    );
  }
}
