import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'color_scheme.dart';

/// Uygulama genelinde kullanılacak metin stilleri
/// SF Pro Display fontunu kullanıyoruz, useGoogleFonts: false
class AppTextTheme {
  AppTextTheme._();

  // Font ailesi
  static const String _fontFamily = 'sfpro';

  // Metin renkleri
  static const Color _textColor = AppColors.textPrimary;
  static const Color _secondaryTextColor = AppColors.textSecondary;

  /// Görüntüye uygun olarak düzenlenmiş metin stilleri

  // Headline 1 (40pt)
  static const TextStyle headline1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: _textColor,
    letterSpacing: -0.5,
  );
  static TextStyle get displayLarge => headline1;

  // Large Title (34pt)
  static const TextStyle largeTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: _textColor,
    letterSpacing: -0.5,
  );
  static TextStyle get displayMedium => largeTitle;

  // Headline 2 (28pt)
  static const TextStyle headline2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: _textColor,
    letterSpacing: -0.5,
  );
  static TextStyle get displaySmall => headline2;

  // Headline 3 (22pt)
  static const TextStyle headline3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );
  static TextStyle get headlineMedium => headline3;

  // Headline 4 (20pt)
  static const TextStyle headline4 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );
  static TextStyle get headlineSmall => headline4;

  // Headline 5 (17pt)
  static const TextStyle headline5 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );
  static TextStyle get titleLarge => headline5;

  // Headline 6 (artık kullanılmayacak - yerine headlin5 kullanılacak)
  static TextStyle get headline6 => headline5;

  // Large Body (17pt)
  static const TextStyle largeBody = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.normal,
    color: _textColor,
  );
  static TextStyle get bodyLarge => largeBody;

  // Body (15pt)
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: _textColor,
  );
  static TextStyle get bodyMedium => body;

  // Eski bodyText1 ve bodyText2 stilleri artık daha küçük stillerimizle eşleştirilir
  static TextStyle get bodyText1 => largeBody;
  static TextStyle get bodyText2 => body;

  // Caption L (13pt)
  static const TextStyle captionL = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: _secondaryTextColor,
  );
  static TextStyle get titleMedium => captionL;

  // Small Caption (11pt)
  static const TextStyle smallCaption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: _secondaryTextColor,
  );
  static TextStyle get titleSmall => smallCaption;

  // Buton metni (15pt, medium weight)
  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
    letterSpacing: 0.5,
  );
  static TextStyle get labelLarge => button;

  // Eski caption stilinin smallCaption ile eşleştirilmesi
  static TextStyle get caption => captionL;

  // En küçük metin (11pt - small caption)
  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: _secondaryTextColor,
    letterSpacing: 0.5,
  );
  static TextStyle get labelSmall => overline;

  /// Material TextTheme - yeni stiller ile
  static TextTheme get materialTextTheme {
    return TextTheme(
      displayLarge: headline1,
      displayMedium: largeTitle,
      displaySmall: headline2,
      headlineMedium: headline3,
      headlineSmall: headline4,
      titleLarge: headline5,
      bodyLarge: largeBody,
      bodyMedium: body,
      titleMedium: captionL,
      titleSmall: smallCaption,
      labelLarge: button,
      bodySmall: smallCaption,
      labelSmall: overline,
    );
  }

  /// Cupertino TextTheme - yeni stiller ile
  static CupertinoTextThemeData get cupertinoTextTheme {
    return CupertinoTextThemeData(
      primaryColor: _textColor,
      textStyle: body,
      actionTextStyle: button,
      tabLabelTextStyle: smallCaption,
      navTitleTextStyle: headline5,
      navLargeTitleTextStyle: headline3,
      navActionTextStyle: button,
      pickerTextStyle: body,
      dateTimePickerTextStyle: body,
    );
  }
}
