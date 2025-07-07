import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/features/settings/cubits/language_cubit.dart';
import 'package:tatarai/features/settings/cubits/language_state.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/utils/logger.dart';

import 'package:flutter/material.dart';

/// Dil seçimi için modal bottom sheet
/// Apple HIG prensiplerine uygun minimal ve kullanıcı dostu tasarım
class LanguageSelectionModal {
  /// Modal bottom sheet'i göster
  static Future<void> show(BuildContext context) async {
    HapticFeedback.mediumImpact();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => const _LanguageSelectionContent(),
    );
  }
}

/// Dil seçimi modal içeriği
class _LanguageSelectionContent extends StatefulWidget {
  const _LanguageSelectionContent();

  @override
  State<_LanguageSelectionContent> createState() =>
      _LanguageSelectionContentState();
}

class _LanguageSelectionContentState extends State<_LanguageSelectionContent> {
  late String _currentLanguageCode;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _currentLanguageCode =
        LocalizationManager.instance.currentLocale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: Text(
        'select_language'.locale(context),
        style: AppTextTheme.headline6.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      message: Text(
        'change_language'.locale(context),
        style: AppTextTheme.captionL.copyWith(
          color: CupertinoColors.secondaryLabel,
        ),
      ),
      actions: [
        _buildLanguageAction(
          context: context,
          locale: LocaleConstants.trLocale,
          title: 'language_tr'.locale(context),
          subtitle: 'Türkiye',
          icon: '🇹🇷',
        ),
        _buildLanguageAction(
          context: context,
          locale: LocaleConstants.enLocale,
          title: 'language_en'.locale(context),
          subtitle: 'United States',
          icon: '🇺🇸',
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        child: Text(
          'cancel'.locale(context),
          style: AppTextTheme.bodyText1.copyWith(
            color: CupertinoColors.systemRed,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Dil seçeneği action'ı oluştur
  Widget _buildLanguageAction({
    required BuildContext context,
    required Locale locale,
    required String title,
    required String subtitle,
    required String icon,
  }) {
    final isSelected = _currentLanguageCode == locale.languageCode;
    final isDisabled = _isChanging;

    return CupertinoActionSheetAction(
      onPressed: () async {
        if (!isDisabled) {
          await _changeLanguage(context, locale);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Bayrak emoji
            Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 16),

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
                          : CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextTheme.caption.copyWith(
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),

            // Seçim durumu
            if (_isChanging)
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
    );
  }

  /// Dil değiştirme işlemi
  Future<void> _changeLanguage(BuildContext context, Locale newLocale) async {
    // Aynı dil seçildiyse işlem yapma
    if (_currentLanguageCode == newLocale.languageCode) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    try {
      AppLogger.i('Dil değiştiriliyor: ${newLocale.languageCode}');

      // Loading state'e geç
      setState(() {
        _isChanging = true;
      });

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Dili değiştir - await ile bekle
      await LocalizationManager.instance.changeLocale(newLocale);

      // Dil değişikliğini kontrol et
      final currentAfterChange = LocalizationManager.instance.currentLocale;
      AppLogger.i(
          'Dil değişikliği sonrası kontrol - istenen: ${newLocale.languageCode}, şu anki: ${currentAfterChange.languageCode}');

      // Başarı feedback'i
      HapticFeedback.lightImpact();

      AppLogger.i('Dil başarıyla değiştirildi: ${newLocale.languageCode}');

      // State'i güncelle
      setState(() {
        _currentLanguageCode = newLocale.languageCode;
        _isChanging = false;
      });

      // Kısa bir gecikme ile değişikliğin yansımasını bekle
      await Future.delayed(const Duration(milliseconds: 300));

      // Modal'ı kapat
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.e('Dil değiştirme hatası: $e');

      // Hata feedback'i
      HapticFeedback.heavyImpact();

      // Loading state'i kapat
      setState(() {
        _isChanging = false;
      });

      // Hata dialog'u göster
      _showErrorDialog(context, e.toString());
    }
  }

  /// Hata dialog'u göster
  void _showErrorDialog(BuildContext context, String error) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('error'.locale(context)),
        content: Text('language_change_error'.locale(context)),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.locale(context)),
          ),
        ],
      ),
    );
  }
}
