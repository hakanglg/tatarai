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

  /// Material temasını döndürür (gerekli olması durumunda)
  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.colorScheme,
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: AppTextTheme.headlineMedium,
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary,
        ),
      ),
      textTheme: AppTextTheme.materialTextTheme,
      iconTheme: const IconThemeData(color: AppColors.primary, size: 24),
    );
  }
}
