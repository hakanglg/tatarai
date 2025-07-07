import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/settings/cubits/settings_cubit.dart';
import 'package:tatarai/features/settings/cubits/settings_state.dart';
import 'package:tatarai/features/settings/widgets/simple_language_picker.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/routing/route_paths.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/services/firestore/firestore_service.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:tatarai/core/utils/revenuecat_debug_helper.dart';
import 'package:tatarai/core/extensions/context_extensions.dart';
import 'package:tatarai/core/services/paywall_manager.dart';
import 'package:tatarai/core/services/permission_service.dart';
import '../cubits/language_cubit.dart';
import '../../payment/cubits/payment_cubit.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';

/// Uygulama ayarları ekranı
/// Apple Human Interface Guidelines'a uygun modern tasarım
class SettingsScreen extends StatefulWidget {
  /// Constructor
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // App lifecycle observer ekle
    WidgetsBinding.instance.addObserver(this);

    // PaymentCubit'ten kullanıcı bilgilerini yenile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paymentCubit = context.read<PaymentCubit>();
      paymentCubit.refreshCustomerInfo();
      AppLogger.i('Settings: PaymentCubit refresh customer info tetiklendi');
    });
  }

  @override
  void dispose() {
    // App lifecycle observer'ı kaldır
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLogger.i('📱 SettingsScreen - App lifecycle değişti: $state');

    if (state == AppLifecycleState.resumed) {
      // Kullanıcı permission settings'den geri döndü, state'i refresh et
      AppLogger.i('🔄 SettingsScreen resumed - refreshing state');
      _handleAppResume();
    }
  }

  /// App resume olduğunda çalışacak handler
  void _handleAppResume() {
    if (!mounted) return;

    try {
      // State'i refresh et
      setState(() {
        // UI'ı force update et
      });

      AppLogger.i('✅ SettingsScreen resume handling tamamlandı');
    } catch (e) {
      AppLogger.e('❌ SettingsScreen resume handling hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // AuthCubit'i context'den al
    final authCubit = BlocProvider.of<AuthCubit>(context, listen: false);

    return BlocProvider(
      create: (context) =>
          SettingsCubit(authCubit: authCubit)..refreshUserData(),
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            'settings'.locale(context),
            style: AppTextTheme.headline6.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          border: null,
          transitionBetweenRoutes: false,
        ),
        child: SafeArea(
          child: BlocListener<SettingsCubit, SettingsState>(
            listener: (context, state) {
              // Hesap silme işlemi başarılı ise AuthCubit'den logout et
              if (state.hasSuccess) {
                // Başarı mesajını göster
                _showAccountDeletedDialog(context);
              }
            },
            child: BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  );
                }

                if (state.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.dimensions.paddingL),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: CupertinoColors.systemRed,
                            size: 50,
                          ),
                          SizedBox(height: context.dimensions.spaceM),
                          Text(
                            'error_occurred'.locale(context),
                            style: AppTextTheme.headline5.copyWith(
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: context.dimensions.spaceS),
                          Text(
                            state.errorMessage!,
                            style: AppTextTheme.bodyText1.copyWith(
                              color: CupertinoColors.systemGrey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final user = state.user;
                if (user == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.gear_alt,
                          size: 48,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(height: context.dimensions.spaceM),
                        Text(
                          'not_logged_in'.locale(context),
                          style: AppTextTheme.headline6
                              .copyWith(color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.all(context.dimensions.paddingL),
                  children: [
                    // Üyelik Bilgileri Kartı - PaymentState ile birleştir
                    BlocBuilder<PaymentCubit, PaymentState>(
                      builder: (context, paymentState) {
                        // RevenueCat'den gerçek premium durumunu al
                        final isActuallyPremium = paymentState.isPremium;
                        // final isActuallyPremium = true;

                        AppLogger.d(
                            'Settings: User premium status: ${user.isPremium}');
                        AppLogger.d(
                            'Settings: RevenueCat premium status: $isActuallyPremium');

                        // RevenueCat verisi yoksa Firestore'dan kullan
                        final effectivePremiumStatus = isActuallyPremium;

                        // Güncellenmiş user modelini oluştur (RevenueCat verisi ile)
                        final effectiveUser =
                            user.copyWith(isPremium: effectivePremiumStatus);

                        return _buildMembershipCard(
                            effectiveUser, paymentState);
                      },
                    ),

                    SizedBox(height: context.dimensions.spaceL),

                    // Ayarlar
                    _buildSettingsSection(context),

                    SizedBox(height: context.dimensions.spaceL),

                    // // Debug Bölümü (sadece debug modda)
                    // if (kDebugMode) ...[
                    //   _buildDebugSection(context),
                    //   SizedBox(height: context.dimensions.spaceL),
                    // ],

                    // Hesap İşlemleri
                    _buildAccountSection(context),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Üyelik bilgilerini gösteren kart - Modern Apple tasarımı
  Widget _buildMembershipCard(UserModel user, PaymentState paymentState) {
    final bool isPremium = user.isPremium;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPremium
                  ? [
                      const Color(
                          0xFF0F172A), // Slate 900 - Profesyonel koyu mavi
                      const Color(0xFF1E293B), // Slate 800 - Orta ton
                      const Color(0xFF334155), // Slate 700 - Açık ton
                    ]
                  : [
                      const Color(0xFF1a1a1a),
                      const Color(0xFF2d2d2d),
                      const Color(0xFF1a1a1a),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Ana içerik
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header kısmı
                    Row(
                      children: [
                        // Avatar ve status badge container
                        Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isPremium
                                    ? CupertinoIcons.star_fill
                                    : CupertinoIcons.person_crop_circle,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            // Premium crown badge
                            if (isPremium)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                        0xFF059669), // Emerald yeşil
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.star_fill,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Üyelik bilgileri
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPremium
                                    ? 'premium_account'.locale(context)
                                    : 'free_account'.locale(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPremium
                                    ? 'unlimited_analysis'.locale(context)
                                    : 'limited_access'.locale(context),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Premium tag
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF059669),
                                  Color(0xFF047857)
                                ], // Emerald gradient - profesyonel yeşil
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'PREMIUM',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Analiz kredisi ve progress kısmı
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  CupertinoIcons.graph_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'remaining_analysis'.locale(context),
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPremium
                                          ? 'unlimited_text'.locale(context)
                                          : '${'remaining_text'.locale(context)}: ${user.analysisCredits}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Büyük kredi sayısı veya infinity
                              Text(
                                isPremium ? '∞' : '${user.analysisCredits}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),

                          // Progress bar (sadece free kullanıcılar için)
                          if (!isPremium) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: user.analysisCredits /
                                      5.0, // 5 maksimum varsayıyoruz
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    user.analysisCredits > 2
                                        ? const Color(0xFF4CAF50)
                                        : user.analysisCredits > 0
                                            ? const Color(0xFFFF9800)
                                            : const Color(0xFFF44336),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action button
                    if (!isPremium) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            try {
                              AppLogger.i(
                                  'Settings ekranından premium buton tıklandı');

                              final result = await PaywallManager.showPaywall(
                                context,
                                displayCloseButton: true,
                                onPremiumPurchased: () {
                                  AppLogger.i(
                                      'Settings ekranından premium satın alındı - callback çağrıldı');

                                  // Success message göster
                                  if (context.mounted) {
                                    PaywallManager.showSuccessMessage(
                                        context,
                                        'premium_purchase_success'
                                            .locale(context));

                                    // Settings sayfasını yenile
                                    final settingsCubit =
                                        context.read<SettingsCubit>();
                                    settingsCubit.refreshUserData();
                                    AppLogger.i(
                                        'Settings: Sayfa yenilendi - premium satın alma sonrası');
                                  }
                                },
                                onError: (error) {
                                  AppLogger.e(
                                      'Settings premium button hatası: $error');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'paywall_error'.locale(context)),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                onCancelled: () {
                                  AppLogger.i('Settings: Paywall iptal edildi');
                                },
                              );

                              AppLogger.i('Settings: Paywall sonucu: $result');
                            } catch (e) {
                              AppLogger.e(
                                  'Settings premium paywall hatası: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('paywall_error'.locale(context)),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.sparkles,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'upgrade_to_premium'.locale(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Premium kullanıcılar için status indicator
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: Color(0xFF4CAF50),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'premium_active_status'.locale(context),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Debug bilgisi (sadece debug modda ve premium kullanıcılar için)
                    // if (kDebugMode &&
                    //     isPremium &&
                    //     paymentState.customerInfo != null) ...[
                    //   const SizedBox(height: 12),
                    //   Container(
                    //     padding: const EdgeInsets.all(12),
                    //     decoration: BoxDecoration(
                    //       color: Colors.white.withValues(alpha: 0.08),
                    //       borderRadius: BorderRadius.circular(8),
                    //     ),
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Text(
                    //           '🔧 Debug: RevenueCat Status',
                    //           style: TextStyle(
                    //             color: Colors.white.withValues(alpha: 0.7),
                    //             fontSize: 11,
                    //             fontWeight: FontWeight.w500,
                    //           ),
                    //         ),
                    //         if (paymentState.customerInfo!.entitlements.active
                    //             .isNotEmpty) ...[
                    //           const SizedBox(height: 4),
                    //           Text(
                    //             'Entitlements: ${paymentState.customerInfo!.entitlements.active.keys.join(', ')}',
                    //             style: TextStyle(
                    //               color: Colors.white.withValues(alpha: 0.6),
                    //               fontSize: 10,
                    //             ),
                    //           ),
                    //         ],
                    //       ],
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Genel ayarlar bölümü
  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader('app_settings'.locale(context)),
          _buildSettingsItem(
            icon: CupertinoIcons.globe,
            title: 'language'.locale(context),
            subtitle: _getCurrentLanguageName(context),
            onTap: () => _showLanguageSelection(context),
          ),
          _buildDebugSection(context)
        ],
      ),
    );
  }

  /// Hesap işlemleri bölümü
  Widget _buildAccountSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader('account'.locale(context)),
          _buildSettingsItem(
            icon: CupertinoIcons.delete,
            iconColor: CupertinoColors.systemRed,
            title: 'delete_account_title'.locale(context),
            subtitle: 'delete_account_subtitle'.locale(context),
            onTap: () => _showDeleteAccountDialog(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Bölüm başlığı
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.spaceS,
        bottom: context.dimensions.spaceXS,
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextTheme.overline.copyWith(
              color: CupertinoColors.systemGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Ayar öğesi
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isLast = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.dimensions.paddingM,
          vertical: context.dimensions.paddingS,
        ),
        decoration: BoxDecoration(
          border: !isLast
              ? const Border(
                  bottom: BorderSide(
                    color: CupertinoColors.systemGrey6,
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 18,
              ),
            ),
            SizedBox(width: context.dimensions.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextTheme.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextTheme.caption.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey3,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Mevcut dil adını al
  String _getCurrentLanguageName(BuildContext context) {
    final currentLocale = LocalizationManager.instance.currentLocale;
    switch (currentLocale.languageCode) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      default:
        return 'English';
    }
  }

  /// Dil seçenekleri listesi
  Widget _buildLanguageOptions(BuildContext context) {
    final currentLocale = LocalizationManager.instance.currentLocale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLanguageOption(
          context: context,
          flag: '🇹🇷',
          title: 'Türkçe',
          subtitle: 'Türkiye',
          isSelected: currentLocale.languageCode == 'tr',
          onTap: () => _changeLanguage(context, 'tr'),
        ),
        const SizedBox(height: 12),
        _buildLanguageOption(
          context: context,
          flag: '🇺🇸',
          title: 'English',
          subtitle: 'United States',
          isSelected: currentLocale.languageCode == 'en',
          onTap: () => _changeLanguage(context, 'en'),
        ),
      ],
    );
  }

  /// Tekil dil seçeneği
  Widget _buildLanguageOption({
    required BuildContext context,
    required String flag,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.dimensions.paddingM,
          vertical: context.dimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.systemBlue.withValues(alpha: 0.1)
              : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemGrey4,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Bayrak
            Text(
              flag,
              style: const TextStyle(fontSize: 28),
            ),
            SizedBox(width: context.dimensions.spaceM),

            // Dil bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextTheme.body.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? CupertinoColors.systemBlue
                          : CupertinoColors.label,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextTheme.caption.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),

            // Seçim işareti
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// Dil değiştir
  void _changeLanguage(BuildContext context, String languageCode) {
    HapticFeedback.lightImpact();
    final locale = Locale(languageCode);
    LocalizationManager.instance.changeLocale(locale);
    Navigator.of(context).pop();
  }

  /// Dil seçimi modalını göster
  void _showLanguageSelection(BuildContext context) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Scaffold(
          body: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle çubuğu
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Başlık
                Text(
                  'language'.locale(context),
                  style: AppTextTheme.headline6.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),

                const SizedBox(height: 24),

                // Dil seçenekleri
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingL),
                  child: _buildLanguageOptions(context),
                ),

                // Alt boşluk
                SizedBox(height: context.dimensions.paddingL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hesap silme dialog'unu göster
  void _showDeleteAccountDialog(BuildContext context) {
    HapticFeedback.heavyImpact();

    // SettingsCubit'i dialog açılmadan önce yakala
    final settingsCubit = context.read<SettingsCubit>();

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('delete_account_title'.locale(context)),
        content: Text('delete_account_warning'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('delete_account_title'.locale(context)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Yakaladığımız cubit'i kullan
              settingsCubit.deleteAccount();
            },
          ),
        ],
      ),
    );
  }

  /// Hesap silindi dialog'unu gösterir
  void _showAccountDeletedDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.checkmark_circle,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'account_deleted'.locale(context),
              style: AppTextTheme.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'account_deleted_message'.locale(context),
            style: AppTextTheme.caption,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('ok'.locale(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Debug bölümü - Sadece debug mode'da gösterilir
  Widget _buildDebugSection(BuildContext context) {
    // Production'da debug araçlarını gizle
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader('🔧 Developer Tools (Debug Only)'),
          _buildSettingsItem(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'test_revenuecat'.locale(context),
            subtitle: 'Debug RevenueCat status',
            onTap: () => _testRevenueCat(context),
          ),
          _buildSettingsItem(
            icon: CupertinoIcons.minus_circle,
            title: 'Test Credit Deduction',
            subtitle: 'Firestore real-time test',
            onTap: () => _testCreditDeduction(context),
          ),
          _buildSettingsItem(
            icon: CupertinoIcons.camera,
            title: 'Test iOS Permissions',
            subtitle: 'Force iOS permission registration',
            onTap: () => _testIOSPermissions(context),
            isLast: false,
          ),
          _buildSettingsItem(
            icon: CupertinoIcons.photo_camera,
            title: 'Test Native Permission Dialog',
            subtitle: 'Show iOS camera/gallery permission dialog',
            onTap: () => _showNativePermissionDialogTest(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// RevenueCat test işlemi
  void _testRevenueCat(BuildContext context) async {
    HapticFeedback.lightImpact();

    try {
      AppLogger.i('RevenueCat test işlemi başlıyor...');

      // Full debug status çalıştır
      await RevenueCatDebugHelper.debugFullStatus();

      // PaymentCubit'i refresh et
      final paymentCubit = context.read<PaymentCubit>();
      await paymentCubit.refreshCustomerInfo();

      // Settings sayfasını refresh et
      final settingsCubit = context.read<SettingsCubit>();
      settingsCubit.refreshUserData();

      AppLogger.i('✅ RevenueCat test ve refresh tamamlandı');

      // Kullanıcıya bildirim göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('RevenueCat durumu test edildi - Log\'ları kontrol edin'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('RevenueCat test hatası: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Test Credit Deduction
  void _testCreditDeduction(BuildContext context) {
    HapticFeedback.lightImpact();

    // Kullanıcının analiz kredilerini azalt
    final settingsCubit = context.read<SettingsCubit>();
    settingsCubit.deductAnalysisCredits(1);

    // Kullanıcıya bildirim göster
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz kredileri 1 azaltıldı'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Test iOS Permissions - Debug only
  void _testIOSPermissions(BuildContext context) async {
    HapticFeedback.lightImpact();

    try {
      AppLogger.i('🔧 iOS Permissions test başlıyor...');

      // Force initialize iOS permissions
      await PermissionService().debugForceInitializeIOSPermissions();

      AppLogger.i('✅ iOS Permissions test tamamlandı');

      // Kullanıcıya bildirim göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iOS Permissions test edildi - Settings\'e git!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('iOS Permissions test hatası: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permissions test hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Test Native Permission Dialog
  void _showNativePermissionDialogTest(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    // Basit bir modal ile kamera/galeri seçtir ve ilgili permission'ı iste
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Test Native Permission Dialog'),
        message:
            const Text('Select source to trigger native permission dialog'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await PermissionService()
                  .requestCameraPermission(context: context);
              AppLogger.i('Test Camera Permission Result: $result');
            },
            child: const Text('Kamera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await PermissionService()
                  .requestPhotosPermission(context: context);
              AppLogger.i('Test Gallery Permission Result: $result');
            },
            child: const Text('Galeri'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
      ),
    );
  }
}
