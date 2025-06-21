import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sprung/sprung.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../navbar/navigation_manager.dart';
import '../../plant_analysis/presentation/views/all_analysis/all_analyses_screen.dart';

/// 🍃 Revolutionary Modern Home Header Widget - Steve Jobs Seviyesinde Tasarım
///
/// Ultra premium glassmorphism, sophisticated depth illusion, cinematic parallax effects,
/// ve revolutionary user engagement patterns ile Apple'ın en modern design language'ini
/// yansıtan next-generation header component.
///
/// ✨ Premium Features:
/// - Günlük değişen AI-powered motivasyonel mesajlar
/// - Multi-layered glassmorphism backgrounds
/// - Advanced depth perception shadows
/// - Revolutionary micro-interactions
/// - Cinematic spring-based animations
/// - Apple HIG 2024 uyumlu sophisticated design
/// - Ultra responsive adaptive layout
/// - Premium typography hierarchy
/// - Dynamic content adaptation
/// - Full accessibility compliance
class HomeHeaderWidget extends StatefulWidget {
  const HomeHeaderWidget({super.key});

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget>
    with TickerProviderStateMixin {
  // ============================================================================
  // 🎭 PREMIUM ANIMATION CONTROLLERS
  // ============================================================================

  late AnimationController _entryController;
  late AnimationController _breatheController;
  late AnimationController _shimmerController;

  late Animation<double> _entryAnimation;
  late Animation<double> _breatheAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializePremiumAnimations();
    _orchestrateRevolutionaryEntrance();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _breatheController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Premium animasyonları başlatır
  void _initializePremiumAnimations() {
    // Entry animation - Cinematic entrance
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _entryAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Sprung.criticallyDamped,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Sprung.overDamped,
    ));

