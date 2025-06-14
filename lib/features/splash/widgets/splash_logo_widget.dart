import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/color_scheme.dart';
import '../constants/splash_constants.dart';

/// Splash screen logo widget'ı
///
/// TatarAI uygulamasının splash screen'inde gösterilen
/// animasyonlu logo component'i. Clean Architecture
/// prensiplerine uygun olarak ayrı widget olarak tanımlanmıştır.
///
/// Özellikler:
/// - Constants kullanarak hardcoded değerlerden kaçınma
/// - Theme colors kullanımı
/// - Responsive design (constraints ile)
/// - Modern iOS stili tasarım
class SplashLogoWidget extends StatelessWidget {
  const SplashLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SplashConstants.logoSize,
      height: SplashConstants.logoSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary
              .withOpacity(SplashConstants.logoBackgroundOpacity),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.leaf_arrow_circlepath,
            color: AppColors.primary,
            size: SplashConstants.logoIconSize,
          ),
        ),
      ),
    );
  }
}
