import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sprung/sprung.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button.dart';
import '../widgets/home_premium_card.dart';
import '../../plant_analysis/data/models/plant_analysis_model.dart';
import '../../plant_analysis/presentation/views/all_analysis/all_analyses_screen.dart';
import '../../plant_analysis/presentation/views/widgets/analysis_card.dart';
import '../../plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';
import '../constants/home_constants.dart';
import '../cubits/home_cubit.dart';
import '../cubits/home_state.dart';
import '../widgets/home_header_widget.dart';
import '../widgets/home_quick_actions_widget.dart';
import '../widgets/home_stats_widget.dart';
import '../widgets/home_tips_widget.dart';
import '../../../core/init/app_initializer.dart';
import '../../auth/cubits/auth_cubit.dart';
import '../../auth/cubits/auth_state.dart';
import '../../navbar/navigation_manager.dart';

/// 🍃 Modern Ana Ekran Tab İçeriği
///
/// Steve Jobs seviyesinde sleek, sexy ve modern Apple Human Interface Guidelines
/// uyumlu ana ekran tasarımı. Clean Architecture prensiplerine uygun modüler yapı.
///
/// ✨ Özellikler:
/// - iOS 17+ modern tasarım dili ile futuristik görünüm
/// - Smooth spring animasyonlar ve fluid geçişler
/// - Glassmorphism efektleri ve depth illusion
/// - Advanced pull-to-refresh desteği
/// - Ultra responsive layout ve adaptive design
/// - Full accessibility desteği
/// - HomeCubit ile reactive state management
/// - ServiceLocator dependency injection
/// - Apple HIG uyumlu haptic feedback
/// - Dynamic content adapters
/// - Performance optimized scroll behavior
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent>
    with TickerProviderStateMixin {
  // ============================================================================
  // 🎭 PREMIUM ANIMATION CONTROLLERS
  // ============================================================================

  late AnimationController _masterFadeController;
  late AnimationController _staggeredSlideController;
  late AnimationController _heroScaleController;
  late AnimationController _parallaxController;
  late AnimationController _pulseController;

  late Animation<double> _masterFadeAnimation;
  late Animation<Offset> _heroSlideAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _heroScaleAnimation;
  late Animation<double> _contentScaleAnimation;
  late Animation<double> _parallaxAnimation;
  late Animation<double> _pulseAnimation;

  // ============================================================================
  // 🎮 PREMIUM CONTROLLERS
  // ============================================================================

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  // ============================================================================
  // 🏗️ CUBIT DEPENDENCIES
  // ============================================================================

  HomeCubit? _homeCubit;
  bool _isInitialized = false;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    AppLogger.i('🍃 Premium HomeTabContent launching with maximum performance');

    _initializePremiumAnimations();
    _initializeAdvancedDependencies();
    _initializeHomeCubitWithEnhancement();
    _setupAdvancedScrollListener();
  }

  @override
  void dispose() {
    _disposePremiumResources();
    super.dispose();
  }

  // ============================================================================
  // 🚀 PREMIUM INITIALIZATION METHODS
  // ============================================================================

  /// Steve Jobs seviyesinde premium animasyonları başlatır
  void _initializePremiumAnimations() {
    // Master fade controller - Ultra smooth fade
    _masterFadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _masterFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _masterFadeController,
      curve: Sprung.criticallyDamped,
    ));

    // Staggered slide controller - Cinematic entrance
    _staggeredSlideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _heroSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggeredSlideController,
      curve: Interval(0.0, 0.6, curve: Sprung.criticallyDamped),
    ));

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggeredSlideController,
      curve: Interval(0.3, 1.0, curve: Sprung.overDamped),
    ));

    // Hero scale controller - Dramatic entrance
    _heroScaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _heroScaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroScaleController,
      curve: Sprung.overDamped,
    ));

    _contentScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroScaleController,
      curve: Interval(0.4, 1.0, curve: Sprung.criticallyDamped),
    ));

    // Parallax controller for dynamic scrolling effects
    _parallaxController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _parallaxAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _parallaxController,
      curve: Curves.easeOutCubic,
    ));

    // Pulse controller for interactive elements
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Cinematic entrance sequence
    _orchestratePremiumEntrance();

    AppLogger.i('✨ Premium animations initialized with spring physics');
  }

  /// Sinematik giriş orkestrasyon
  void _orchestratePremiumEntrance() {
    _masterFadeController.forward();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggeredSlideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _heroScaleController.forward();
    });

    // Continuous pulse for interactive elements
    _pulseController.repeat(reverse: true);
  }

  /// Gelişmiş scroll listener kurulumu
  void _setupAdvancedScrollListener() {
    _scrollController.addListener(() {
      if (mounted) {
        final newOffset = _scrollController.offset;
        setState(() {
          _scrollOffset = newOffset;
        });

        // Parallax effect for header
        final parallaxValue = (newOffset / 200).clamp(0.0, 1.0);
        _parallaxController.animateTo(parallaxValue);
      }
    });
  }

  /// Dependencies'i ServiceLocator'dan premium şekilde alır
  void _initializeAdvancedDependencies() {
    try {
      if (ServiceLocator.isRegistered<HomeCubit>()) {
        _homeCubit = ServiceLocator.get<HomeCubit>();
        _setupAdvancedAuthCubitIntegration();
        _isInitialized = true;
        AppLogger.i('✅ Premium HomeCubit dependency injection successful');
      } else {
        AppLogger.w('⚠️ HomeCubit not registered, creating premium fallback');
        _createAdvancedFallbackHomeCubit();
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Premium dependency injection error', e, stackTrace);
      _createAdvancedFallbackHomeCubit();
    }
  }

  /// Premium fallback HomeCubit oluşturur
  void _createAdvancedFallbackHomeCubit() {
    try {
      _homeCubit = HomeCubit();
      _setupAdvancedAuthCubitIntegration();
      _isInitialized = true;
      AppLogger.i('🔄 Premium fallback HomeCubit created successfully');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Premium fallback creation failed', e, stackTrace);
      _isInitialized = false;
    }
  }

  /// Advanced AuthCubit integration
  void _setupAdvancedAuthCubitIntegration() {
    try {
      if (_homeCubit == null) {
        AppLogger.w('⚠️ HomeCubit null, skipping AuthCubit integration');
        return;
      }

      if (ServiceLocator.isRegistered<AuthCubit>()) {
        final authCubit = ServiceLocator.get<AuthCubit>();
        _homeCubit!.setAuthCubit(authCubit);
        AppLogger.i('✅ Advanced AuthCubit integration successful');
      } else {
        AppLogger.w('⚠️ AuthCubit not registered, retrying later');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Advanced AuthCubit integration failed', e, stackTrace);
    }
  }

  /// HomeCubit'i premium özelliklerle başlatır
  void _initializeHomeCubitWithEnhancement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeCubit != null && _isInitialized) {
        _homeCubit!.refresh().catchError((e, stackTrace) {
          AppLogger.e('Premium home initial refresh failed', e, stackTrace);
        });
      }
    });
  }

  /// Premium kaynakları temizler
  void _disposePremiumResources() {
    _masterFadeController.dispose();
    _staggeredSlideController.dispose();
    _heroScaleController.dispose();
    _parallaxController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    AppLogger.i('🧹 Premium HomeTabContent resources disposed successfully');
  }

  // ============================================================================
  // 🎨 PREMIUM BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 Premium HomeTabContent rendering - mounted: $mounted');

    if (!_isInitialized || _homeCubit == null) {
      return _buildPremiumErrorScreen();
    }

    return BlocProvider.value(
      value: _homeCubit!,
      child: CupertinoPageScaffold(
        backgroundColor:
            CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            children: [
              _buildPremiumNavigationBar(context),
              Expanded(
                child: _buildPremiumMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✨ Ultra Premium Navigation Bar - Steve Jobs Seviyesinde Glassmorphism
  ///
  /// Advanced glassmorphism efektleri, dynamic blur, ve sophisticated micro-interactions
  /// ile Apple'ın en modern tasarım dilini yansıtan navigation bar.
  Widget _buildPremiumNavigationBar(BuildContext context) {
    return AnimatedBuilder(
      animation: _parallaxAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.only(
            left: context.dimensions.paddingM,
            right: context.dimensions.paddingM,
            top: context.dimensions.paddingM,
            bottom: context.dimensions.paddingS,
          ),
          decoration: BoxDecoration(
            // Ultra premium glassmorphism background
            color: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withOpacity(0.85 + (_parallaxAnimation.value * 0.15)),
            // Advanced backdrop filter would go here
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withOpacity(0.05 * _parallaxAnimation.value),
                blurRadius: 30,
                offset: const Offset(0, 8),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 1,
                offset: const Offset(0, 0.5),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider
                    .withOpacity(_parallaxAnimation.value * 0.4),
                width: 0.33,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🎭 Sol Taraf - Revolutionary Brand Identity
              AnimatedBuilder(
                animation: _heroScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heroScaleAnimation.value,
                    child: Row(
                      children: [
                        // Ultra modern app logo container
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.08),
                                AppColors.primary.withOpacity(0.02),
                                AppColors.primary.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/applogo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: context.dimensions.spaceL),
                        // Revolutionary typography
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main brand name - ultra premium typography
                            Text(
                              'app_title'.locale(context),
                              style: AppTextTheme.headline4.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -1.2,
                                fontSize: 24,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            // Sophisticated tagline
                            Text(
                              'app_subtitle'.locale(context),
                              style: AppTextTheme.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 🎯 Sağ Taraf - Revolutionary Notification System
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.98 + (0.04 * _pulseAnimation.value),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            CupertinoColors.systemBackground
                                .resolveFrom(context)
                                .withOpacity(0.95),
                            CupertinoColors.systemBackground
                                .resolveFrom(context)
                                .withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.divider.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.all(context.dimensions.paddingM),
                        onPressed: () => _showPremiumNotifications(context),
                        child: Icon(
                          CupertinoIcons.bell_fill,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Premium ana içerik with enhanced physics
  Widget _buildPremiumMainContent() {
    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _handlePremiumRefresh,
      color: AppColors.primary,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      displacement: 80,
      strokeWidth: 3.0,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Hero Header Section with parallax
          _buildPremiumHeaderSection(),

          // Enhanced Premium Section - Moved to top priority
          _buildEnhancedPremiumSection(),

          // Premium Stats Section
          _buildPremiumStatsSection(),

          // Recent Analyses with advanced layout
          _buildAdvancedRecentAnalysesSection(),

          // Premium Tips Section
          _buildPremiumTipsSection(),

          // Advanced bottom spacing
          _buildAdvancedBottomSpacing(),
        ],
      ),
    );
  }

  /// Premium error screen with beautiful design
  Widget _buildPremiumErrorScreen() {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          children: [
            _buildPremiumNavigationBar(context),
            Expanded(
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(context.dimensions.paddingXL),
                  padding: EdgeInsets.all(context.dimensions.paddingXL),
                  decoration: BoxDecoration(
                    color:
                        CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CupertinoColors.systemRed.withOpacity(0.2),
                              CupertinoColors.systemRed.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          size: 48,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      SizedBox(height: context.dimensions.spaceL),
                      Text(
                        'app_initialization_error'.locale(context),
                        style: AppTextTheme.headline5.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.dimensions.spaceM),
                      Text(
                        'Lütfen uygulamayı yeniden başlatmayı deneyin.',
                        style: AppTextTheme.bodyText2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.dimensions.spaceXL),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          borderRadius: BorderRadius.circular(16),
                          onPressed: _attemptPremiumRestart,
                          child: Text(
                            'try_again_button'.locale(context),
                            style: AppTextTheme.bodyText1.copyWith(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 🏗️ PREMIUM SECTION BUILDERS
  // ============================================================================

  /// 🚀 Revolutionary Hero Header - Next Generation Parallax Design
  ///
  /// Ultra sophisticated parallax effects, dynamic depth illusion,
  /// ve cinematic entrance animations ile Steve Jobs'un vizyonunu yansıtan header.
  Widget _buildPremiumHeaderSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _masterFadeAnimation,
          _parallaxAnimation,
        ]),
        builder: (context, child) {
          return Transform.translate(
            // Advanced parallax offset calculation
            offset: Offset(0, _scrollOffset * 0.3),
            child: FadeTransition(
              opacity: _masterFadeAnimation,
              child: SlideTransition(
                position: _heroSlideAnimation,
                child: Transform.scale(
                  scale: 1.0 - (_scrollOffset * 0.0005).clamp(0.0, 0.1),
                  child: _buildRevolutionaryHeaderCard(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🎨 Revolutionary Header Card - Ultra Premium Design
  Widget _buildRevolutionaryHeaderCard() {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Primary shadow for depth
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
          // Secondary shadow for sophistication
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 64,
            offset: const Offset(0, 32),
            spreadRadius: -16,
          ),
          // Accent highlight
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Dynamic background image with enhanced effects
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2E7D32),
                      Color(0xFF1B5E20),
                      Color(0xFF388E3C),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: Image.asset(
                  'assets/images/background_3.jpg',
                  fit: BoxFit.cover,
                  color: AppColors.primary.withOpacity(0.7),
                  colorBlendMode: BlendMode.multiply,
                ),
              ),
            ),

            // Revolutionary gradient overlay with depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.85),
                      AppColors.primary.withOpacity(0.65),
                      AppColors.primary.withOpacity(0.75),
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Ultra premium content
            Padding(
              padding: EdgeInsets.all(context.dimensions.paddingXL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revolutionary welcome message
                  AnimatedBuilder(
                    animation: _contentScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _contentScaleAnimation.value,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final headerMessage =
                                    _getTodaysHeaderMessage(context);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      headerMessage['title']!,
                                      style: AppTextTheme.headline2.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                        letterSpacing: -1.0,
                                        fontSize: 32,
                                      ),
                                    ),
                                    SizedBox(height: context.dimensions.spaceM),
                                    Text(
                                      headerMessage['subtitle']!,
                                      style: AppTextTheme.bodyText1.copyWith(
                                        color: Colors.white.withOpacity(0.95),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: context.dimensions.spaceXL),

                  // Revolutionary action buttons
                  _buildRevolutionaryActionButtons(),
                ],
              ),
            ),

            // Subtle accent border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 Revolutionary Action Buttons - Ultra Premium CTA Design
  Widget _buildRevolutionaryActionButtons() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Row(
          children: [
            // Primary CTA - Ultra premium scan button
            Expanded(
              flex: 3,
              child: Transform.scale(
                scale: 0.98 + (0.02 * _pulseAnimation.value),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(18),
                    onPressed: _navigateToAnalysis,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.camera_fill,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'start_analysis'.locale(context),
                          style: AppTextTheme.bodyText1.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(width: context.dimensions.spaceM),

            // Secondary CTA - Elegant history button
            Expanded(
              flex: 2,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: _navigateToAllAnalyses,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.clock_fill,
                        size: 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'history'.locale(context),
                        style: AppTextTheme.bodyText2.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Premium stats section
  Widget _buildPremiumStatsSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _contentScaleAnimation,
        builder: (context, child) {
          return ScaleTransition(
            scale: _contentScaleAnimation,
            child: FadeTransition(
              opacity: _masterFadeAnimation,
              child: const HomeStatsWidget(),
            ),
          );
        },
      ),
    );
  }

  /// Enhanced premium section
  Widget _buildEnhancedPremiumSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _contentScaleAnimation,
        builder: (context, child) {
          return ScaleTransition(
            scale: _contentScaleAnimation,
            child: FadeTransition(
              opacity: _masterFadeAnimation,
              child: HomePremiumCard(
                onPremiumPurchased: () {
                  AppLogger.i('Premium satın alındı - Home ekranından');
                  _homeCubit?.refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🌟 Revolutionary Recent Analyses Section - Next-Gen Design
  ///
  /// Ultra premium card layouts, sophisticated hover effects, advanced animations,
  /// ve engaging user interactions ile Steve Jobs'un vizyonunu yansıtan analyses display.
  Widget _buildAdvancedRecentAnalysesSection() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _masterFadeAnimation,
              _contentScaleAnimation,
            ]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _masterFadeAnimation,
                child: SlideTransition(
                  position: _contentSlideAnimation,
                  child: Transform.scale(
                    scale: _contentScaleAnimation.value,
                    child: _buildRevolutionaryAnalysesContent(state),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Premium tips section
  Widget _buildPremiumTipsSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _masterFadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _masterFadeAnimation,
            child: const HomeTipsWidget(),
          );
        },
      ),
    );
  }

  /// Advanced bottom spacing
  Widget _buildAdvancedBottomSpacing() {
    return SliverToBoxAdapter(
      child: SizedBox(height: context.dimensions.spaceXL),
    );
  }

  // ============================================================================
  // 🎨 PREMIUM CONTENT BUILDING METHODS
  // ============================================================================

  /// 🚀 Revolutionary Analyses Content - Ultra Premium State Management
  ///
  /// Sophisticated state transitions, premium loading animations, ve engaging
  /// empty states ile next-generation user experience.
  Widget _buildRevolutionaryAnalysesContent(HomeState state) {
    if (state.isAnyLoading) {
      return _buildRevolutionaryLoadingState();
    }

    if (!state.hasRecentAnalyses) {
      return _buildRevolutionaryEmptyAnalysesState();
    }

    return _buildRevolutionaryAnalysesList(state);
  }

  /// Premium analyses content with advanced state management (Deprecated - use Revolutionary version)
  Widget _buildAnalysesContent(HomeState state) {
    if (state.isAnyLoading) {
      return _buildPremiumLoadingState();
    }

    if (!state.hasRecentAnalyses) {
      return _buildPremiumEmptyAnalysesState();
    }

    return _buildPremiumAnalysesList(state);
  }

  /// 🎭 Revolutionary Loading State - Ultra Premium Animation
  ///
  /// Multi-layered loading animation, sophisticated gradients, ve mesmerizing
  /// visual feedback ile next-generation loading experience.
  Widget _buildRevolutionaryLoadingState() {
    return Container(
      margin: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevolutionaryAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceM),
          _buildRevolutionaryLoadingCard(),
        ],
      ),
    );
  }

  /// Revolutionary Loading Card
  Widget _buildRevolutionaryLoadingCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * _pulseAnimation.value),
          child: Container(
            padding: EdgeInsets.all(context.dimensions.paddingXL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CupertinoColors.systemBackground.resolveFrom(context),
                  CupertinoColors.systemBackground
                      .resolveFrom(context)
                      .withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: AppColors.primary.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // Revolutionary loading icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.05),
                        AppColors.primary.withOpacity(0.1),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(
                            (0.2 * (_pulseAnimation.value ?? 0.0))
                                .clamp(0.0, 1.0)),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: AppColors.primary.withOpacity(
                          (0.8 + (0.2 * (_pulseAnimation.value ?? 0.0)))
                              .clamp(0.0, 1.0)),
                    ),
                  ),
                ),
                SizedBox(height: context.dimensions.spaceL),
                Text(
                  'Analizleriniz Yükleniyor...',
                  style: AppTextTheme.headline5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceS),
                Text(
                  'loading_latest_analyses'.locale(context),
                  style: AppTextTheme.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Premium loading state with beautiful indicator (Deprecated)
  Widget _buildPremiumLoadingState() {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      padding: EdgeInsets.all(context.dimensions.paddingXL),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium loading animation container
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(
              child: CupertinoActivityIndicator(
                radius: 12,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),
          Text(
            'Analizler Yükleniyor...',
            style: AppTextTheme.bodyText1.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 🌟 Revolutionary Empty Analyses State - Engaging User Experience
  ///
  /// Ultra premium empty state design, sophisticated engagement patterns,
  /// ve motivational user interactions ile next-generation empty experience.
  Widget _buildRevolutionaryEmptyAnalysesState() {
    return Container(
      margin: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevolutionaryAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceM),
          _buildEmptyAnalysisCard(),
        ],
      ),
    );
  }

  /// Premium empty analyses state with beautiful design (Deprecated)
  Widget _buildPremiumEmptyAnalysesState() {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('recent_analyses'.locale(context)),
          SizedBox(height: context.dimensions.spaceM),
          _buildEmptyAnalysisCard(),
        ],
      ),
    );
  }

  /// 🚀 Revolutionary Analyses List - Ultra Premium Layout
  ///
  /// Sophisticated card designs, advanced hover effects, cinematic animations,
  /// ve engaging interaction patterns ile next-generation analyses display.
  Widget _buildRevolutionaryAnalysesList(HomeState state) {
    return Container(
      margin: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevolutionaryAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceM),
          _buildRevolutionaryAnalysesItems(state.recentAnalyses),
        ],
      ),
    );
  }

  /// 🎯 Revolutionary Analyses Header - Premium Typography & Actions
  Widget _buildRevolutionaryAnalysesHeader() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Ultra premium section title - hizalı başlık
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'latest_analyses'.locale(context),
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'latest_analyses_desc'.locale(context),
                  style: AppTextTheme.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            // Revolutionary "see all" button
            Transform.scale(
              scale: 0.98 + (0.02 * _pulseAnimation.value),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.dimensions.paddingM,
                    vertical: context.dimensions.paddingS,
                  ),
                  onPressed: _navigateToAllAnalyses,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'see_all'.locale(context),
                        style: AppTextTheme.bodyText2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.arrow_right,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🎨 Revolutionary Analyses Items - Premium Card Layout
  Widget _buildRevolutionaryAnalysesItems(List<PlantAnalysisModel> analyses) {
    return Column(
      children: analyses.asMap().entries.map((entry) {
        final index = entry.key;
        final analysis = entry.value;

        return AnimatedBuilder(
          animation: _contentScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _contentScaleAnimation.value,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: context.dimensions.spaceM,
                ),
                child: _buildRevolutionaryAnalysisCard(analysis, index),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  /// 🌟 Revolutionary Analysis Card - Ultra Premium Design
  Widget _buildRevolutionaryAnalysisCard(
      PlantAnalysisModel analysis, int index) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.01 * _pulseAnimation.value),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -6,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CupertinoColors.systemBackground.resolveFrom(context),
                      CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (analysis.id.isNotEmpty) {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AnalysisResultScreen(
                            analysisId: analysis.id,
                            analysisResult: analysis,
                          ),
                        ),
                      );
                    }
                  },
                  child: AnalysisCard(
                    analysis: analysis,
                    cardSize: AnalysisCardSize.compact,
                    onTap: () {
                      if (analysis.id.isNotEmpty) {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => AnalysisResultScreen(
                              analysisId: analysis.id,
                              analysisResult: analysis,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Premium analyses list with enhanced layout (Deprecated)
  Widget _buildPremiumAnalysesList(HomeState state) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceS),
          _buildAnalysesItems(state.recentAnalyses),
        ],
      ),
    );
  }

  /// Analyses header with title and "see all" button (Deprecated)
  Widget _buildAnalysesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle('recent_analyses'.locale(context)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _navigateToAllAnalyses,
          child: Text(
            'see_all'.locale(context),
            style: AppTextTheme.bodyText1.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Analyses items list
  Widget _buildAnalysesItems(List<PlantAnalysisModel> analyses) {
    return Column(
      children: analyses.map((analysis) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.dimensions.spaceS),
          child: AnalysisCard(
            analysis: analysis,
            cardSize: AnalysisCardSize.compact,
            onTap: () {
              // Analiz detay sayfasına git
              if (analysis.id.isNotEmpty) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => AnalysisResultScreen(
                      analysisId: analysis.id,
                      analysisResult: analysis,
                    ),
                  ),
                );
              }
            },
          ),
        );
      }).toList(),
    );
  }

  /// Section title widget'ı
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextTheme.headline5.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }

  /// 🎨 Revolutionary Empty Analysis Card - Steve Jobs Seviyesinde Tasarım
  ///
  /// Ultra premium glassmorphism, sophisticated depth illusion, ve engaging
  /// micro-interactions ile kullanıcıyı aksiyona teşvik eden empty state design.
  Widget _buildEmptyAnalysisCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * _pulseAnimation.value),
          child: Container(
            width: double.infinity,
            margin:
                EdgeInsets.symmetric(horizontal: context.dimensions.paddingXS),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                // Primary depth shadow
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: -8,
                ),
                // Secondary ambient shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
              child: Container(
                // Revolutionary glassmorphism background
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withOpacity(0.95),
                      CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withOpacity(0.85),
                      CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                padding: EdgeInsets.all(context.dimensions.paddingXL),
                child: Column(
                  children: [
                    _buildRevolutionaryEmptyStateIcon(),
                    SizedBox(height: context.dimensions.spaceXL),
                    _buildRevolutionaryEmptyStateTitle(),
                    SizedBox(height: context.dimensions.spaceM),
                    _buildRevolutionaryEmptyStateDescription(),
                    SizedBox(height: context.dimensions.spaceXXL),
                    _buildRevolutionaryEmptyStateButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🌟 Revolutionary Empty State Icon - Ultra Premium 3D Design
  ///
  /// Multi-layered depth illusion, sophisticated pulsing, ve mesmerizing
  /// visual effects ile kullanıcının dikkatini çeken icon component.
  Widget _buildRevolutionaryEmptyStateIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.92 + (0.16 * _pulseAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(70),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(
                          (0.15 * (_pulseAnimation.value ?? 0.0))
                              .clamp(0.0, 1.0)),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Middle ring with gradient
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.03),
                      AppColors.primary.withOpacity(0.12),
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                      spreadRadius: -5,
                    ),
                  ],
                ),
              ),
              // Inner icon container with sophisticated gradients
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.05),
                      AppColors.primary.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.leaf_arrow_circlepath,
                  size: 40,
                  color: AppColors.primary.withOpacity(
                      (0.85 + (0.15 * (_pulseAnimation.value ?? 0.0)))
                          .clamp(0.0, 1.0)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🎯 Revolutionary Empty State Title - Premium Typography
  Widget _buildRevolutionaryEmptyStateTitle() {
    return Text(
      'first_analysis_title'.locale(context),
      textAlign: TextAlign.center,
      style: AppTextTheme.headline3.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.8,
        fontSize: 26,
      ),
    );
  }

  /// 🎨 Revolutionary Empty State Description - Engaging Copy
  Widget _buildRevolutionaryEmptyStateDescription() {
    return Text(
      'first_analysis_desc'.locale(context),
      textAlign: TextAlign.center,
      style: AppTextTheme.bodyText1.copyWith(
        color: AppColors.textSecondary,
        height: 1.6,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    );
  }

  /// 🚀 Revolutionary Empty State Button - Ultra Premium CTA
  ///
  /// Multi-dimensional shadows, sophisticated gradients, ve engaging
  /// micro-interactions ile kullanıcıyı aksiyona motive eden button design.
  Widget _buildRevolutionaryEmptyStateButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.97 + (0.03 * _pulseAnimation.value),
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                // Primary action shadow
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
                // Secondary depth shadow
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 60,
                  offset: const Offset(0, 24),
                  spreadRadius: -8,
                ),
                // Dynamic pulse glow
                BoxShadow(
                  color: AppColors.primary.withOpacity(
                      (0.15 * (_pulseAnimation.value ?? 0.0)).clamp(0.0, 1.0)),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(
                  horizontal: context.dimensions.paddingM,
                  vertical: context.dimensions.paddingS,
                ),
                borderRadius: BorderRadius.circular(22),
                onPressed: _navigateToAnalysis,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sophisticated icon container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                    SizedBox(width: context.dimensions.spaceM),
                    // Premium button text - responsive ve flexible
                    Flexible(
                      child: Text(
                        'start_first_analysis'.locale(context),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.bodyText1.copyWith(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: context.dimensions.spaceM),
                    // Elegant arrow indicator
                    Icon(
                      CupertinoIcons.arrow_right_circle_fill,
                      size: 16,
                      color: CupertinoColors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // 🚀 PREMIUM ACTION METHODS
  // ============================================================================

  /// Refresh işlemini gerçekleştirir
  Future<void> _handlePremiumRefresh() async {
    try {
      AppLogger.i('🔄 Pull-to-refresh başlatıldı');
      await _homeCubit?.refresh();
      AppLogger.i('✅ Pull-to-refresh tamamlandı');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Pull-to-refresh hatası', e, stackTrace);
    }
  }

  /// Tüm analizler sayfasına yönlendirir
  void _navigateToAllAnalyses() {
    AppLogger.i('📊 Tüm analizler sayfasına yönlendiriliyor');
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const AllAnalysesScreen(),
      ),
    );
  }

  /// Analiz sayfasına yönlendirir
  void _navigateToAnalysis() {
    AppLogger.i('📷 Analiz sayfasına yönlendiriliyor');

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

  /// Bildirimler gösterir
  void _showPremiumNotifications(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'notifications'.locale(context),
          style: AppTextTheme.headline6.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        message: const Text('Henüz bildiriminiz bulunmuyor.'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('ok'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Emergency restart deneme
  void _attemptPremiumRestart() {
    AppLogger.i('🚨 Emergency restart deneniyor');
    try {
      _initializeAdvancedDependencies();
      _initializeHomeCubitWithEnhancement();
      setState(() {});
    } catch (e, stackTrace) {
      AppLogger.e('❌ Emergency restart başarısız', e, stackTrace);
    }
  }

  /// Günün header mesajını getirir
  Map<String, String> _getTodaysHeaderMessage(BuildContext context) {
    final messages = [
      {
        'title': 'header_message_1_title'.locale(context),
        'subtitle': 'header_message_1_subtitle'.locale(context),
      },
      {
        'title': 'header_message_2_title'.locale(context),
        'subtitle': 'header_message_2_subtitle'.locale(context),
      },
      {
        'title': 'header_message_3_title'.locale(context),
        'subtitle': 'header_message_3_subtitle'.locale(context),
      },
      {
        'title': 'header_message_4_title'.locale(context),
        'subtitle': 'header_message_4_subtitle'.locale(context),
      },
      {
        'title': 'header_message_5_title'.locale(context),
        'subtitle': 'header_message_5_subtitle'.locale(context),
      },
      {
        'title': 'header_message_6_title'.locale(context),
        'subtitle': 'header_message_6_subtitle'.locale(context),
      },
      {
        'title': 'header_message_7_title'.locale(context),
        'subtitle': 'header_message_7_subtitle'.locale(context),
      },
    ];

    final dayOfYear = DateTime.now().dayOfYear;
    return messages[dayOfYear % messages.length];
  }
}
