import 'package:flutter/material.dart';

/// Kaydırma yönü
enum SwipeDirection { left, right, up, down }

/// iOS tarzı kaydırma hareketlerini algılayan widget
class SwipeDetector extends StatelessWidget {
  /// Kaydırma sonrası çağrılacak fonksiyon
  final Function(SwipeDirection) onSwipe;

  /// İçerik widget'ı
  final Widget child;

  /// Kaydırma sensitivitesi
  final double sensitivity;

  /// Yapıcı metod
  const SwipeDetector({
    super.key,
    required this.onSwipe,
    required this.child,
    this.sensitivity = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        // Sağa kaydırma (hız negatifse sola doğru, pozitifse sağa doğru)
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (velocity.abs() > sensitivity) {
          onSwipe(velocity > 0 ? SwipeDirection.right : SwipeDirection.left);
        }
      },
      onVerticalDragEnd: (details) {
        // Yukarı/aşağı kaydırma (yorumlanmayacak)
        final velocity = details.velocity.pixelsPerSecond.dy;
        if (velocity.abs() > sensitivity) {
          onSwipe(velocity > 0 ? SwipeDirection.down : SwipeDirection.up);
        }
      },
      child: child,
    );
  }
}

/// iOS stil kaydırma davranışlarını sekme için uygular
class TabSwipeNavigator extends StatelessWidget {
  /// Tab değiştirme fonksiyonu
  final Function(int) onChangeTab;

  /// Mevcut indeks
  final int currentIndex;

  /// Maksimum tab sayısı
  final int maxTabCount;

  /// İçerik widget'ı
  final Widget child;

  /// Yapıcı metod
  const TabSwipeNavigator({
    super.key,
    required this.onChangeTab,
    required this.currentIndex,
    required this.maxTabCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeDetector(
      onSwipe: (direction) {
        if (direction == SwipeDirection.left) {
          // Sonraki tab'a geç (sola kaydırınca)
          if (currentIndex < maxTabCount - 1) {
            onChangeTab(currentIndex + 1);
          }
        } else if (direction == SwipeDirection.right) {
          // Önceki tab'a geç (sağa kaydırınca)
          if (currentIndex > 0) {
            onChangeTab(currentIndex - 1);
          }
        }
      },
      child: child,
    );
  }
}
