import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Uygulama genelinde kullanılacak yükleme ekranı.
/// assets/animations/loading.json Lottie animasyonunu kullanır.
class LoadingView extends StatelessWidget {
  /// Animasyonun boyutu
  final double? size;

  /// Arka plan rengi (varsayılan: yarı saydam siyah)
  final Color? backgroundColor;

  /// Tam ekran kaplamak isteniyorsa true olarak ayarlayın
  final bool isFullScreen;

  /// LoadingView için yapıcı metod
  const LoadingView({
    super.key,
    this.size = 120,
    this.backgroundColor,
    this.isFullScreen = false,
  });

  /// Tam ekran gösteren bir LoadingView döndürür
  static Widget fullScreen() {
    return const LoadingView(isFullScreen: true);
  }

  /// Uygulamaya yükleme ekranı eklemek için kullanılır
  static Future<void> show(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingView(isFullScreen: true),
    );
  }

  /// Uygulamadan yükleme ekranını kapatmak için kullanılır
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget lottieAnimation = Lottie.asset(
      'assets/animations/loading.json',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (isFullScreen) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          color: backgroundColor ?? Colors.transparent,
          child: Center(
            child: lottieAnimation,
          ),
        ),
      );
    }

    return Center(
      child: lottieAnimation,
    );
  }
}
