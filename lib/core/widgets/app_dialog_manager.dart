import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';

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
            onPressed: onPressed ?? () => Navigator.pop(context),
            child: Text(buttonText ?? 'ok'.locale(context)),
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
            onPressed: onCancelPressed ??
                () {
                  Navigator.pop(context, false);
                },
            child: Text(cancelText ?? 'no'.locale(context)),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: onConfirmPressed ??
                () {
                  Navigator.pop(context, true);
                },
            child: Text(confirmText ?? 'yes'.locale(context)),
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
            onPressed: onPressed ?? () => Navigator.pop(context),
            child: Text(buttonText ?? 'ok'.locale(context)),
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
                color: AppColors.warning.withValues(alpha: 0.1),
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
      builder: (dialogContext) => CupertinoAlertDialog(
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
            onPressed: () {
              // Önce diyaloğu kapat
              Navigator.of(dialogContext).pop(false);

              // Sonra callback'i çağır (eğer varsa)
              if (onCancelPressed != null) {
                onCancelPressed();
              }
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(settingsText ?? 'button_settings'.locale(context)),
            onPressed: () {
              // Önce diyaloğu kapat
              Navigator.of(dialogContext).pop(true);

              // Sonra onSettingsPressed callback'ini çağır
              if (onSettingsPressed != null) {
                // Bir mikrosaniye gecikmeli olarak çağır, böylece diyalog tamamen kapanır
                Future.delayed(const Duration(milliseconds: 100), () {
                  onSettingsPressed();
                });
              }
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
            onPressed: onPressed ?? () => Navigator.pop(context),
            child: Text(buttonText ?? 'ok'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Diyalog'u kapat
  static void dismissDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// SnackBar bildirim gösterir - kısa süreli popup şeklinde bildirim
  static void showSnackBar({
    required BuildContext context,
    required String message,
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onDismiss,
  }) {
    if (!context.mounted) return;

    // İkon ve rengi belirle
    IconData iconToShow = icon ??
        (message.contains('success') ||
                message.contains('başarı') ||
                message.contains('güncelle') ||
                message.contains('updated')
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.info_circle_fill);

    Color colorToShow = iconColor ??
        (message.contains('success') ||
                message.contains('başarı') ||
                message.contains('güncelle') ||
                message.contains('updated')
            ? CupertinoColors.activeGreen
            : CupertinoColors.activeBlue);

    // Platform adaptif SnackBar gösterimi
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars(); // Mevcut SnackBar'ları kapat

    if (isIOS) {
      // iOS stili SnackBar
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                iconToShow,
                color: colorToShow,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'sfpro',
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
              Colors.grey[850], // AppTheme.darkColorScheme.surface,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          dismissDirection: DismissDirection.horizontal,
          action: SnackBarAction(
            label: 'Kapat',
            textColor: Colors.white70,
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
              if (onDismiss != null) {
                onDismiss();
              }
            },
          ),
        ),
      );
    } else {
      // Android stili SnackBar
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                iconToShow,
                color: colorToShow,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
              Colors.grey[900], // AppTheme.darkColorScheme.background,
          duration: duration,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: 'KAPAT',
            textColor: AppColors.primary,
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
              if (onDismiss != null) {
                onDismiss();
              }
            },
          ),
        ),
      );
    }
  }
}
