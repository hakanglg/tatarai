import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/theme/dimensions.dart';

/// Yazı boyutu kontrol widgetı
///
/// Özellikle yaşlı kullanıcılar için yazı boyutunun dinamik olarak
/// ayarlanabilmesini sağlayan widget
class FontSizeControl extends StatelessWidget {
  /// Mevcut yazı boyutu seviyesi
  final int fontSizeLevel;

  /// Maksimum yazı boyutu seviyesi
  final int maxLevel;

  /// Yazı boyutu değiştiğinde çalışacak callback
  final Function(int) onFontSizeChanged;

  /// Gösterilecek metin (opsiyonel)
  final String? labelText;

  /// Varsayılan yapıcı
  const FontSizeControl({
    super.key,
    required this.fontSizeLevel,
    required this.onFontSizeChanged,
    this.maxLevel = 2,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: context.dimensions.spaceXS,
          horizontal: context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelText != null) ...[
            Text(
              labelText!,
              style: AppTextTheme.caption.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: context.dimensions.spaceXS),
          ],

          // Küçültme butonu
          _buildControlButton(
            icon: CupertinoIcons.minus,
            onPressed: fontSizeLevel > 0
                ? () => onFontSizeChanged(fontSizeLevel - 1)
                : null,
            context: context,
          ),

          // Mevcut yazı boyutu göstergesi
          Container(
            margin:
                EdgeInsets.symmetric(horizontal: context.dimensions.spaceXS),
            padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.spaceXS,
                vertical: context.dimensions.spaceXXS),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(context.dimensions.radiusS),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  'A',
                  style: AppTextTheme.caption.copyWith(
                    fontSize: 12 + (fontSizeLevel * 3),
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Büyütme butonu
          _buildControlButton(
            icon: CupertinoIcons.plus,
            onPressed: fontSizeLevel < maxLevel
                ? () => onFontSizeChanged(fontSizeLevel + 1)
                : null,
            context: context,
          ),
        ],
      ),
    );
  }

  /// Kontrol butonunu oluşturur
  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    required BuildContext context,
  }) {
    final bool isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(context.dimensions.radiusXS),
        child: Container(
          padding: EdgeInsets.all(context.dimensions.spaceXS),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.divider,
            borderRadius: BorderRadius.circular(context.dimensions.radiusXS),
          ),
          child: Icon(
            icon,
            size: context.dimensions.iconSizeXS,
            color: isEnabled ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