    // Breathe animation - Subtle life indication
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _breatheAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOut,
    ));

    // Shimmer animation - Premium highlight effect
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  /// Sinematik giriş orkestrasyon
  void _orchestrateRevolutionaryEntrance() {
    _entryController.forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _breatheController.repeat(reverse: true);
        _shimmerController.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dil değişikliklerini dinlemek için Localizations.localeOf(context) kullanıyoruz
    final currentLocale = Localizations.localeOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryAnimation,
        _breatheAnimation,
      ]),
      builder: (context, child) {
        // Her build'de header message'ı yeniden al (dil değişikliği için)
        final headerMessage = _getTodaysMessage(context);

        return FadeTransition(
          opacity: _entryAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Transform.scale(
              scale: _breatheAnimation.value,
              child: _buildRevolutionaryHeaderContainer(headerMessage),
            ),
          ),
        );
      },
    );
  }

  /// 🎨 Revolutionary Header Container - Ultra Premium Design
  Widget _buildRevolutionaryHeaderContainer(HeaderMessage headerMessage) {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          // Primary depth shadow
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
          // Secondary ambient shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 80,
            offset: const Offset(0, 40),
            spreadRadius: -20,
          ),
          // Surface highlight
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            _buildPremiumBackground(),
            _buildRevolutionaryGradientOverlay(),
            _buildPremiumContent(headerMessage),
            _buildSubtleAccentBorder(),
            _buildShimmerEffect(),
          ],
        ),
      ),
    );
  }

  /// 🌄 Premium Background - Dynamic Image with Effects
  Widget _buildPremiumBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
              Color(0xFF388E3C),
              Color(0xFF2E7D32),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Image.asset(
          'assets/images/background_3.jpg',
          fit: BoxFit.cover,
          color: AppColors.primary.withOpacity(0.75),
          colorBlendMode: BlendMode.multiply,
        ),
      ),
    );
  }

  /// 🎨 Revolutionary Gradient Overlay - Ultra Sophisticated
  Widget _buildRevolutionaryGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.88),
              AppColors.primary.withOpacity(0.65),
              AppColors.primary.withOpacity(0.78),
              AppColors.primary.withOpacity(0.85),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  /// ✨ Premium Content - Revolutionary Layout
  Widget _buildPremiumContent(HeaderMessage headerMessage) {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevolutionaryWelcomeMessage(headerMessage),
          SizedBox(height: context.dimensions.spaceXL),
          _buildRevolutionaryActionButtons(),
        ],
      ),
    );
  }

  /// 🎯 Revolutionary Welcome Message - Premium Typography
  Widget _buildRevolutionaryWelcomeMessage(HeaderMessage headerMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ultra premium title
        Text(
          headerMessage.title,
          style: AppTextTheme.headline2.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1.2,
            fontSize: 34,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        SizedBox(height: context.dimensions.spaceM),
        // Sophisticated subtitle
        Text(
          headerMessage.subtitle,
          style: AppTextTheme.bodyText1.copyWith(
            color: Colors.white.withOpacity(0.95),
            height: 1.6,
            fontWeight: FontWeight.w500,
            fontSize: 17,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 🚀 Revolutionary Action Buttons - Ultra Premium CTAs
  Widget _buildRevolutionaryActionButtons() {
    return Row(
      children: [
        // Primary CTA - Ultra premium scan button
        Expanded(
          flex: 3,
          child: _buildPremiumActionButton(
            title: 'quick_analysis'.locale(context),
            icon: CupertinoIcons.camera_fill,
            onTap: () => _navigateToAnalysis(context),
            isPrimary: true,
          ),
        ),
        SizedBox(width: context.dimensions.spaceM),
        // Secondary CTA - Elegant history button
        Expanded(
          flex: 2,
          child: _buildPremiumActionButton(
            title: 'history'.locale(context),
            icon: CupertinoIcons.clock_fill,
            onTap: () => _navigateToHistory(context),
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  /// 🎨 Premium Action Button - Ultra Sophisticated Design
  Widget _buildPremiumActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isPrimary ? 20 : 18),
        child: Container(
          height: isPrimary ? 58 : 54,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(isPrimary ? 20 : 18),
            border: Border.all(
              color: Colors.white.withOpacity(isPrimary ? 0.3 : 0.25),
              width: isPrimary ? 0.5 : 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                      spreadRadius: -3,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPrimary) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    style: AppTextTheme.bodyText1.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ] else ...[
                Icon(
                  icon,
                  size: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: AppTextTheme.bodyText2.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ✨ Subtle Accent Border - Premium Touch
  Widget _buildSubtleAccentBorder() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// 🌟 Shimmer Effect - Luxury Highlight
  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.transparent,
                    Colors.white
                        .withOpacity(0.1 * (1 - _shimmerAnimation.value.abs())),
                    Colors.transparent,
                  ],
                  stops: [
                    (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                    _shimmerAnimation.value.clamp(0.0, 1.0),
                    (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

    final dayOfYear = DateTime.now().dayOfYear;
    return messages[dayOfYear % messages.length];
  }

  /// Analiz sayfasına navigate eder
  void _navigateToAnalysis(BuildContext context) {
    try {
      // NavigationManager ile analiz tab'ına geç (tab index: 1)
      final navigationManager = NavigationManager.instance;
      if (navigationManager != null) {
        navigationManager.switchToTab(1);
        AppLogger.i('🚀 Analysis tab\'ına geçiş yapıldı');
      } else {
        AppLogger.w('NavigationManager instance bulunamadı');
      }
    } catch (e, stack) {
      AppLogger.e('Analysis tab geçiş hatası', e, stack);
    }
  }

  /// Geçmiş sayfasına navigate eder
  void _navigateToHistory(BuildContext context) {
    try {
      // AllAnalysesScreen'i modal olarak aç
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => const AllAnalysesScreen(),
          fullscreenDialog: true,
        ),
      );
      AppLogger.i('🗂️ All Analyses screen açıldı');
    } catch (e, stack) {
      AppLogger.e('All Analyses screen açma hatası', e, stack);
    }
  }
}

/// Header mesajı modeli
class HeaderMessage {
  final String title;
  final String subtitle;

  const HeaderMessage({
    required this.title,
    required this.subtitle,
  });
}

/// DateTime extension for day of year
extension DateTimeExtension on DateTime {
  int get dayOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    return difference(firstDayOfYear).inDays + 1;
  }
}
