import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button.dart';
import '../widgets/home_premium_card.dart';
import '../../plant_analysis/presentation/views/all_analysis/all_analyses_screen.dart';
import '../../plant_analysis/presentation/views/widgets/analysis_card.dart';
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

/// Modern Ana Ekran Tab İçeriği
///
/// Apple Human Interface Guidelines uyumlu, modern ve kullanıcı dostu
/// ana ekran tasarımı. Clean Architecture prensiplerine uygun modüler yapı.
///
/// Özellikler:
/// - Modern iOS 17 tasarım dili
/// - Smooth animasyonlar ve geçişler
/// - Pull-to-refresh desteği
/// - Responsive layout
/// - Accessibility desteği
/// - HomeCubit ile state management
/// - ServiceLocator dependency injection
/// - Apple HIG uyumlu scroll behavior
/// - Haptic feedback desteği
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent>
    with TickerProviderStateMixin {
  // ============================================================================
  // ANIMATION CONTROLLERS
  // ============================================================================

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // ============================================================================
  // CONTROLLERS
  // ============================================================================

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  // ============================================================================
  // CUBIT DEPENDENCIES
  // ============================================================================

  HomeCubit? _homeCubit;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    AppLogger.i('🏠 Modern HomeTabContent başlatılıyor');

    _initializeAnimations();
    _initializeDependencies();
    _initializeHomeCubit();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  /// Animasyonları başlatır
  void _initializeAnimations() {
    // Fade animasyonu
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    // Slide animasyonu
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Scale animasyonu
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    // Animasyonları başlat
    _startAnimations();

    AppLogger.i('✨ Modern animasyonlar başlatıldı');
  }

  /// Animasyonları sıralı olarak başlatır
  void _startAnimations() {
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _scaleController.forward();
    });
  }

  /// Dependencies'i ServiceLocator'dan alır
  void _initializeDependencies() {
    try {
      if (ServiceLocator.isRegistered<HomeCubit>()) {
        _homeCubit = ServiceLocator.get<HomeCubit>();
        _trySetAuthCubitToHomeCubit();
        _isInitialized = true;
        AppLogger.i('✅ HomeCubit ServiceLocator\'dan alındı');
      } else {
        AppLogger.w('⚠️ HomeCubit henüz register olmamış');
        _createFallbackHomeCubit();
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ HomeCubit dependency injection hatası', e, stackTrace);
      _createFallbackHomeCubit();
    }
  }

  /// Fallback HomeCubit oluşturur
  void _createFallbackHomeCubit() {
    try {
      _homeCubit = HomeCubit();
      _trySetAuthCubitToHomeCubit();
      _isInitialized = true;
      AppLogger.i('🔄 Fallback HomeCubit oluşturuldu');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Fallback HomeCubit oluşturma hatası', e, stackTrace);
      _isInitialized = false;
    }
  }

  /// HomeCubit'e AuthCubit'i set etmeye çalışır
  void _trySetAuthCubitToHomeCubit() {
    try {
      if (_homeCubit == null) {
        AppLogger.w('⚠️ HomeCubit null, AuthCubit set edilemez');
        return;
      }

      if (ServiceLocator.isRegistered<AuthCubit>()) {
        final authCubit = ServiceLocator.get<AuthCubit>();
        _homeCubit!.setAuthCubit(authCubit);
        AppLogger.i('✅ AuthCubit başarıyla HomeCubit\'e set edildi');
      } else {
        AppLogger.w('⚠️ AuthCubit henüz register olmamış, sonra denenecek');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ AuthCubit set etme hatası', e, stackTrace);
    }
  }

  /// HomeCubit'i başlatır ve initial data yükler
  void _initializeHomeCubit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeCubit != null && _isInitialized) {
        _homeCubit!.refresh().catchError((e, stackTrace) {
          AppLogger.e('Home initial refresh failed', e, stackTrace);
        });
      }
    });
  }

  /// Kaynakları temizler
  void _disposeResources() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _scrollController.dispose();
    AppLogger.i('🧹 Modern HomeTabContent kaynakları temizlendi');
  }

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 Modern HomeTabContent build - mounted: $mounted');

    if (!_isInitialized || _homeCubit == null) {
      return _buildErrorScreen();
    }

    return BlocProvider.value(
      value: _homeCubit!,
      child: CupertinoPageScaffold(
        child: SafeArea(
          child: Column(
            children: [
              _buildNavigationBar(context),
              Expanded(
                child: _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigation bar oluşturur
  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol taraf - Logo/Başlık
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.dimensions.paddingXS),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.leaf_arrow_circlepath,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: context.dimensions.spaceS),
              Text(
                'TatarAI',
                style: AppTextTheme.headline5.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Sağ taraf - Bildirimler
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.all(context.dimensions.paddingS),
              onPressed: () => _showNotifications(context),
              child: Icon(
                CupertinoIcons.bell,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ana içerik oluşturur
  Widget _buildMainContent() {
    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Header Section
          _buildHeaderSection(),

          // Premium Section (moved to top for visibility)
          _buildPremiumSection(),

          // Quick Stats Section
          _buildQuickStatsSection(),

          // Quick Actions Section
          // _buildQuickActionsSection(),

          // Recent Analyses Section
          _buildRecentAnalysesSection(),

          // Tips Section
          _buildTipsSection(),

          // Bottom Spacing
          _buildBottomSpacing(),
        ],
      ),
    );
  }

  /// Hata durumunda gösterilecek emergency screen
  Widget _buildErrorScreen() {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            _buildNavigationBar(context),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 64,
                      color: CupertinoColors.systemRed,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Uygulama başlatılırken bir sorun oluştu',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      onPressed: _attemptEmergencyRestart,
                      child: const Text('Yeniden Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECTION BUILDERS
  // ============================================================================

  /// Header section oluşturur
  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: const HomeHeaderWidget(),
            ),
          );
        },
      ),
    );
  }

  /// Quick stats section oluşturur
  Widget _buildQuickStatsSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const HomeStatsWidget(),
            ),
          );
        },
      ),
    );
  }

  /// Quick actions section oluşturur
  // Widget _buildQuickActionsSection() {
  //   return SliverToBoxAdapter(
  //     child: AnimatedBuilder(
  //       animation: _slideAnimation,
  //       builder: (context, child) {
  //         return SlideTransition(
  //           position: _slideAnimation,
  //           child: FadeTransition(
  //             opacity: _fadeAnimation,
  //             child: const HomeQuickActionsWidget(),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  /// Recent analyses section oluşturur
  Widget _buildRecentAnalysesSection() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildAnalysesContent(state),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Tips section oluşturur
  Widget _buildTipsSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: const HomeTipsWidget(),
          );
        },
      ),
    );
  }

  /// Premium section oluşturur
  Widget _buildPremiumSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
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

  /// Bottom spacing oluşturur
  Widget _buildBottomSpacing() {
    return SliverToBoxAdapter(
      child: SizedBox(height: context.dimensions.spaceXL),
    );
  }

  // ============================================================================
  // CONTENT BUILDING METHODS
  // ============================================================================

  /// Analyses content'ini state'e göre oluşturur
  Widget _buildAnalysesContent(HomeState state) {
    if (state.isAnyLoading) {
      return _buildLoadingState();
    }

    if (!state.hasRecentAnalyses) {
      return _buildEmptyAnalysesState();
    }

    return _buildAnalysesList(state);
  }

  /// Loading state widget'ı
  Widget _buildLoadingState() {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: const Center(
        child: CupertinoActivityIndicator(),
      ),
    );
  }

  /// Empty analyses state widget'ı
  Widget _buildEmptyAnalysesState() {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Son Analizler'),
          SizedBox(height: context.dimensions.spaceS),
          _buildEmptyAnalysisCard(),
        ],
      ),
    );
  }

  /// Analyses list widget'ı
  Widget _buildAnalysesList(HomeState state) {
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
  Widget _buildAnalysesItems(List<dynamic> analyses) {
    return Column(
      children: analyses.map((analysis) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.dimensions.spaceS),
          child: AnalysisCard(
            analysis: analysis,
            cardSize: AnalysisCardSize.compact,
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

  /// Empty analysis card widget'ı
  Widget _buildEmptyAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.dimensions.paddingS),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEmptyStateIcon(),
          SizedBox(height: context.dimensions.spaceM),
          _buildEmptyStateTitle(),
          SizedBox(height: context.dimensions.spaceS),
          _buildEmptyStateDescription(),
          SizedBox(height: context.dimensions.spaceL),
          _buildEmptyStateButton(),
        ],
      ),
    );
  }

  /// Empty state icon
  Widget _buildEmptyStateIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
      ),
      child: const Icon(
        CupertinoIcons.leaf_arrow_circlepath,
        size: 36,
        color: AppColors.primary,
      ),
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

  /// Empty state button
  Widget _buildEmptyStateButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
        onPressed: _navigateToAnalysis,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.camera_fill,
              size: 18,
              color: CupertinoColors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'İlk Analizini Yap',
              style: AppTextTheme.bodyText1.copyWith(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ACTION METHODS
  // ============================================================================

  /// Refresh işlemini gerçekleştirir
  Future<void> _handleRefresh() async {
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
  void _showNotifications(BuildContext context) {
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
  void _attemptEmergencyRestart() {
    AppLogger.i('🚨 Emergency restart deneniyor');
    try {
      _initializeDependencies();
      _initializeHomeCubit();
      setState(() {});
    } catch (e, stackTrace) {
      AppLogger.e('❌ Emergency restart başarısız', e, stackTrace);
    }
  }
}
