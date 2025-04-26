import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../theme/app_text_styles.dart';
import '../theme/color_scheme.dart';

/// Buton tipleri
enum AppButtonType {
  /// Ana buton - yeşil arka plan, beyaz metin
  primary,

  /// İkincil buton - beyaz arka plan, yeşil metin
  secondary,

  /// Tehlikeli işlem butonu - kırmızı arka plan, beyaz metin
  destructive,

  /// Text buton - transparan arka plan, yeşil metin
  text,
}

/// Uygulama genelinde kullanılacak standart buton bileşeni
/// Tüm uygulamada tutarlı görünüm sağlar
class AppButton extends StatelessWidget {
  /// Buton metni
  final String text;

  /// Butona tıklandığında çalışacak işlev
  final VoidCallback? onPressed;

  /// Buton tipi (primary, secondary, destructive)
  final AppButtonType type;

  /// Yükleniyor göstergesi
  final bool isLoading;

  /// Butonun tam genişlikte olup olmayacağı
  final bool isFullWidth;

  /// Buton metni yanında gösterilecek ikon (opsiyonel)
  final IconData? icon;

  /// Buton yüksekliği
  final double height;

  /// Buton içi dolgu boşluğu
  final EdgeInsets? padding;

  /// Yapıcı metot
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = 48.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = CupertinoButton(
      padding: padding ?? EdgeInsets.zero,
      onPressed: isLoading ? null : onPressed,
      color: _getBackgroundColor(),
      disabledColor: _getBackgroundColor().withOpacity(0.5),
      borderRadius: BorderRadius.circular(10),
      child: _buildContent(),
    );

    Widget finalButton = buttonChild;

    // Secondary butona kenarlık ekle
    if (type == AppButtonType.secondary) {
      finalButton = Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: buttonChild,
      );
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: finalButton,
      );
    } else {
      // Esnek olmayan mod - sadece içeriği kadar genişlikte
      return SizedBox(height: height, child: finalButton);
    }
  }

  /// Buton içeriğini oluşturur
  Widget _buildContent() {
    if (isLoading) {
      return CupertinoActivityIndicator(color: _getTextColor());
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _getTextColor(), size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.buttonText.copyWith(color: _getTextColor()),
          ),
        ],
      );
    }

    return Text(
      text,
      style: AppTextStyles.buttonText.copyWith(color: _getTextColor()),
    );
  }

  /// Buton tipine göre arkaplan rengini döndürür
  Color _getBackgroundColor() {
    switch (type) {
      case AppButtonType.primary:
        return AppColors.primary;
      case AppButtonType.secondary:
        return AppColors.surface;
      case AppButtonType.destructive:
        return AppColors.error;
      case AppButtonType.text:
        return Colors.transparent;
    }
  }

  /// Buton tipine göre metin rengini döndürür
  Color _getTextColor() {
    switch (type) {
      case AppButtonType.primary:
        return AppColors.onPrimary;
      case AppButtonType.secondary:
        return AppColors.primary;
      case AppButtonType.destructive:
        return AppColors.onPrimary;
      case AppButtonType.text:
        return AppColors.primary;
    }
  }
}

/* 
// Örnek Kullanım:
Row(
  children: [
    // Primary Buton
    AppButton(
      text: 'Primary',
      onPressed: () {},
      type: AppButtonType.primary,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Secondary Buton
    AppButton(
      text: 'Secondary',
      onPressed: () {},
      type: AppButtonType.secondary,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Destructive Buton
    AppButton(
      text: 'Destructive',
      onPressed: () {},
      type: AppButtonType.destructive,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Text Buton
    AppButton(
      text: 'Text',
      onPressed: () {},
      type: AppButtonType.text,
      isFullWidth: false,
    ),
  ],
)
*/
