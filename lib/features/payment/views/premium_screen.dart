import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentCubit()..fetchOfferings(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Premium'),
          centerTitle: true,
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            // Kullanıcı giriş yapmış mı kontrol et
            final bool isLoggedIn =
                authState.isAuthenticated && authState.user != null;

            return BlocBuilder<PaymentCubit, PaymentState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Paketler yüklenirken bir hata oluştu.'),
                        SizedBox(height: context.dimensions.spaceM),
                        AppButton(
                          text: "Tekrar Dene",
                          width: AppDimensions(context).screenWidth * 0.5,
                          onPressed: () {
                            context.read<PaymentCubit>().fetchOfferings();
                          },
                        )
                      ],
                    ),
                  );
                }

                final offerings = state.offerings;

                if (offerings == null || offerings.current == null) {
                  return const Center(
                    child: Text('Şu anda satın alma paketleri mevcut değil.'),
                  );
                }

                // RevenueCat UI kullanıyoruz
                if (state.isProcessingPurchase) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _PremiumContent(
                  offerings: offerings,
                  remainingAnalyses: state.remainingFreeAnalyses,
                  isLoggedIn: isLoggedIn, // Login durumunu aktarıyoruz
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PremiumContent extends StatelessWidget {
  final Offerings offerings;
  final int remainingAnalyses;
  final bool isLoggedIn;

  const _PremiumContent({
    required this.offerings,
    required this.remainingAnalyses,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst kısım - Premium açıklaması ve Kalan analizler
          Padding(
            padding: EdgeInsets.all(context.dimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                SizedBox(height: context.dimensions.spaceL),
                _buildRemainingAnalyses(context),
                SizedBox(height: context.dimensions.spaceL),
                _buildPremiumButton(context),

                // Login olmamış kullanıcılar için login seçenekleri
                if (!isLoggedIn) ...[
                  SizedBox(height: context.dimensions.spaceXL),
                  _buildLoginSection(context),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Login olmamış kullanıcılar için giriş/kayıt seçeneklerini gösteren bölüm
  Widget _buildLoginSection(BuildContext context) {
    final colorScheme = AppColors.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Divider(color: colorScheme.outlineVariant),
        SizedBox(height: context.dimensions.spaceM),

        Text(
          'Premium satın almak için hesabınıza giriş yapmanız gerekiyor',
          textAlign: TextAlign.center,
          style: AppTextTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: context.dimensions.spaceM),

        // Giriş yap butonu
        AppButton(
          text: 'Giriş Yap',
          onPressed: () {
            // Login ekranına yönlendir
            context.goNamed(RouteNames.login);
            AppLogger.i(
                'Premium ekranından login sayfasına yönlendirme yapıldı');
          },
          isFullWidth: true,
          type: AppButtonType.secondary,
        ),

        SizedBox(height: context.dimensions.spaceM),

        // Kayıt ol butonu
        AppButton(
          text: 'Hesap Oluştur',
          onPressed: () {
            // Register ekranına yönlendir
            context.goNamed(RouteNames.register);
            AppLogger.i(
                'Premium ekranından kayıt sayfasına yönlendirme yapıldı');
          },
          isFullWidth: true,
          type: AppButtonType.primary,
        ),
      ],
    );
  }

  Widget _buildPremiumButton(BuildContext context) {
    final colorScheme = AppColors.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showPaywall(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: EdgeInsets.symmetric(vertical: context.dimensions.paddingM),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          ),
        ),
        child: Text(
          'Premium Paketleri Görüntüle',
          style: AppTextTheme.button.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context) async {
    // Login olmamış kullanıcı kontrol - eğer giriş yapmadıysa uyar ve durdur
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium satın almak için önce giriş yapmalısınız'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final result = await RevenueCatUI.presentPaywall(
        offering: offerings.current!,
      );

      // Satın alma sonucunu işle
      switch (result) {
        case PaywallResult.purchased:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satın alma başarılı!')),
          );
          break;
        case PaywallResult.restored:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satın alma geri yüklendi!')),
          );
          break;
        case PaywallResult.cancelled:
          // Kullanıcı satın alma işlemini iptal etti, bir şey yapmaya gerek yok
          break;
        default:
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TatarAI Premium',
          style: AppTextTheme.headline3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Yapay zeka analizlerine sınırsız erişim elde et',
          style: AppTextTheme.captionL,
        ),
      ],
    );
  }

  Widget _buildRemainingAnalyses(BuildContext context) {
    final colorScheme = AppColors.colorScheme;

    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: context.dimensions.iconSizeL,
            color: colorScheme.onPrimaryContainer,
          ),
          SizedBox(width: context.dimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kalan Ücretsiz Analizler',
                  style: AppTextTheme.body.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  remainingAnalyses > 0
                      ? '$remainingAnalyses analiz hakkınız kaldı'
                      : 'Ücretsiz analiz hakkınız kalmadı',
                  style: AppTextTheme.captionL.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
