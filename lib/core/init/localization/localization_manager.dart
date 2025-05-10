import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Tüm lokalizasyon süreçlerini yöneten sınıf
class LocalizationManager {
  /// SharedPreferences instance
  static late final SharedPreferences _preferences;

  /// Tek örnek (singleton) pattern için instance
  static final LocalizationManager _instance = LocalizationManager._init();

  /// Singleton instance
  static LocalizationManager get instance => _instance;

  /// Şu anki dil değeri stream controller
  final ValueNotifier<Locale> _currentLocale =
      ValueNotifier<Locale>(LocaleConstants.fallbackLocale);

  /// Şu anki dil değeri stream controller getter
  ValueNotifier<Locale> get currentLocaleNotifier => _currentLocale;

  /// Şu anki locale değeri
  Locale get currentLocale => _currentLocale.value;

  /// Private constructor
  LocalizationManager._init();

  /// LocalizationManager'ı başlat
  static Future<void> init() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final localeManager = LocalizationManager._instance;
      await localeManager._loadSavedLocale();
      AppLogger.i('Localization manager başarıyla başlatıldı');
    } catch (e) {
      AppLogger.e('Localization manager başlatma hatası: $e');
    }
  }

  /// Kaydedilmiş dil ayarını yükle
  Future<void> _loadSavedLocale() async {
    try {
      final savedLanguageCode =
          _preferences.getString(LocaleConstants.prefsKeyLanguage);

      if (savedLanguageCode != null && savedLanguageCode.isNotEmpty) {
        // Kaydedilmiş dili al ve kullan
        final List<String> codeParts = savedLanguageCode.split('_');
        if (codeParts.length >= 2) {
          final newLocale = Locale(codeParts[0], codeParts[1]);
          _updateLocale(newLocale);
          AppLogger.i('Kaydedilmiş dil yüklendi: $newLocale');
        } else {
          // Sadece dil kodu varsa (ülke kodu yoksa)
          final newLocale = Locale(codeParts[0]);
          _updateLocale(newLocale);
          AppLogger.i('Kaydedilmiş dil yüklendi: $newLocale');
        }
      } else {
        // Kaydedilmiş dil yoksa cihaz dilini kullan
        _useDeviceLocale();
      }
    } catch (e) {
      AppLogger.e('Kaydedilmiş dil yükleme hatası: $e');
      _useDeviceLocale();
    }
  }

  /// Cihaz dilini kullan
  void _useDeviceLocale() {
    try {
      final deviceLocale = PlatformDispatcher.instance.locale;
      final deviceLanguageCode = deviceLocale.languageCode;

      // Desteklenen diller arasında varsa kullan, yoksa varsayılan dil
      final supportedLocale = LocaleConstants.supportedLocales.firstWhere(
        (locale) => locale.languageCode == deviceLanguageCode,
        orElse: () => LocaleConstants.fallbackLocale,
      );

      _updateLocale(supportedLocale);
      AppLogger.i('Cihaz dili kullanılıyor: $supportedLocale');
    } catch (e) {
      AppLogger.e('Cihaz dili alma hatası: $e');
      _updateLocale(LocaleConstants.fallbackLocale);
    }
  }

  /// Dil değiştir
  Future<void> changeLocale(Locale locale) async {
    if (!_isSupportedLocale(locale)) {
      AppLogger.w('Desteklenmeyen dil: $locale, varsayılan dil kullanılıyor');
      locale = LocaleConstants.fallbackLocale;
    }

    try {
      await _saveLocale(locale);
      _updateLocale(locale);

      // Uygulamanın doğru delegate'leri bilmesi için dil değişikliğini bildiriyoruz
      AppLogger.i('Dil değiştirildi: $locale');
    } catch (e) {
      AppLogger.e('Dil değiştirme hatası: $e');
    }
  }

  /// Dil ayarını kaydet
  Future<void> _saveLocale(Locale locale) async {
    final localeCode = '${locale.languageCode}_${locale.countryCode}';
    await _preferences.setString(LocaleConstants.prefsKeyLanguage, localeCode);
  }

  /// Locale değerini güncelle
  void _updateLocale(Locale locale) {
    _currentLocale.value = locale;
  }

  /// Desteklenen bir dil mi?
  bool _isSupportedLocale(Locale locale) {
    return LocaleConstants.supportedLocales.contains(locale) ||
        LocaleConstants.supportedLocales
            .map((e) => e.languageCode)
            .contains(locale.languageCode);
  }
}
