import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';
import 'dart:io';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  final PaymentCubit _paymentCubit = PaymentCubit();

  @override
  void initState() {
    super.initState();
    _initPaywall();
  }

  @override
  void dispose() {
    _paymentCubit.close();
    super.dispose();
  }

  // Paywall'u hazırla
  Future<void> _initPaywall() async {
    try {
      setState(() => _isLoading = true);

      // RevenueCat konfigürasyonu doğru yapılmış mı kontrol et
      final isConfigured = await Purchases.isConfigured;
      if (!isConfigured) {
        // RevenueCat yapılandırılmamışsa, paymentCubit ile offerings'i çağırarak yapılandırılmasını sağla
        await _paymentCubit.fetchOfferings();
      }

      // StoreKit yapılandırma dosyasıyla çalışıyor muyuz kontrol et
      AppLogger.i('PremiumScreen: StoreKit yapılandırma dosyası kullanılıyor');

      // Doğrudan RevenueCat UI paywall'u göster
      await _showRevenueCatPaywall();
    } catch (e) {
      AppLogger.e('PremiumScreen: Offerings getirme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              'Ödeme paketleri yüklenirken bir hata oluştu: ${e.toString()}';
        });
      }
    }
  }

  // RevenueCat'in kendi paywall'unu göster
  Future<void> _showRevenueCatPaywall() async {
    setState(() => _isLoading = true);

    try {
      final entitlementID = AppConstants.entitlementId; // "premium"
      AppLogger.i('PremiumScreen: RevenueCat UI paywall gösteriliyor...');

      // Direct RevenueCat UI kullanımı - StoreKit yapılandırma dosyasıyla çalışacak
      try {
        final paywallResult =
            await RevenueCatUI.presentPaywallIfNeeded(entitlementID);
        AppLogger.i('PremiumScreen: RevenueCat UI sonucu: $paywallResult');

        // Satın alma başarılı olup olmadığını kontrol et
        final customerInfo = await Purchases.getCustomerInfo();
        final isPremium =
            customerInfo.entitlements.active.containsKey(entitlementID);

        if (isPremium && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Premium satın alma işlemi başarılı!')),
          );
          if (context.mounted) {
            context.pop();
          }
        }

        // Her durumda yükleme durumunu kapat
        if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (paywallError) {
        AppLogger.e('PremiumScreen: RevenueCat UI hatası: $paywallError');

        // RevenueCat UI başarısız olursa offerings ile manuel yaklaşımı dene
        final offerings = await _paymentCubit.fetchOfferings();

        if (offerings != null && offerings.current != null) {
          AppLogger.i(
              'PremiumScreen: Offerings başarıyla alındı, paketler manuel gösterilecek');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        } else {
          // Offerings de başarısız olursa hata durumunu güncelle
          throw Exception('RevenueCat UI ve manual offerings alınamadı');
        }
      }
    } catch (e) {
      AppLogger.e('PremiumScreen: RevenueCat işlemi hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              'Ödeme işlemi başlatılırken bir hata oluştu: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final bool isLoggedIn =
              authState.isAuthenticated && authState.user != null;
          AppLogger.d('PremiumScreen AuthCubit: isLoggedIn: $isLoggedIn');

          // Kullanıcı giriş yapmamışsa giriş seçeneklerini göster
          if (!isLoggedIn) {
            AppLogger.i(
                'PremiumScreen: Kullanıcı giriş yapmamış, _buildLoginSection gösteriliyor.');
            return _buildLoginSection(context);
          }

          // Yükleniyor durumu
          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ödeme seçenekleri yükleniyor...'),
                ],
              ),
            );
          }

          // Hata durumu
          if (_hasError) {
            return _buildErrorDisplay(context, () {
              AppLogger.i(
                  'PremiumScreen: Hata ekranından "Tekrar Dene" tıklandı.');
              setState(() => _isLoading = true);
              _initPaywall(); // Paywall'u tekrar başlat
            });
          }

          // Normal durum - RevenueCat UI paywall'unu göster butonu ve manuel butonlar
          return BlocBuilder<PaymentCubit, PaymentState>(
            bloc: _paymentCubit,
            builder: (context, state) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(context.dimensions.paddingM),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium, size: 80),
                      const SizedBox(height: 24),
                      Text(
                        'Premium paketlerimiz',
                        style: AppTextTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Premium özelliklerden yararlanmak için paketlerimizi inceleyebilirsiniz.',
                        style: AppTextTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // RevenueCat Paywall'unu direkt açan buton
                      AppButton(
                        text: 'Premium Satın Al',
                        onPressed: () => _showRevenueCatPaywall(),
                        type: AppButtonType.primary,
                        isFullWidth: true,
                      ),

                      const SizedBox(height: 24),
                      Text('veya', style: AppTextTheme.bodyLarge),
                      const SizedBox(height: 24),

                      // Eğer offerings varsa, mevcut tüm paketleri listele
                      if (state.offerings != null &&
                          state.offerings!.current != null &&
                          state
                              .offerings!.current!.availablePackages.isNotEmpty)
                        ..._buildPackageButtons(
                            state.offerings!.current!.availablePackages),

                      // Paketleri yenileme butonu
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Paketleri Yenile',
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _initPaywall();
                        },
                        type: AppButtonType.secondary,
                        isFullWidth: true,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Satın alma paketleri için butonlar oluştur
  List<Widget> _buildPackageButtons(List<Package> packages) {
    final List<Widget> buttons = [];

    for (var i = 0; i < packages.length; i++) {
      final package = packages[i];
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppButton(
            text:
                '${package.storeProduct.title} - ${package.storeProduct.priceString}',
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await _paymentCubit.purchasePackage(package);
                if (mounted) {
                  setState(() => _isLoading = false);

                  // Başarılı satın alma durumunu kontrol et
                  if (_paymentCubit.state.isPremium) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Premium satın alma işlemi başarılı!')),
                    );
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage =
                        'Satın alma işlemi sırasında bir hata oluştu.';
                  });
                }
              }
            },
            type: i == 0 ? AppButtonType.primary : AppButtonType.secondary,
            isFullWidth: true,
          ),
        ),
      );
    }

    return buttons;
  }

  // Giriş yapılmamış kullanıcılar için giriş/kayıt seçeneklerini gösteren bölüm
  Widget _buildLoginSection(BuildContext context) {
    final colorScheme = AppColors.colorScheme;
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
            _errorMessage ??
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
