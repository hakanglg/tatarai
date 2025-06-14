import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılacak renk paleti
class AppColors {
  AppColors._();

  // Ana renkler
  static const Color primary = Color(0xFF2E7D32); // Yeşil
  static const Color white = Color(0xFFFFFFFF); // Beyaz
  static const Color black = Color(0xFF080808); // Siyah

  // Metin renkleri
  static const Color onPrimary = white;
  static const Color onSecondary = black;
  static const Color onBackground = black;
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF666666); // Gri tonu
  static const Color textTertiary = Color(0xFF999999); // Açık gri tonu

  // Arka plan renkleri
  static const Color background = white;
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Çok açık gri

  // Durum renkleri
  static const Color error = Color(0xFFB00020);
  static const Color success = primary;
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
      secondary: primary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: onBackground,
      error: error,
      onError: onPrimary,
      brightness: Brightness.light,
      outline: divider,
      outlineVariant: disabled,
      tertiary: primary,
      onTertiary: onSecondary,
    );
  }
}
