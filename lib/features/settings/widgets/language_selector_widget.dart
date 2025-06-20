import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/extensions/context_extensions.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';
import 'package:tatarai/features/settings/cubits/language_cubit.dart';
import 'package:tatarai/features/settings/cubits/language_state.dart';

/// Apple HIG prensiplerine uygun modern dil seçici widget'ı
/// Zarif animasyonlar ve kullanıcı dostu tasarım sunar
class LanguageSelectorWidget extends StatelessWidget {
  /// Widget'ın görünümü - compact veya expanded
  final bool isCompact;

  /// Başlık gösterilsin mi?
  final bool showTitle;

  /// Custom title
  final String? customTitle;

  /// Constructor
  const LanguageSelectorWidget({
    super.key,
    this.isCompact = false,
    this.showTitle = true,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LanguageCubit(),
      child: _LanguageSelectorContent(
        isCompact: isCompact,
        showTitle: showTitle,
        customTitle: customTitle,
      ),
    );
  }
}

/// Dil seçici içerik widget'ı
class _LanguageSelectorContent extends StatefulWidget {
  final bool isCompact;
  final bool showTitle;
  final String? customTitle;

  const _LanguageSelectorContent({
    required this.isCompact,
    required this.showTitle,
    this.customTitle,
  });

  @override
  State<_LanguageSelectorContent> createState() =>
      _LanguageSelectorContentState();
}

class _LanguageSelectorContentState extends State<_LanguageSelectorContent>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon kontrolcüsü ve animasyonları oluştur
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Sprung.overDamped,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    // Animasyonu başlat
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LanguageCubit, LanguageState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildContent(context, state),
              ),
            );
          },
        );
      },
    );
  }

  /// State değişikliklerini dinle ve gerekli aksiyonları al
  void _handleStateChanges(BuildContext context, LanguageState state) {
    // Hata mesajını göster
    if (state.hasError && state.errorMessage != null) {
      _showErrorMessage(context, state.errorMessage!);
    }

    // Başarı mesajını göster
    if (state.hasSuccess && state.successMessage != null) {
      _showSuccessMessage(context, state.successMessage!);
    }
  }

  /// Ana içerik widget'ı
  Widget _buildContent(BuildContext context, LanguageState state) {
    if (widget.isCompact) {
      return _buildCompactView(context, state);
    } else {
      return _buildExpandedView(context, state);
    }
  }

  /// Kompakt görünüm - ayarlar ekranında kullanım için
  Widget _buildCompactView(BuildContext context, LanguageState state) {
    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              widget.customTitle ?? 'language'.locale(context),
              style: AppTextTheme.headline6.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: context.dimensions.spaceS),
          ],
          _buildLanguageOptions(context, state),
        ],
      ),
    );
  }

  /// Genişletilmiş görünüm - tam sayfa kullanım için
  Widget _buildExpandedView(BuildContext context, LanguageState state) {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              widget.customTitle ?? 'select_language'.locale(context),
              style: AppTextTheme.headline3.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: context.dimensions.spaceL),
          ],
          _buildLanguageOptions(context, state),
        ],
      ),
    );
  }

  /// Dil seçenekleri widget'ı
  Widget _buildLanguageOptions(BuildContext context, LanguageState state) {
    return Column(
      children: [
        _buildLanguageOptionTile(
          context: context,
          locale: LocaleConstants.trLocale,
          title: 'language_tr'.locale(context),
          subtitle: 'Türkiye',
          icon: CupertinoIcons.location_solid,
          isSelected: state.currentLocale.languageCode ==
              LocaleConstants.trLocale.languageCode,
          isLoading: state.isLoading,
          onTap: () => _changeLanguage(context, LocaleConstants.trLocale),
        ),
        SizedBox(height: context.dimensions.spaceS),
        _buildLanguageOptionTile(
          context: context,
          locale: LocaleConstants.enLocale,
          title: 'language_en'.locale(context),
          subtitle: 'United States',
          icon: CupertinoIcons.globe,
          isSelected: state.currentLocale.languageCode ==
              LocaleConstants.enLocale.languageCode,
          isLoading: state.isLoading,
          onTap: () => _changeLanguage(context, LocaleConstants.enLocale),
        ),
      ],
    );
  }

  /// Tekil dil seçeneği tile widget'ı
  Widget _buildLanguageOptionTile({
    required BuildContext context,
    required Locale locale,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final isDisabled = isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Sprung.criticallyDamped,
      decoration: BoxDecoration(
        color:
            isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.divider.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isDisabled ? null : onTap,
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          child: Row(
            children: [
              // Dil ikonu
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(context.dimensions.radiusS),
                ),
                child: Icon(
                  icon,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              SizedBox(width: context.dimensions.spaceM),

              // Dil bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextTheme.bodyText1.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: context.dimensions.spaceXS),
                    Text(
                      subtitle,
                      style: AppTextTheme.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Seçim durumu
              if (isLoading)
                const CupertinoActivityIndicator(radius: 10)
              else if (isSelected)
                Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: AppColors.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dil değiştirme işlemini başlat
  void _changeLanguage(BuildContext context, Locale newLocale) {
    AppLogger.i('Dil değiştirme isteği: ${newLocale.languageCode}');
    context.read<LanguageCubit>().changeLanguage(newLocale);
  }

  /// Hata mesajını göster
  void _showErrorMessage(BuildContext context, String message) {
    AppDialogManager.showErrorDialog(
      context: context,
      title: 'error'.locale(context),
      message: message,
    );
  }

  /// Başarı mesajını göster
  void _showSuccessMessage(BuildContext context, String message) {
    AppDialogManager.showInfoDialog(
      context: context,
      title: 'success'.locale(context),
      message: message,
    );
  }
}
