import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';

/// Modern Ana Ekran Header Widget'ı
///
/// Kullanıcı-agnostic motivasyonel mesajlar ve modern gradient
/// background içeren üst banner component'i.
///
/// Özellikler:
/// - Günlük değişen motivasyonel mesajlar
/// - Modern gradient background
/// - Apple HIG uyumlu tasarım
/// - Theme colors kullanımı
/// - Responsive design
class HomeHeaderWidget extends StatelessWidget {
  const HomeHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final headerMessage = _getTodaysMessage(context);

    return Container(
      margin: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 16,
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
                'assets/images/background_3.jpg',
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
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primary.withOpacity(0.6),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: EdgeInsets.all(context.dimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ana başlık
                  Text(
                    headerMessage.title,
                    style: AppTextTheme.headline4.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  SizedBox(height: context.dimensions.spaceS),

                  // Alt mesaj
                  Text(
                    headerMessage.subtitle,
                    style: AppTextTheme.bodyText1.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: context.dimensions.spaceM),

                  // Action row
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // Quick scan button
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'quick_analysis'.locale(context),
                            icon: CupertinoIcons.camera_fill,
                            onTap: () => _navigateToAnalysis(context),
                          ),
                        ),

                        SizedBox(width: context.dimensions.spaceXS),

                        // View history button
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'history'.locale(context),
                            icon: CupertinoIcons.clock_fill,
                            onTap: () => _navigateToHistory(context),
                            isSecondary: true,
                          ),
                        ),
                      ],
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

  /// Quick action button oluşturur
  Widget _buildQuickActionButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero, // Padding'i sıfırla
      onPressed: onTap,
      child: Container(
        width: double.infinity, // Maksimum genişlik
        decoration: BoxDecoration(
          color: isSecondary
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10), // 12'den 10'a düşürüldü
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: 12, // 8'den 12'ye artırıldı
          horizontal: 8, // Sabit değer
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14, // 16'dan 14'e düşürüldü
              color: Colors.white,
            ),
            SizedBox(width: 4), // context.dimensions.spaceXS yerine sabit değer
            Flexible(
              child: Text(
                title,
                style: AppTextTheme.bodyText2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12, // Font boyutu küçültüldü
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Günün mesajını getirir
  HeaderMessage _getTodaysMessage(BuildContext context) {
    final messages = [
      HeaderMessage(
        title: 'header_message_1_title'.locale(context),
        subtitle: 'header_message_1_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_2_title'.locale(context),
        subtitle: 'header_message_2_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_3_title'.locale(context),
        subtitle: 'header_message_3_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_4_title'.locale(context),
        subtitle: 'header_message_4_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_5_title'.locale(context),
        subtitle: 'header_message_5_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_6_title'.locale(context),
        subtitle: 'header_message_6_subtitle'.locale(context),
      ),
      HeaderMessage(
        title: 'header_message_7_title'.locale(context),
        subtitle: 'header_message_7_subtitle'.locale(context),
      ),
    ];

    // Haftanın gününe göre mesaj seç
    final dayOfWeek = DateTime.now().weekday;
    return messages[(dayOfWeek - 1) % messages.length];
  }

  /// Analiz sayfasına yönlendirir
  void _navigateToAnalysis(BuildContext context) {
    // NavigationManager ile analiz tab'ına geç
    // Bu implementasyon NavigationManager'a bağlı
  }

  /// Geçmiş sayfasına yönlendirir
  void _navigateToHistory(BuildContext context) {
    // Geçmiş analizler sayfasına git
  }
}

/// Header mesaj modeli
class HeaderMessage {
  final String title;
  final String subtitle;

  const HeaderMessage({
    required this.title,
    required this.subtitle,
  });
}
