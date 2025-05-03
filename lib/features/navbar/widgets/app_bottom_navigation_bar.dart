import 'package:flutter/cupertino.dart';
import 'package:tatarai/core/theme/color_scheme.dart';

/// Navbar öğeleri için bilgileri içeren sınıf
/// iOS stil CupertinoTabBar wrapper'ı
class AppBottomNavigationBar extends CupertinoTabBar {
  /// Özelleştirilmiş TabBar yapıcı metodu
  const AppBottomNavigationBar({
    super.key,
    required super.currentIndex,
    required Function(int) onTabSelected,
    required super.items,
    super.height = 54.0, // iOS standart yüksekliği
    super.iconSize = 26.0, // iOS standart ikon boyutu
    Color super.activeColor = AppColors.primary,
    super.inactiveColor = AppColors.textSecondary,
    super.backgroundColor = AppColors.white,
  }) : super(
          onTap: onTabSelected,
          border: const Border(
            top: BorderSide(
              color: AppColors.divider,
              width: 0.3, // iOS'daki ince separator çizgisi
            ),
          ),
        );
}
