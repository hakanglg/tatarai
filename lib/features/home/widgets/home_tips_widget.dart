import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/extensions/string_extension.dart';

/// Modern Ana Ekran İpuçları Widget'ı
///
/// Günlük değişen bitki bakım ipuçları ve motivasyonel
/// içerikler gösteren modern card tasarımı.
///
/// Özellikler:
/// - Günlük rotasyonlu ipuçları
/// - Modern gradient tasarım
/// - Actionable öneriler
/// - Apple HIG uyumlu animasyonlar
/// - Theme colors kullanımı
/// - Responsive design
class HomeTipsWidget extends StatelessWidget {
  const HomeTipsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final todaysTip = _getTodaysTip(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section başlığı
          Padding(
            padding: EdgeInsets.only(
              left: context.dimensions.paddingXS,
              bottom: context.dimensions.paddingS,
            ),
            child: Row(
              children: [
                Text(
                  'daily_tip'.locale(context),
                  style: AppTextTheme.headline6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: context.dimensions.spaceXS),
                Icon(
                  CupertinoIcons.lightbulb_fill,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),

          // Tip card
          _buildTipCard(context, todaysTip),
        ],
      ),
    );
  }

  /// Tip card oluşturur
  Widget _buildTipCard(BuildContext context, TipData tip) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tip.color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Arka plan resmi
            Positioned.fill(
              child: Image.asset(
                'assets/images/background_2.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tip.color.withValues(alpha: 0.8),
                      tip.color.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: EdgeInsets.all(context.dimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // İkon
                      Container(
                        padding: EdgeInsets.all(context.dimensions.paddingS),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tip.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      SizedBox(width: context.dimensions.spaceM),

                      // Kategori
                      Expanded(
                        child: Text(
                          tip.category,
                          style: AppTextTheme.bodyText1.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.dimensions.spaceM),

                  // Başlık
                  Text(
                    tip.title,
                    style: AppTextTheme.headline5.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  SizedBox(height: context.dimensions.spaceS),

                  // Açıklama
                  Text(
                    tip.description,
                    style: AppTextTheme.bodyText1.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: context.dimensions.spaceM),

                  // Action button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _handleTipAction(context, tip),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.dimensions.paddingM,
                        vertical: context.dimensions.paddingS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tip.actionText,
                            style: AppTextTheme.bodyText2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: context.dimensions.spaceXS),
                          Icon(
                            CupertinoIcons.arrow_right,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Günün ipucunu getirir
  TipData _getTodaysTip(BuildContext context) {
    final tips = [
      // Pazartesi - Sulama
      TipData(
        category: 'watering_category'.locale(context),
        title: 'watering_tip_title'.locale(context),
        description: 'watering_tip_desc'.locale(context),
        icon: CupertinoIcons.drop_fill,
        color: AppColors.info, // Proje info rengi
        actionText: 'watering_guide'.locale(context),
      ),

      // Salı - Işık
      TipData(
        category: 'lighting_category'.locale(context),
        title: 'lighting_tip_title'.locale(context),
        description: 'lighting_tip_desc'.locale(context),
        icon: CupertinoIcons.sun_max_fill,
        color: AppColors.warning, // Proje warning rengi
        actionText: 'lighting_guide'.locale(context),
      ),

      // Çarşamba - Toprak
      TipData(
        category: 'soil_category'.locale(context),
        title: 'soil_tip_title'.locale(context),
        description: 'soil_tip_desc'.locale(context),
        icon: CupertinoIcons.globe,
        color: AppColors.primary, // Proje ana rengi
        actionText: 'soil_test'.locale(context),
      ),

      // Perşembe - Budama
      TipData(
        category: 'pruning_category'.locale(context),
        title: 'pruning_tip_title'.locale(context),
        description: 'pruning_tip_desc'.locale(context),
        icon: CupertinoIcons.scissors,
        color: AppColors.textSecondary, // Proje secondary rengi
        actionText: 'pruning_techniques'.locale(context),
      ),

      // Cuma - Gübre
      TipData(
        category: 'nutrition_category'.locale(context),
        title: 'nutrition_tip_title'.locale(context),
        description: 'nutrition_tip_desc'.locale(context),
        icon: CupertinoIcons.leaf_arrow_circlepath,
        color: AppColors.success, // Proje success rengi
        actionText: 'fertilizer_guide'.locale(context),
      ),

      // Cumartesi - Hastalık
      TipData(
        category: 'disease_prevention_category'.locale(context),
        title: 'disease_prevention_tip_title'.locale(context),
        description: 'disease_prevention_tip_desc'.locale(context),
        icon: CupertinoIcons.shield_fill,
        color:
            AppColors.textSecondary, // error yerine textSecondary kullanıyoruz
        actionText: 'disease_guide'.locale(context),
      ),

      // Pazar - Genel Bakım
      TipData(
        category: 'general_care_category'.locale(context),
        title: 'general_care_tip_title'.locale(context),
        description: 'general_care_tip_desc'.locale(context),
        icon: CupertinoIcons.heart_fill,
        color: AppColors.textTertiary, // Proje tertiary rengi
        actionText: 'care_calendar'.locale(context),
      ),
    ];

    // Haftanın gününe göre tip seç
    final dayOfWeek = DateTime.now().weekday;
    return tips[(dayOfWeek - 1) % tips.length];
  }

  /// Tip action'ını işler
  void _handleTipAction(BuildContext context, TipData tip) {
    // Tip kategorisine göre ilgili sayfaya yönlendir
    // Bu implementasyon NavigationManager'a bağlı

    // Şimdilik basit bir dialog göster
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(tip.category),
        content: Text(
            '${tip.category} hakkında daha detaylı bilgi yakında eklenecek!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.locale(context)),
          ),
        ],
      ),
    );
  }
}

/// Tip verisi modeli
class TipData {
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String actionText;

  const TipData({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionText,
  });
}
