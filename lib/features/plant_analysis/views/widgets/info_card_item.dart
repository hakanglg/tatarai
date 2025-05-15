import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';

// Bilgi kartı içinde ikon, başlık ve değer içeren satır elementi

class InfoCardItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;

  InfoCardItem(
      {super.key,
      required this.icon,
      required this.title,
      required this.value,
      this.iconColor});

  final double _currentFontSize = AppTextTheme.bodyText2.fontSize ?? 14.0;

  @override
  Widget build(BuildContext context) {
    final dim = context.dimensions;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(dim.paddingS),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: dim.iconSizeS,
            color: iconColor ?? AppColors.primary,
          ),
        ),
        SizedBox(width: dim.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextTheme.captionL.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: _currentFontSize * 0.9,
                ),
              ),
              SizedBox(height: dim.spaceXXS),
              Text(
                value,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: AppTextTheme.bodyText2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: _currentFontSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
