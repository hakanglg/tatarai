import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Uygulama içi çeviri desteği
class AppLocalizations {
  /// Geçerli locale değeri
  final Locale locale;

  /// Çeviri metinlerini içeren map
  Map<String, String> _localizedStrings = {};

  /// Constructor
  AppLocalizations(this.locale);

  /// Delegate oluşturucu
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Mevcut instance'a erişim için yardımcı metod
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Localization dosyalarını yükle
  Future<bool> load() async {
    try {
      // Dil dosyasını yükle (assets/translations/tr.json gibi)
      final String jsonString = await rootBundle.loadString(
        '${LocaleConstants.langPath}/${locale.languageCode}.json',
      );

      // JSON dosyasını parse et
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      // JSON'dan gelen değerleri String'e çevir
      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });

      AppLogger.i('${locale.languageCode} dil dosyası yüklendi');
      return true;
    } catch (e) {
      AppLogger.e('Dil dosyasını yükleme hatası: $e');
      // Hata durumunda boş map ile devam et
      _localizedStrings = {};
      return false;
    }
  }

  /// Verilen anahtara göre çeviri değerini döndür
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

/// LocalizationsDelegate implementation
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  /// Constructor
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Desteklenen dilleri kontrol et
    return LocaleConstants.supportedLocales
        .map((e) => e.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Yeni bir AppLocalizations instance'ı oluştur
    AppLocalizations localizations = AppLocalizations(locale);

    // Dil dosyasını yükle
    await localizations.load();

    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
