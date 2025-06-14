import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../payment/cubits/payment_cubit.dart';

/// Sade Premium Card Widget'ı
///
/// Minimal tasarım ile premium özellikleri tanıtan
/// küçük boyutlu card component'i.
///
/// Özellikler:
/// - Minimal tasarım
/// - Modern gradient tasarım
/// - Premium özellikleri listesi
/// - Call-to-action button
/// - Apple HIG uyumlu animasyonlar
/// - Theme colors kullanımı
class HomePremiumCard extends StatelessWidget {
  final VoidCallback? onPremiumPurchased;

  const HomePremiumCard({
    super.key,
    this.onPremiumPurchased,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, paymentState) {
        // Premium kullanıcı ise card'ı gizle
        if (paymentState.isPremium) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: context.dimensions.paddingM,
            vertical: context.dimensions.paddingXS,
          ),
          child: _buildPremiumCard(context, paymentState),
        );
      },
    );
  }

  /// Premium card oluşturur
  Widget _buildPremiumCard(BuildContext context, PaymentState paymentState) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Arka plan resmi
            Positioned.fill(
              child: Image.asset(
                'assets/images/background.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primary.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: EdgeInsets.all(context.dimensions.paddingM),
              child: Row(
                children: [
                  // Sol taraf - Icon ve bilgi
                  Expanded(
                    child: Row(
                      children: [
                        // Premium icon
                        Container(
                          padding: EdgeInsets.all(context.dimensions.paddingS),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.star_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        SizedBox(width: context.dimensions.spaceM),

                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Premium\'a Geç',
                                style: AppTextTheme.bodyText1.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sınırsız analiz ve gelişmiş özellikler',
                                style: AppTextTheme.bodyText2.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: context.dimensions.spaceS),

                  // Sağ taraf - CTA button
                  _buildCTAButton(context, paymentState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CTA button oluşturur
  Widget _buildCTAButton(BuildContext context, PaymentState paymentState) {
    final isLoading = paymentState.isLoading;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : () => _handlePremiumPurchase(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.dimensions.paddingM,
          vertical: context.dimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Keşfet',
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: context.dimensions.spaceXS),
                  Icon(
                    CupertinoIcons.arrow_right,
                    color: AppColors.primary,
                    size: 14,
                  ),
                ],
              ),
      ),
    );
  }

  /// Premium satın alma işlemini başlatır
  Future<void> _handlePremiumPurchase(BuildContext context) async {
    try {
      AppLogger.i('Premium card tıklandı');

      // PaymentCubit üzerinden offerings getir
      final paymentCubit = context.read<PaymentCubit>();
      final offerings = await paymentCubit.fetchOfferings();

      if (offerings?.current?.availablePackages.isNotEmpty == true) {
        // İlk paketi satın al
        final package = offerings!.current!.availablePackages.first;
        await paymentCubit.purchasePackage(package);

        // Başarılı satın alma durumunda callback çağır
        if (onPremiumPurchased != null) {
          onPremiumPurchased!();
        }
      } else {
        AppLogger.w('Premium paketleri bulunamadı');
      }

      AppLogger.i('Premium satın alma işlemi tamamlandı');
    } catch (e, stackTrace) {
      AppLogger.e('Premium satın alma hatası', e, stackTrace);
    }
  }
}

/// Premium özellik modeli
class PremiumFeature {
  final IconData icon;
  final String title;
  final String description;

  const PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
