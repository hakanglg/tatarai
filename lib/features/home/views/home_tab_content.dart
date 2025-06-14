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
import '../../../core/widgets/premium_button.dart';
import '../../plant_analysis/presentation/views/all_analysis/all_analyses_screen.dart';
import '../../plant_analysis/presentation/views/widgets/analysis_card.dart';
import '../constants/home_constants.dart';
import '../cubits/home_cubit.dart';
import '../cubits/home_state.dart';
import '../widgets/home_header_widget.dart';
import '../widgets/home_quick_actions_widget.dart';
import '../../../core/init/app_initializer.dart';
import '../../auth/cubits/auth_cubit.dart';

/// Ana ekran tab içeriği
///
/// Bu widget home tab'ının ana içeriğini oluşturur.
/// Clean Architecture prensiplerine uygun olarak modüler
/// component'lerden oluşmuştur.
///
/// Özellikler:
/// - Modern iOS tasarımı
/// - Pull-to-refresh desteği
/// - Animasyonlu geçişler
/// - HomeCubit ile state management
/// - ServiceLocator dependency injection
/// - Apple HIG uyumlu scroll behavior
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent>
    with SingleTickerProviderStateMixin {
  // ============================================================================
  // ANIMATION PROPERTIES
  // ============================================================================

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ============================================================================
  // CONTROLLERS
  // ============================================================================

  final ScrollController _scrollController = ScrollController();

  // ============================================================================
  // CUBIT DEPENDENCIES
  // ============================================================================

  HomeCubit? _homeCubit;

  @override
  void initState() {
    super.initState();
    AppLogger.i('🏠 HomeTabContent başlatılıyor');

    _initializeDependencies();
    _initializeAnimations();
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

  /// Dependencies'i ServiceLocator'dan alır
  void _initializeDependencies() {
    try {
      AppLogger.i('🔧 HomeTabContent dependencies initialization başlıyor');

      // ServiceLocator durumunu kontrol et
      if (!AppInitializer.instance.isInitialized) {
        AppLogger.w('⚠️ AppInitializer henüz tamamlanmamış');
      }

      // HomeCubit register durumunu kontrol et
      if (!ServiceLocator.isRegistered<HomeCubit>()) {
        AppLogger.w('⚠️ ServiceLocator\'da HomeCubit register olmamış');

        // Fallback: Direkt HomeCubit oluştur
        AppLogger.i('🛠️ Fallback: Direkt HomeCubit oluşturuluyor');
        _homeCubit = HomeCubit();

        // AuthCubit'i manuel olarak set etmeye çalış
        _trySetAuthCubitToHomeCubit();

        AppLogger.i('✅ HomeCubit fallback ile oluşturuldu');
        return;
      }

      // ServiceLocator'dan HomeCubit al
      AppLogger.i('🔄 ServiceLocator\'dan HomeCubit alınıyor');
      _homeCubit = ServiceLocator.get<HomeCubit>();

      // AuthCubit'i manuel olarak set etmeye çalış
      _trySetAuthCubitToHomeCubit();

      AppLogger.i('✅ HomeTabContent dependencies başarıyla initialize edildi');
    } catch (e, stackTrace) {
      AppLogger.e(
          '❌ HomeTabContent dependency initialization failed', e, stackTrace);

      // Fallback: Direkt HomeCubit oluştur
      try {
        AppLogger.i('🔄 Fallback: Emergency HomeCubit oluşturuluyor');
        _homeCubit = HomeCubit();

        // AuthCubit'i manuel olarak set etmeye çalış
        _trySetAuthCubitToHomeCubit();

        AppLogger.i('✅ HomeCubit emergency fallback ile oluşturuldu');
      } catch (fallbackError, fallbackStackTrace) {
        AppLogger.e('❌ HomeCubit emergency fallback oluşturma hatası',
            fallbackError, fallbackStackTrace);

        // Son çare: _homeCubit null kalacak ve error screen gösterilecek
        AppLogger.e('💥 HomeCubit hiçbir şekilde oluşturulamadı');
      }
    }
  }

  /// HomeCubit'e AuthCubit'i set etmeye çalışır
  void _trySetAuthCubitToHomeCubit() {
    try {
      if (_homeCubit == null) {
        AppLogger.w('⚠️ HomeCubit null, AuthCubit set edilemez');
        return;
      }

      // AuthCubit'i ServiceLocator'dan almaya çalış
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

  /// Animasyonları başlatır
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: HomeConstants.animationDurationMs),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    AppLogger.i('✨ HomeTabContent animasyonları başlatıldı');
  }

  /// HomeCubit'i başlatır ve initial data yükler
  void _initializeHomeCubit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeCubit?.refresh().catchError((e, stackTrace) {
        AppLogger.e('Home initial refresh failed', e, stackTrace);
      });
    });
  }

  /// Kaynakları temizler
  void _disposeResources() {
    _animationController.dispose();
    _scrollController.dispose();
    AppLogger.i('🧹 HomeTabContent kaynakları temizlendi');
  }

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 HomeTabContent build - mounted: $mounted');

    // HomeCubit'in initialize olup olmadığını kontrol et
    if (!_isHomeCubitInitialized()) {
      AppLogger.e('HomeCubit initialize olmamış, emergency fallback');
      return _buildErrorScreen();
    }

    return BlocProvider.value(
      value: _homeCubit!,
      child: CupertinoPageScaffold(
        navigationBar: _buildNavigationBar(),
        child: SafeArea(
          child: _buildScrollableContent(),
        ),
      ),
    );
  }

  /// HomeCubit'in initialize olup olmadığını kontrol eder
  bool _isHomeCubitInitialized() {
    return _homeCubit != null;
  }

  /// Hata durumunda gösterilecek emergency screen
  Widget _buildErrorScreen() {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: SafeArea(
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
                onPressed: () {
                  AppLogger.i('Emergency restart button pressed');
                  // Sayfa yenileme deneme
                  _attemptEmergencyRestart();
                },
                child: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Emergency restart deneme
  void _attemptEmergencyRestart() {
    try {
      AppLogger.i('🔄 Emergency restart başlatılıyor');

      // HomeCubit'i yeniden initialize etmeye çalış
      _initializeDependencies();

      if (_isHomeCubitInitialized()) {
        // HomeCubit başarılı ama AuthCubit set edilmemiş olabilir, tekrar dene
        _trySetAuthCubitToHomeCubit();

        // Başarılıysa setState ile widget'ı rebuild et
        setState(() {});
        AppLogger.i('✅ Emergency restart başarılı');
      } else {
        AppLogger.e('❌ Emergency restart başarısız - HomeCubit oluşturulamadı');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Emergency restart hatası', e, stackTrace);
    }
  }

  /// Navigation bar oluşturur
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      middle: Text(
        AppConstants.appName,
        style: AppTextTheme.headline5.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: HomeConstants.headerLetterSpacing,
        ),
      ),
      backgroundColor: AppColors.background.withValues(alpha: 0.9),
      border: null,
    );
  }

  /// Scrollable content oluşturur
  Widget _buildScrollableContent() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildHeaderSection(),
          _buildQuickActionsSection(),
          _buildPremiumSection(),
          _buildRecentAnalysesSection(),
          _buildBottomSpacing(),
        ],
      ),
    );
  }

  /// Header section oluşturur
  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: const HomeHeaderWidget(),
            ),
          );
        },
      ),
    );
  }

  /// Quick actions section oluşturur
  Widget _buildQuickActionsSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - _fadeAnimation.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: const HomeQuickActionsWidget(),
            ),
          );
        },
      ),
    );
  }

  /// Premium section oluşturur
  Widget _buildPremiumSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 35 * (1 - _fadeAnimation.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.dimensions.paddingM,
                  vertical: context.dimensions.paddingS,
                ),
                child: PremiumButton.home(
                  onPremiumPurchased: () {
                    AppLogger.i('Premium satın alındı - Home ekranından');
                    _homeCubit?.refresh();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Recent analyses section oluşturur
  Widget _buildRecentAnalysesSection() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - _fadeAnimation.value)),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: _buildAnalysesContent(state),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Bottom spacing oluşturur
  Widget _buildBottomSpacing() {
    return SliverToBoxAdapter(
      child: SizedBox(height: context.dimensions.spaceL),
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
          _buildSectionTitle('recent_analyses'),
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
        _buildSectionTitle('recent_analyses'),
        AppButton(
          text: 'all_analyses'.locale(context),
          type: AppButtonType.text,
          onPressed: _navigateToAllAnalyses,
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
  Widget _buildSectionTitle(String titleKey) {
    return Text(
      titleKey.locale(context),
      style: AppTextTheme.headline5.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: HomeConstants.titleLetterSpacing,
      ),
    );
  }

  /// Empty analysis card widget'ı
  Widget _buildEmptyAnalysisCard() {
    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(35),
      ),
      child: const Icon(
        CupertinoIcons.leaf_arrow_circlepath,
        size: 32,
        color: AppColors.primary,
      ),
    );
  }

  /// Empty state title
  Widget _buildEmptyStateTitle() {
    return Text(
      'no_analysis_yet'.locale(context),
      style: AppTextTheme.headline5.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: HomeConstants.titleLetterSpacing,
      ),
    );
  }

  /// Empty state description
  Widget _buildEmptyStateDescription() {
    return Text(
      'no_analysis_desc'.locale(context),
      textAlign: TextAlign.center,
      style: AppTextTheme.body.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }

  /// Empty state action button
  Widget _buildEmptyStateButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(
          vertical: context.dimensions.paddingS,
        ),
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(context.dimensions.radiusM),
        onPressed: _navigateToAnalysis,
        child: Text(
          'analyze'.locale(context),
          style: AppTextTheme.button.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: HomeConstants.titleLetterSpacing,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // NAVIGATION METHODS
  // ============================================================================

  /// Analiz ekranına yönlendirir
  void _navigateToAnalysis() {
    try {
      // Navigation logic moved to HomeQuickActionsWidget
      AppLogger.i('Analysis navigation triggered from empty state');
    } catch (e) {
      AppLogger.e('Analysis navigation failed', e);
    }
  }

  /// Tüm analizler ekranına yönlendirir
  void _navigateToAllAnalyses() {
    try {
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (context) => const AllAnalysesScreen(),
        ),
      );
      AppLogger.i('Navigated to all analyses screen');
    } catch (e) {
      AppLogger.e('All analyses navigation failed', e);
    }
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  /// Pull-to-refresh handler
  Future<void> _handleRefresh() async {
    try {
      AppLogger.i('🔄 Home pull-to-refresh triggered');
      await _homeCubit?.refresh();

      // UI feedback için kısa delay
      await Future<void>.delayed(HomeConstants.refreshCompletionDelay);

      AppLogger.i('✅ Home refresh completed');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Home refresh failed', e, stackTrace);
    }
  }
}
