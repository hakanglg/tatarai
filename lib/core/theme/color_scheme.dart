import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılacak renk paleti
class AppColors {
  AppColors._();

  // Ana renkler - Çiftçi temasına uygun yeşil tonları
  static const Color primary = Color(0xFF2E7D32); // Koyu yeşil
  static const Color secondary = Color(0xFF66BB6A); // Açık yeşil
  static const Color tertiary = Color(0xFFA5D6A7); // Çok açık yeşil

  // Metin renkleri
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color.fromARGB(255, 146, 144, 144);
  static const Color onBackground = Color(0xFF1C1C1E);
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color black = Color(0xFF000000);

  // Arka plan renkleri
  static const Color background = Color(0xFFF9F9F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFECEFF1);

  // Durum renkleri
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF0288D1);

  // Diğer renkler
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color border = Color(0xFFE0E0E0);

  /// Material 3 renk şeması
  static ColorScheme get colorScheme {
    return const ColorScheme(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: onBackground,
      error: error,
      onError: onPrimary,
      brightness: Brightness.light,
      outline: divider,
      outlineVariant: disabled,
      tertiary: tertiary,
      onTertiary: onSecondary,
    );
  }
}
