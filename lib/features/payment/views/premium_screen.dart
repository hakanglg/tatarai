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
      create: (context) {
        AppLogger.i(
            'PremiumScreen: PaymentCubit oluşturuluyor ve fetchOfferings çağrılıyor.');
        return PaymentCubit()..fetchOfferings();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Premium'),
          centerTitle: true,
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final bool isLoggedIn =
                authState.isAuthenticated && authState.user != null;
            AppLogger.d('PremiumScreen AuthCubit: isLoggedIn: $isLoggedIn');

            return BlocBuilder<PaymentCubit, PaymentState>(
              builder: (context, paymentState) {
                AppLogger.d(
                    'PremiumScreen PaymentCubit: isLoading: ${paymentState.isLoading}, hasError: ${paymentState.hasError}, offerings: ${paymentState.offerings?.current?.identifier}');

                if (paymentState.isLoading && paymentState.offerings == null) {
                  AppLogger.i(
                      'PremiumScreen: İlk yükleme, CircularProgressIndicator gösteriliyor.');
                  return const Center(child: CircularProgressIndicator());
                }

                if (!isLoggedIn) {
                  AppLogger.i(
                      'PremiumScreen: Kullanıcı giriş yapmamış, _buildLoginSection gösteriliyor.');
                  return _buildLoginSection(context);
                }

                // PaymentCubit'teki _useMockData aktifse ve offerings null ise bu bir sorundur.
                // Veya _useMockData false ama yine de hata varsa.
                // Mock data özelliği kaldırıldığı için direkt hata durumunu kontrol ediyoruz
                if (paymentState.hasError || paymentState.offerings == null) {
                  AppLogger.w(
                      'PremiumScreen: Hata durumu. Hata: ${paymentState.hasError}, OfferingsNull: ${paymentState.offerings == null}');
                  return _buildErrorDisplay(context, () {
                    AppLogger.i(
                        'PremiumScreen: Hata ekranından "Tekrar Dene" tıklandı.');
                    context.read<PaymentCubit>().fetchOfferings();
                  });
                }

                AppLogger.i('PremiumScreen: PaywallView gösteriliyor.');
                return PaywallView(
                  offering: paymentState.offerings
                      ?.current, // Her zaman state'teki offering'i kullan
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Giriş yapılmamış kullanıcılar için giriş/kayıt seçeneklerini gösteren bölüm
  Widget _buildLoginSection(BuildContext context) {
    final colorScheme = AppColors.colorScheme;
    // Bu fonksiyon önceki versiyondan alındı ve hala geçerli.
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: colorScheme.primary),
          SizedBox(height: context.dimensions.spaceL),
          Text(
            'Premium özelliklere erişmek ve satın alma yapmak için lütfen giriş yapın.',
            textAlign: TextAlign.center,
            style: AppTextTheme.titleMedium,
          ),
          SizedBox(height: context.dimensions.spaceXL),
          AppButton(
            text: 'Giriş Yap',
            onPressed: () {
              context.goNamed(RouteNames.login);
              AppLogger.i(
                  'Premium ekranından login sayfasına yönlendirme yapıldı');
            },
            isFullWidth: true,
            type: AppButtonType.primary,
          ),
          SizedBox(height: context.dimensions.spaceM),
          AppButton(
            text: 'Hesap Oluştur',
            onPressed: () {
              context.goNamed(RouteNames.register);
              AppLogger.i(
                  'Premium ekranından kayıt sayfasına yönlendirme yapıldı');
            },
            isFullWidth: true,
            type: AppButtonType.secondary,
          ),
        ],
      ),
    );
  }

  // Paketler yüklenirken genel bir hata oluştuğunda gösterilecek bölüm
  Widget _buildErrorDisplay(BuildContext context, VoidCallback onRetry) {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 60, color: Theme.of(context).colorScheme.error),
          SizedBox(height: context.dimensions.spaceL),
          Text(
            'Premium paketler yüklenirken bir sorun oluştu.',
            textAlign: TextAlign.center,
            style: AppTextTheme.titleMedium,
          ),
          SizedBox(height: context.dimensions.spaceS),
          Text(
            'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin. Sorun devam ederse destek ekibimizle iletişime geçebilirsiniz.',
            textAlign: TextAlign.center,
            style: AppTextTheme.bodyMedium,
          ),
          SizedBox(height: context.dimensions.spaceXL),
          AppButton(
            text: 'Tekrar Dene',
            onPressed: onRetry,
            type: AppButtonType.primary,
          ),
        ],
      ),
    );
  }
}
