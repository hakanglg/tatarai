// lib/features/update/widgets/update_dialog.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/update_config.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateConfig config;

  const UpdateDialog({super.key, required this.config});

  Future<void> _launchStoreUrl() async {
    final uri = Uri.parse(config.storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppLogger.w('Uygulama mağazası açılamadı: ${config.storeUrl}');
      }
    } catch (e) {
      AppLogger.e('Uygulama mağazası açılırken hata', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Geri tuşu engellendi
      child: AlertDialog(
        title: const Text(
          'Güncelleme Mevcut',
          textAlign: TextAlign.center,
          style: AppTextTheme.headline4,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.arrow_up_circle,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              config.optionalUpdateMessage,
              textAlign: TextAlign.center,
              style: AppTextTheme.body,
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni sürüm: ${config.latestVersion}',
              style: AppTextTheme.captionL,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Daha Sonra'),
          ),
          ElevatedButton(
            onPressed: _launchStoreUrl,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Güncelle'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
