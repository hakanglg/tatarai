import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';

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
    Key? key,
    required this.fontSizeLevel,
    required this.onFontSizeChanged,
    this.maxLevel = 2,
    this.labelText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelText != null) ...[
            Text(
              labelText!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Küçültme butonu
          _buildControlButton(
            icon: CupertinoIcons.minus,
            onPressed: fontSizeLevel > 0
                ? () => onFontSizeChanged(fontSizeLevel - 1)
                : null,
          ),

          // Mevcut yazı boyutu göstergesi
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CupertinoColors.systemGrey5,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  'A',
                  style: TextStyle(
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
          ),
        ],
      ),
    );
  }

  /// Kontrol butonunu oluşturur
  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final bool isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.divider,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
