import 'package:flutter/material.dart';

/// Uygulama içi dil desteği için sabitler
class LocaleConstants {
  /// Türkçe dil desteği
  static const Locale trLocale = Locale('tr', 'TR');

  /// İngilizce dil desteği
  static const Locale enLocale = Locale('en', 'US');

  /// Desteklenen tüm diller
  static final List<Locale> supportedLocales = [trLocale, enLocale];

  /// Dil saklama anahtarı - SharedPreferences için
  static const String prefsKeyLanguage = 'selected_language';

  /// Path ayarları
  static const String langPath = 'assets/translations';

  /// Varsayılan dil seçimi
  static const Locale fallbackLocale = trLocale;
}
