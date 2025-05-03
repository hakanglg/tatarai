import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    String buttonText = 'Tamam',
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
            child: Text(buttonText),
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
    String confirmText = 'Evet',
    String cancelText = 'Hayır',
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
            child: Text(cancelText),
            onPressed: onCancelPressed ??
                () {
                  Navigator.pop(context, false);
                },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(confirmText),
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
    String buttonText = 'Tamam',
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
            child: Text(buttonText),
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
    String title = 'Premium Gerekiyor',
    String premiumButtonText = 'Premium Satın Al',
    String cancelText = 'Vazgeç',
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          title,
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
                      'Premium üyelikle sınırsız bitki analizi yapabilirsiniz!',
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
            child: Text(cancelText),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              premiumButtonText,
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
    String settingsText = 'Ayarlara Git',
    String cancelText = 'İptal',
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
            child: Text(cancelText),
            onPressed: onCancelPressed ??
                () {
                  Navigator.pop(context, false);
                },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(settingsText),
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
    String message = 'Lütfen bekleyin...',
  }) async {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text(
              message,
              style: AppTextTheme.body,
            ),
          ],
        ),
      ),
    );
  }

  /// Özel ikonlu diyalog
  static Future<void> showIconDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = CupertinoColors.activeBlue,
    String buttonText = 'Tamam',
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
            child: Text(buttonText),
            onPressed: onPressed ?? () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Diyalog'u kapat
  static void dismissDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
