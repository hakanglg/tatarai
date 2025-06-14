import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';

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
    final todaysTip = _getTodaysTip();

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
                  'Günün İpucu',
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
            color: tip.color.withOpacity(0.12),
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
                      tip.color.withOpacity(0.8),
                      tip.color.withOpacity(0.6),
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
                          color: Colors.white.withOpacity(0.2),
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
                            color: Colors.white.withOpacity(0.9),
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
                      color: Colors.white.withOpacity(0.9),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
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
  TipData _getTodaysTip() {
    final tips = [
      // Pazartesi - Sulama
      TipData(
        category: 'Sulama',
        title: 'Doğru Sulama Zamanı',
        description:
            'Bitkilerinizi sabah erken saatlerde sulayın. Bu sayede gün boyunca suyu emebilir ve gece nemli kalmaktan kaynaklı hastalıklardan korunabilirler.',
        icon: CupertinoIcons.drop_fill,
        color: AppColors.info, // Proje info rengi
        actionText: 'Sulama Rehberi',
      ),

      // Salı - Işık
      TipData(
        category: 'Işık',
        title: 'Işık İhtiyacını Anlayın',
        description:
            'Her bitkinin farklı ışık ihtiyacı vardır. Yaprakların solması veya uzaması, yanlış ışık koşullarının işareti olabilir.',
        icon: CupertinoIcons.sun_max_fill,
        color: AppColors.warning, // Proje warning rengi
        actionText: 'Işık Rehberi',
      ),

      // Çarşamba - Toprak
      TipData(
        category: 'Toprak',
        title: 'Toprak Sağlığı Kontrolü',
        description:
            'Toprağınızın pH seviyesini kontrol edin. Çoğu bitki 6.0-7.0 pH aralığında en iyi gelişir.',
        icon: CupertinoIcons.globe,
        color: AppColors.primary, // Proje ana rengi
        actionText: 'Toprak Testi',
      ),

      // Perşembe - Budama
      TipData(
        category: 'Budama',
        title: 'Düzenli Budama Yapın',
        description:
            'Ölü, hastalıklı veya zarar görmüş yaprakları düzenli olarak temizleyin. Bu, bitkinin enerjisini sağlıklı büyümeye odaklamasını sağlar.',
        icon: CupertinoIcons.scissors,
        color: AppColors.textSecondary, // Proje secondary rengi
        actionText: 'Budama Teknikleri',
      ),

      // Cuma - Gübre
      TipData(
        category: 'Beslenme',
        title: 'Mevsimsel Gübreleme',
        description:
            'İlkbahar ve yaz aylarında bitkilerinizi düzenli gübrelemeyi unutmayın. Organik gübreler uzun vadeli sağlık için idealdir.',
        icon: CupertinoIcons.leaf_arrow_circlepath,
        color: AppColors.success, // Proje success rengi
        actionText: 'Gübre Rehberi',
      ),

      // Cumartesi - Hastalık
      TipData(
        category: 'Hastalık Önleme',
        title: 'Erken Teşhis Önemli',
        description:
            'Bitkilerinizi düzenli kontrol edin. Yapraklardaki lekeler, renk değişiklikleri veya şekil bozuklukları hastalık belirtisi olabilir.',
        icon: CupertinoIcons.shield_fill,
        color:
            AppColors.textSecondary, // error yerine textSecondary kullanıyoruz
        actionText: 'Hastalık Rehberi',
      ),

      // Pazar - Genel Bakım
      TipData(
        category: 'Genel Bakım',
        title: 'Sabırlı Olun',
        description:
            'Bitki bakımı sabır işidir. Ani değişiklikler yapmak yerine, bitkilerinizin doğal ritmine uyum sağlayın.',
        icon: CupertinoIcons.heart_fill,
        color: AppColors.textTertiary, // Proje tertiary rengi
        actionText: 'Bakım Takvimi',
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
            child: const Text('Tamam'),
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
