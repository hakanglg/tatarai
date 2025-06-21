import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/settings/cubits/settings_cubit.dart';
import 'package:tatarai/features/settings/cubits/settings_state.dart';
import 'package:tatarai/core/extensions/context_extensions.dart';

/// Uygulama ayarları ekranı
/// Apple Human Interface Guidelines'a uygun modern tasarım
class SettingsScreen extends StatefulWidget {
  /// Constructor
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                    // Üyelik Bilgileri Kartı
                    _buildMembershipCard(user),

                    SizedBox(height: context.dimensions.spaceL),

                    // Ayarlar
                    _buildSettingsSection(context),

                    SizedBox(height: context.dimensions.spaceL),

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

  /// Üyelik bilgilerini gösteren kart
  Widget _buildMembershipCard(UserModel user) {
    final Color cardBgColor = user.isPremium
        ? const Color(0xFF0A8D48) // Premium yeşil
        : const Color(0xFF2C2C2E); // Standard gri

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.dimensions.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardBgColor,
            cardBgColor.withOpacity(0.95),
            Color.lerp(cardBgColor, Colors.black, 0.15) ?? cardBgColor,
          ],
        ),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst kısım - Premium durumu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      user.isPremium
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.person_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: context.dimensions.spaceM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.isPremium
                            ? 'premium_account'.locale(context)
                            : 'free_account'.locale(context),
                        style: AppTextTheme.headline6.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.isPremium
                            ? 'unlimited_analysis'.locale(context)
                            : 'limited_access'.locale(context),
                        style: AppTextTheme.caption.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Premium rozeti
              if (user.isPremium)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.dimensions.spaceS,
                    vertical: context.dimensions.spaceXS,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9CF58).withOpacity(0.9),
                    borderRadius:
                        BorderRadius.circular(context.dimensions.radiusS),
                  ),
                  child: Text(
                    'premium_tag'.locale(context),
                    style: AppTextTheme.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: context.dimensions.spaceL),

          // Analiz kredisi bilgisi
          Column(
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'remaining_analysis'.locale(context),
                    style: AppTextTheme.bodyText2.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    user.isPremium ? '∞' : '${user.analysisCredits}',
                    style: AppTextTheme.headline4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              // Premium olmayan kullanıcılar için yükseltme butonu
              if (!user.isPremium) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(
                      vertical: context.dimensions.spaceXS,
                    ),
                    color: Colors.white.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(context.dimensions.radiusS),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.arrow_up_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'upgrade_to_premium'.locale(context),
                          style: AppTextTheme.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      // Premium upgrade ekranına git
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
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
            color: Colors.black.withOpacity(0.05),
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
            color: Colors.black.withOpacity(0.05),
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
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
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
              ? CupertinoColors.systemBlue.withOpacity(0.1)
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
}
