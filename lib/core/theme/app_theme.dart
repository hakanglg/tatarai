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
      primaryColor: CupertinoColors.systemGrey,
      primaryContrastingColor: AppColors.onPrimary,
      barBackgroundColor: AppColors.background,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextTheme.cupertinoTextTheme,
      brightness: Brightness.light,
    );
  }

  /// Material temasını döndürür (gerekli olması durumunda)
  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: AppTextTheme.headline5,
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
          foregroundColor: AppColors.onPrimary,
          backgroundColor: AppColors.primary,
        ),
      ),
      textTheme: AppTextTheme.materialTextTheme,
      iconTheme: const IconThemeData(color: AppColors.primary, size: 24),
    );
  }

  /// CupertinoNavigationBar'da ikon rengi ve arka planı kolayca ayarlamak için yardımcı fonksiyon
  static CupertinoNavigationBar buildCupertinoNavigationBar({
    required Widget middle,
    Widget? leading,
    Widget? trailing,
    String? previousPageTitle,
    Color? backgroundColor,
  }) {
    return CupertinoNavigationBar(
      middle: middle,
      leading: leading,
      trailing: trailing,
      previousPageTitle: previousPageTitle,
      backgroundColor: backgroundColor ?? AppColors.background,
      border: const Border(
        bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
      ),
    );
  }
}
