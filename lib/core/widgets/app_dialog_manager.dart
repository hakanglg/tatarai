import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';

/// Uygulama genelinde tüm diyalogları yönetmek için kullanılan yardımcı sınıf
class AppDialogManager {
  AppDialogManager._(); // Singleton için private constructor

  /// Basit bilgi diyaloğu gösterir - tek 'Tamam' butonu ile
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          title,
          style: AppTextTheme.headline4,
        ),
        content: Text(
          message,
          style: AppTextTheme.body,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(buttonText ?? 'ok'.locale(context)),
            onPressed: onPressed ?? () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Onay diyaloğu gösterir - 'Evet/Hayır' veya 'Tamam/İptal' gibi iki seçenek içerir
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirmPressed,
    VoidCallback? onCancelPressed,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          title,
          style: AppTextTheme.headline4,
        ),
        content: Text(
          message,
          style: AppTextTheme.body,
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(cancelText ?? 'no'.locale(context)),
            onPressed: onCancelPressed ??
                () {
                  Navigator.pop(context, false);
                },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(confirmText ?? 'yes'.locale(context)),
            onPressed: onConfirmPressed ??
                () {
                  Navigator.pop(context, true);
                },
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Hata diyaloğu gösterir - kırmızı renkli uyarı ikonu ile
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: CupertinoColors.systemRed,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: AppTextTheme.headline4,
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextTheme.body,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(buttonText ?? 'ok'.locale(context)),
            onPressed: onPressed ?? () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Premium satın alma diyaloğu gösterir
  static Future<bool> showPremiumRequiredDialog({
    required BuildContext context,
    required String message,
    required VoidCallback onPremiumButtonPressed,
    String? title,
    String? premiumButtonText,
    String? cancelText,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          title ?? 'premium_required_title'.locale(context),
          style: AppTextTheme.headline4,
        ),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextTheme.body,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.lightbulb_fill,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'unlimited_analysis'.locale(context),
                      style: AppTextTheme.captionL.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text(cancelText ?? 'cancel'.locale(context)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              premiumButtonText ?? 'get_premium'.locale(context),
              style: AppTextTheme.body.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
              onPremiumButtonPressed();
            },
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Ayarlar diyaloğu - ayarlara gitme seçeneği ile
  static Future<bool> showSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? settingsText,
    String? cancelText,
    VoidCallback? onSettingsPressed,
    VoidCallback? onCancelPressed,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.gear,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: AppTextTheme.headline4,
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextTheme.body,
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(cancelText ?? 'cancel'.locale(context)),
            onPressed: onCancelPressed ??
                () {
                  Navigator.pop(context, false);
                },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(settingsText ?? 'button_settings'.locale(context)),
            onPressed: onSettingsPressed ??
                () {
                  Navigator.pop(context, true);
                },
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Yükleniyor diyaloğu - işlem sırasında gösterilir
  static Future<void> showLoadingDialog({
    required BuildContext context,
    String? message,
    String? buttonText,
  }) async {
    await showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const CupertinoActivityIndicator(radius: 12),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(message ?? 'loading'.locale(context)),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(buttonText ?? 'ok'.locale(context)),
            ),
          ],
        );
      },
    );
  }

  /// Özel ikonlu diyalog
  static Future<void> showIconDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = CupertinoColors.activeBlue,
    String? buttonText,
    VoidCallback? onPressed,
  }) async {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: AppTextTheme.headline4,
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextTheme.body,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(buttonText ?? 'ok'.locale(context)),
            onPressed: onPressed ?? () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Diyalog'u kapat
  static void dismissDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
