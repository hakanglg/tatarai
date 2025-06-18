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

  /// Premium navigation bar with glassmorphism
  Widget _buildPremiumNavigationBar(BuildContext context) {
    return AnimatedBuilder(
      animation: _parallaxAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.only(
            left: context.dimensions.paddingM,
            right: context.dimensions.paddingM,
            top: context.dimensions.paddingS,
            bottom: context.dimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withOpacity(0.8 + (_parallaxAnimation.value * 0.2)),
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider
                    .withOpacity(_parallaxAnimation.value * 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sol taraf - Premium brand identity
              AnimatedBuilder(
                animation: _heroScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heroScaleAnimation.value,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.dimensions.paddingS),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.15),
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
                          ),
                          child: Icon(
                            CupertinoIcons.leaf_arrow_circlepath,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        SizedBox(width: context.dimensions.spaceM),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TatarAI',
                              style: AppTextTheme.headline5.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              'Bitki Analiz Asistanı',
                              style: AppTextTheme.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Sağ taraf - Premium notification button
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.divider.withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.all(context.dimensions.paddingS),
                        onPressed: () => _showPremiumNotifications(context),
                        child: Icon(
                          CupertinoIcons.bell_fill,
                          color: AppColors.textSecondary,
                          size: 22,
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

          // Premium Stats Section
          _buildPremiumStatsSection(),

          // Enhanced Premium Section
          _buildEnhancedPremiumSection(),

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
                        'Uygulama Başlatılırken Bir Sorun Oluştu',
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
                            'Yeniden Dene',
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

  /// Hero header section with parallax
  Widget _buildPremiumHeaderSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _masterFadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _masterFadeAnimation,
            child: SlideTransition(
              position: _heroSlideAnimation,
              child: const HomeHeaderWidget(),
            ),
          );
        },
      ),
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

  /// Advanced recent analyses section
  Widget _buildAdvancedRecentAnalysesSection() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _masterFadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _masterFadeAnimation,
                child: SlideTransition(
                  position: _contentSlideAnimation,
                  child: _buildAnalysesContent(state),
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

  /// Premium analyses content with advanced state management
  Widget _buildAnalysesContent(HomeState state) {
    if (state.isAnyLoading) {
      return _buildPremiumLoadingState();
    }

    if (!state.hasRecentAnalyses) {
      return _buildPremiumEmptyAnalysesState();
    }

    return _buildPremiumAnalysesList(state);
  }

  /// Premium loading state with beautiful indicator
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

  /// Premium empty analyses state with beautiful design
  Widget _buildPremiumEmptyAnalysesState() {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Son Analizler'),
          SizedBox(height: context.dimensions.spaceM),
          _buildEmptyAnalysisCard(),
        ],
      ),
    );
  }

  /// Premium analyses list with enhanced layout
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

  /// Analyses header with title and "see all" button
  Widget _buildAnalysesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle('Son Analizler'),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _navigateToAllAnalyses,
          child: Text(
            'Tümünü Gör',
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

  /// Premium empty analysis card with glassmorphism
  Widget _buildEmptyAnalysisCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * _pulseAnimation.value),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.dimensions.paddingL),
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
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: CupertinoColors.systemGrey.withOpacity(0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildEmptyStateIcon(),
                SizedBox(height: context.dimensions.spaceL),
                _buildEmptyStateTitle(),
                SizedBox(height: context.dimensions.spaceM),
                _buildEmptyStateDescription(),
                SizedBox(height: context.dimensions.spaceXL),
                _buildEmptyStateButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Premium empty state icon with pulsing animation
  Widget _buildEmptyStateIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.1 * _pulseAnimation.value),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withOpacity(0.2 * _pulseAnimation.value),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              size: 44,
              color: AppColors.primary
                  .withOpacity(0.8 + (0.2 * _pulseAnimation.value)),
            ),
          ),
        );
      },
    );
  }

  /// Empty state title
  Widget _buildEmptyStateTitle() {
    return Text(
      'Henüz Analiz Yok',
      style: AppTextTheme.headline5.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Empty state description
  Widget _buildEmptyStateDescription() {
    return Text(
      'İlk bitki analizinizi yapmak için kamerayı kullanın ve bitkilerinizin sağlığını öğrenin.',
      textAlign: TextAlign.center,
      style: AppTextTheme.bodyText2.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }

  /// Premium empty state button with gradient and animations
  Widget _buildEmptyStateButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * _pulseAnimation.value),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.primary
                      .withOpacity(0.1 * _pulseAnimation.value),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                  spreadRadius: 5,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 20,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'İlk Analizini Yap',
                    style: AppTextTheme.bodyText1.copyWith(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.arrow_right,
                    size: 16,
                    color: CupertinoColors.white.withOpacity(0.8),
                  ),
                ],
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
    // NavigationManager ile analiz tab'ına geç
    // Bu implementasyon NavigationManager'a bağlı
  }

  /// Bildirimler gösterir
  void _showPremiumNotifications(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Bildirimler',
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
            child: const Text('Tamam'),
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
}
