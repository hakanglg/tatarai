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
  static const Color _textColor = AppColors.onBackground;
  static const Color _secondaryTextColor = Color(0xFF6B6B6B);

  // Material stil tanımları
  static const TextStyle headline1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: _textColor,
    letterSpacing: -0.5,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: _textColor,
    letterSpacing: -0.5,
  );

  static const TextStyle headline3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );

  static const TextStyle headline4 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );

  static const TextStyle headline5 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );

  static const TextStyle headline6 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: _textColor,
    letterSpacing: -0.25,
  );

  static const TextStyle bodyText1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: _textColor,
  );

  static const TextStyle bodyText2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: _textColor,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: .16,
    fontWeight: FontWeight.w500,
    color: _textColor,
  );

  static const TextStyle subtitle2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _secondaryTextColor,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: _secondaryTextColor,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: _secondaryTextColor,
    letterSpacing: 0.5,
  );

  /// Material TextTheme
  static TextTheme get materialTextTheme {
    return const TextTheme(
      displayLarge: headline1,
      displayMedium: headline2,
      displaySmall: headline3,
      headlineMedium: headline4,
      headlineSmall: headline5,
      titleLarge: headline6,
      bodyLarge: bodyText1,
      bodyMedium: bodyText2,
      titleMedium: subtitle1,
      titleSmall: subtitle2,
      labelLarge: button,
      bodySmall: caption,
      labelSmall: overline,
    );
  }

  /// Cupertino TextTheme
  static CupertinoTextThemeData get cupertinoTextTheme {
    return const CupertinoTextThemeData(
      primaryColor: _textColor,
      textStyle: bodyText1,
      actionTextStyle: button,
      tabLabelTextStyle: caption,
      navTitleTextStyle: headline6,
      navLargeTitleTextStyle: headline4,
      navActionTextStyle: button,
      pickerTextStyle: bodyText1,
      dateTimePickerTextStyle: bodyText1,
    );
  }
}
