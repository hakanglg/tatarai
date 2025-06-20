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
        Locale newLocale;

        if (codeParts.length >= 2) {
          newLocale = Locale(codeParts[0], codeParts[1]);
        } else {
          // Sadece dil kodu varsa (ülke kodu yoksa)
          newLocale = Locale(codeParts[0]);
        }

        // Desteklenen dil mi kontrol et
        if (_isSupportedLocale(newLocale)) {
          _updateLocale(newLocale);
          AppLogger.i('Kaydedilmiş dil yüklendi: $newLocale');
        } else {
          AppLogger.w(
              'Desteklenmeyen kaydedilmiş dil: $newLocale, varsayılan dil kullanılıyor');
          _useDeviceLocale();
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
    AppLogger.i('changeLocale çağrıldı - istek edilen dil: $locale');
    AppLogger.i('Mevcut dil: ${_currentLocale.value}');

    if (!_isSupportedLocale(locale)) {
      AppLogger.w('Desteklenmeyen dil: $locale, varsayılan dil kullanılıyor');
      locale = LocaleConstants.fallbackLocale;
    }

    try {
      AppLogger.i('Dil kaydediliyor: $locale');
      await _saveLocale(locale);

      AppLogger.i('Locale güncelleniyor: $locale');
      _updateLocale(locale);

      AppLogger.i('Yeni locale değeri: ${_currentLocale.value}');
      AppLogger.i('Dil değişikliği tamamlandı: $locale');
    } catch (e) {
      AppLogger.e('Dil değiştirme hatası: $e');
      throw e; // Hatayı yukarı fırlat
    }
  }

  /// Dil ayarını kaydet
  Future<void> _saveLocale(Locale locale) async {
    try {
      final localeCode = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;

      await _preferences.setString(
          LocaleConstants.prefsKeyLanguage, localeCode);
      AppLogger.i('Dil ayarı kaydedildi: $localeCode');
    } catch (e) {
      AppLogger.e('Dil ayarı kaydetme hatası: $e');
    }
  }

  /// Locale değerini güncelle
  void _updateLocale(Locale locale) {
    AppLogger.d(
        '_updateLocale çağrıldı - eski: ${_currentLocale.value}, yeni: $locale');
    _currentLocale.value = locale;
    AppLogger.d(
        'ValueNotifier güncellendi - şu anki değer: ${_currentLocale.value}');
  }

  /// Desteklenen bir dil mi?
  bool _isSupportedLocale(Locale locale) {
    return LocaleConstants.supportedLocales.contains(locale) ||
        LocaleConstants.supportedLocales
            .map((e) => e.languageCode)
            .contains(locale.languageCode);
  }
}
