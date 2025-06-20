import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Basit dil seçici widget'ı
/// Apple HIG prensiplerine uygun minimal tasarım
class SimpleLanguagePicker {
  /// Dil seçimi modal'ını göster
  static Future<void> showLanguagePicker(BuildContext context) async {
    HapticFeedback.mediumImpact();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
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
          // Türkçe seçeneği
          CupertinoActionSheetAction(
            onPressed: () {
              _changeLanguage(context, LocaleConstants.trLocale);
            },
            child: _buildLanguageOption(
              context,
              'language_tr'.locale(context),
              'Türkiye',
              '🇹🇷',
              LocaleConstants.trLocale,
            ),
          ),
          // İngilizce seçeneği
          CupertinoActionSheetAction(
            onPressed: () {
              _changeLanguage(context, LocaleConstants.enLocale);
            },
            child: _buildLanguageOption(
              context,
              'language_en'.locale(context),
              'United States',
              '🇺🇸',
              LocaleConstants.enLocale,
            ),
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
      ),
    );
  }

  /// Dil seçeneği widget'ı oluştur
  static Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String subtitle,
    String flag,
    Locale locale,
  ) {
    final currentLocale = LocalizationManager.instance.currentLocale;
    final isSelected = currentLocale.languageCode == locale.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Bayrak
          Text(
            flag,
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected ? AppColors.primary : CupertinoColors.label,
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

          // Seçim işareti
          if (isSelected)
            Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: AppColors.primary,
              size: 24,
            ),
        ],
      ),
    );
  }

  /// Dil değiştirme işlemi
  static void _changeLanguage(BuildContext context, Locale newLocale) {
    final currentLocale = LocalizationManager.instance.currentLocale;

    // Aynı dil seçildiyse modal'ı kapat
    if (currentLocale.languageCode == newLocale.languageCode) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    try {
      AppLogger.i('Dil değiştiriliyor: ${newLocale.languageCode}');

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Dili değiştir
      LocalizationManager.instance.changeLocale(newLocale);

      AppLogger.i('Dil başarıyla değiştirildi: ${newLocale.languageCode}');

      // Modal'ı kapat
      Navigator.of(context).pop();
    } catch (e) {
      AppLogger.e('Dil değiştirme hatası: $e');

      // Modal'ı kapat
      Navigator.of(context).pop();

      // Hata göster
      _showErrorDialog(context);
    }
  }

  /// Hata dialog'u göster
  static void _showErrorDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('error'.locale(context)),
        content: Text('Dil değiştirilemedi. Lütfen tekrar deneyin.'),
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

  /// Mevcut dil adını al
  static String getCurrentLanguageName(BuildContext context) {
    final currentLocale = LocalizationManager.instance.currentLocale;

    if (currentLocale.languageCode == 'tr') {
      return 'language_tr'.locale(context);
    } else {
      return 'language_en'.locale(context);
    }
  }
}
