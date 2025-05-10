import 'package:flutter/material.dart';
import 'package:tatarai/core/init/localization/language_manager.dart';

/// String sınıfı için ek özellikler
extension StringLocalization on String {
  /// Bu string'i mevcut dile çevirir
  ///
  /// Örnek kullanım:
  /// ```dart
  /// "hello_world".locale(context)
  /// ```
  String locale(BuildContext context) {
    try {
      final appLocalizations = AppLocalizations.of(context);
      return appLocalizations?.translate(this) ?? this;
    } catch (e) {
      return this; // Hata durumunda orijinal string'i döndür
    }
  }

  /// Capitalize ilk harfi büyük yapar
  String get capitalize {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  /// Tüm kelimelerin ilk harflerini büyük yapar
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// HTML etiketlerini kaldırır
  String get removeHtml {
    return replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// String içindeki her alt stringi yeni bir string ile değiştirir
  String replaceAll(Pattern from, String replace) {
    return this.replaceAll(from, replace);
  }
}
