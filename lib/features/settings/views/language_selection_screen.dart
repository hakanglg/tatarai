import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/features/settings/widgets/language_selector_widget.dart';

/// Dil seçimi için tam sayfa ekranı
/// Apple Human Interface Guidelines'a uygun modern ve zarif tasarım
class LanguageSelectionScreen extends StatelessWidget {
  /// Constructor
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.chevron_left,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                'back'.locale(context),
                style: AppTextTheme.bodyText1.copyWith(
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ],
          ),
        ),
        // Başlık - ortalanmış ve modern tipografi
        middle: Text(
          'select_language'.locale(context),
          style: AppTextTheme.headline6.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        // iOS tarzı şeffaf arkaplan
        backgroundColor: CupertinoColors.systemBackground.withValues(alpha: 0.9),
        border: null, // Modern iOS look için border kaldır
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Üst boşluk
            const SizedBox(height: 24),

            // Açıklama metni - modern ve bilgilendirici
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'change_language'.locale(context),
                style: AppTextTheme.captionL.copyWith(
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // Dil seçici widget'ı - genişletilmiş görünümde
            Expanded(
              child: LanguageSelectorWidget(
                isCompact: false,
                showTitle: false, // Başlık navigation bar'da zaten var
              ),
            ),

            // Alt boşluk
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
