import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'color_scheme.dart';
import 'text_theme.dart';

/// App genelinde kullanılacak tema ayarları
/// Apple Human Interface Guidelines ile uyumlu tasarım
class AppTheme {
  AppTheme._();

  /// Cupertino temasını döndürür
  static CupertinoThemeData get cupertinoTheme {
    return CupertinoThemeData(
      primaryColor: AppColors.primary,
      primaryContrastingColor: AppColors.white,
      barBackgroundColor: AppColors.white,
      scaffoldBackgroundColor: AppColors.white,
      textTheme: AppTextTheme.cupertinoTextTheme,
      brightness: Brightness.light,
    );
  }

  /// Açık tema için ColorScheme
  static final ColorScheme lightColorScheme = AppColors.colorScheme;

  /// Koyu tema için ColorScheme
  static final ColorScheme darkColorScheme = AppColors.colorScheme.copyWith(
    brightness: Brightness.dark,
    background: Colors.grey[900]!,
    surface: Colors.grey[850]!,
    onBackground: Colors.white,
    onSurface: Colors.white,
  );

  /// Material temasını döndürür (gerekli olması durumunda)
  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      fontFamily: 'sfpro',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: lightColorScheme.onPrimary,
          backgroundColor: lightColorScheme.primary,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightColorScheme.primary,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
