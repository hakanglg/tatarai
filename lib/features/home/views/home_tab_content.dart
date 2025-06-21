import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../../core/utils/logger.dart';
import '../widgets/home_premium_card.dart';
import '../../plant_analysis/data/models/plant_analysis_model.dart';
import '../../plant_analysis/presentation/views/all_analysis/all_analyses_screen.dart';
import '../../plant_analysis/presentation/views/widgets/analysis_card.dart';
import '../../plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';
import '../cubits/home_cubit.dart';
import '../cubits/home_state.dart';
import '../widgets/home_stats_widget.dart';
import '../widgets/home_tips_widget.dart';
import '../../auth/cubits/auth_cubit.dart';
import '../../navbar/navigation_manager.dart';

/// 🍃 Modern Ana Ekran Tab İçeriği
///
/// Apple Human Interface Guidelines uyumlu, Clean Architecture prensiplerine
/// uygun ana ekran tasarımı. Basit ve performanslı tasarım.
///
/// ✨ Özellikler:
/// - Modern iOS tasarım dili
/// - Pull-to-refresh desteği
/// - Responsive layout
/// - HomeCubit ile reactive state management
/// - ServiceLocator dependency injection
/// - Performans optimizasyonu
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  // ============================================================================
  // 🎮 CONTROLLERS & STATE
  // ============================================================================

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  HomeCubit? _homeCubit;
  bool _isInitialized = false;

  // ============================================================================
  // 🏗️ LIFECYCLE METHODS
  // ============================================================================

  @override
  void initState() {
    super.initState();
    AppLogger.i('🍃 HomeTabContent başlatılıyor');
    _initializeDependencies();
    _initializeHomeCubit();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppLogger.i('🧹 HomeTabContent kaynakları temizlendi');
    super.dispose();
  }

  // ============================================================================
  // 🚀 INITIALIZATION METHODS
  // ============================================================================

  /// Dependencies'i ServiceLocator'dan alır
  void _initializeDependencies() {
    try {
      if (ServiceLocator.isRegistered<HomeCubit>()) {
        _homeCubit = ServiceLocator.get<HomeCubit>();
        _setupAuthCubitIntegration();
        _isInitialized = true;
        AppLogger.i('✅ HomeCubit dependency injection başarılı');
      } else {
        AppLogger.w('⚠️ HomeCubit kayıtlı değil, fallback oluşturuluyor');
        _createFallbackHomeCubit();
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Dependency injection hatası', e, stackTrace);
      _createFallbackHomeCubit();
    }
  }

  /// Fallback HomeCubit oluşturur
  void _createFallbackHomeCubit() {
    try {
      _homeCubit = HomeCubit();
      _setupAuthCubitIntegration();
      _isInitialized = true;
      AppLogger.i('🔄 Fallback HomeCubit oluşturuldu');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Fallback oluşturma hatası', e, stackTrace);
      _isInitialized = false;
    }
  }

  /// AuthCubit entegrasyonu
  void _setupAuthCubitIntegration() {
    try {
      if (_homeCubit == null) {
        AppLogger.w('⚠️ HomeCubit null, AuthCubit entegrasyonu atlanıyor');
        return;
      }

      if (ServiceLocator.isRegistered<AuthCubit>()) {
        final authCubit = ServiceLocator.get<AuthCubit>();
        _homeCubit!.setAuthCubit(authCubit);
        AppLogger.i('✅ AuthCubit entegrasyonu başarılı');
      } else {
        AppLogger.w('⚠️ AuthCubit kayıtlı değil');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ AuthCubit entegrasyon hatası', e, stackTrace);
    }
  }

  /// HomeCubit'i başlatır
  void _initializeHomeCubit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeCubit != null && _isInitialized) {
        _homeCubit!.refresh().catchError((e, stackTrace) {
          AppLogger.e('Initial refresh hatası', e, stackTrace);
        });
      }
    });
  }

  // ============================================================================
  // 🎨 BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 HomeTabContent rendering - mounted: $mounted');

    // Initialization kontrolü
    if (!_isInitialized || _homeCubit == null) {
      return _buildErrorScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor:
            CupertinoColors.systemGroupedBackground.resolveFrom(context),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: BlocProvider.value(
        value: _homeCubit!,
        child: CupertinoPageScaffold(
          backgroundColor:
              CupertinoColors.systemGroupedBackground.resolveFrom(context),
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
      ),
    );
  }

  /// Basit navigation bar
  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.3),
            width: 0.33,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo ve başlık
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 0.5,
                  ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'app_title'.locale(context),
                    style: AppTextTheme.headline4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'app_subtitle'.locale(context),
                    style: AppTextTheme.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Bildirim butonu
          CupertinoButton(
            padding: EdgeInsets.all(context.dimensions.paddingM),
            onPressed: () => _showNotifications(context),
            child: Icon(
              CupertinoIcons.bell_fill,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Ana içerik
  Widget _buildMainContent() {
    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildHeaderSection(),
          _buildPremiumSection(),
          _buildStatsSection(),
          _buildAnalysesSection(),
          _buildTipsSection(),
          SliverToBoxAdapter(
            child: SizedBox(height: context.dimensions.spaceXL),
          ),
        ],
      ),
    );
  }

  /// Header bölümü
  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(context.dimensions.paddingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Arka plan görsel
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
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
              // İçerik
              Padding(
                padding: EdgeInsets.all(context.dimensions.paddingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header mesajı
                    Builder(
                      builder: (context) {
                        final headerMessage = _getTodaysHeaderMessage(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerMessage['title']!,
                              style: AppTextTheme.headline2.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 32,
                              ),
                            ),
                            SizedBox(height: context.dimensions.spaceM),
                            Text(
                              headerMessage['subtitle']!,
                              style: AppTextTheme.bodyText1.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.dimensions.spaceXL),
                    // Aksiyon butonları
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aksiyon butonları
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Ana buton - Analiz başlat
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: () {
              AppLogger.i('🎯 Header Analiz Başlat basıldı');
              _navigateToAnalysis();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'start_analysis'.locale(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: context.dimensions.spaceM),
        // İkincil buton - Geçmiş
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              AppLogger.i('🎯 Header Geçmiş basıldı');
              _navigateToAllAnalyses();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.clock_fill, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'history'.locale(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Premium bölümü
  Widget _buildPremiumSection() {
    return SliverToBoxAdapter(
      child: HomePremiumCard(
        onPremiumPurchased: () {
          AppLogger.i('Premium satın alındı - Home ekranından');
          _homeCubit?.refresh();
        },
      ),
    );
  }

  /// İstatistikler bölümü
  Widget _buildStatsSection() {
    return const SliverToBoxAdapter(
      child: HomeStatsWidget(),
    );
  }

  /// Analizler bölümü
  Widget _buildAnalysesSection() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SliverToBoxAdapter(
          child: _buildAnalysesContent(state),
        );
      },
    );
  }

  /// İpuçları bölümü
  Widget _buildTipsSection() {
    return const SliverToBoxAdapter(
      child: HomeTipsWidget(),
    );
  }

  /// Analizler içeriği
  Widget _buildAnalysesContent(HomeState state) {
    if (state.isAnyLoading) {
      return _buildLoadingState();
    }

    if (!state.hasRecentAnalyses) {
      return _buildEmptyAnalysesState();
    }

    return _buildAnalysesList(state);
  }

  /// Yükleniyor durumu
  Widget _buildLoadingState() {
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
        children: [
          const CupertinoActivityIndicator(color: AppColors.primary),
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

  /// Boş analizler durumu
  Widget _buildEmptyAnalysesState() {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceM),
          _buildEmptyAnalysisCard(),
        ],
      ),
    );
  }

  /// Analizler listesi
  Widget _buildAnalysesList(HomeState state) {
    return Container(
      margin: EdgeInsets.all(context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysesHeader(),
          SizedBox(height: context.dimensions.spaceM),
          ...state.recentAnalyses.map((analysis) => Padding(
                padding: EdgeInsets.only(bottom: context.dimensions.spaceS),
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
              )),
        ],
      ),
    );
  }

  /// Analizler başlığı
  Widget _buildAnalysesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'latest_analyses'.locale(context),
              style: AppTextTheme.headline5.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'latest_analyses_desc'.locale(context),
              style: AppTextTheme.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            AppLogger.i('🎯 Tümünü Gör basıldı');
            _navigateToAllAnalyses();
          },
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

  /// Boş analiz kartı
  Widget _buildEmptyAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.dimensions.paddingXL),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // İkon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: context.dimensions.spaceXL),
          // Başlık
          Text(
            'first_analysis_title'.locale(context),
            textAlign: TextAlign.center,
            style: AppTextTheme.headline3.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 26,
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),
          // Açıklama
          Text(
            'first_analysis_desc'.locale(context),
            textAlign: TextAlign.center,
            style: AppTextTheme.bodyText1.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          SizedBox(height: context.dimensions.spaceXXL),
          // Aksiyon butonu
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () {
                AppLogger.i('🎯 İlk Analiz Başlat basıldı');
                _navigateToAnalysis();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'start_first_analysis'.locale(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.arrow_right_circle_fill,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hata ekranı
  Widget _buildErrorScreen() {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          children: [
            _buildNavigationBar(context),
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
                          onPressed: _attemptRestart,
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
  // 🚀 ACTION METHODS
  // ============================================================================

  /// Refresh işlemi
  Future<void> _handleRefresh() async {
    try {
      AppLogger.i('🔄 Pull-to-refresh başlatıldı');
      await _homeCubit?.refresh();
      AppLogger.i('✅ Pull-to-refresh tamamlandı');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Pull-to-refresh hatası', e, stackTrace);
    }
  }

  /// Tüm analizler sayfasına git
  void _navigateToAllAnalyses() {
    AppLogger.i('📊 Tüm analizler sayfasına yönlendiriliyor');
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const AllAnalysesScreen(),
      ),
    );
  }

  /// Analiz sayfasına git
  void _navigateToAnalysis() {
    AppLogger.i('📷 Analiz sayfasına yönlendiriliyor');

    try {
      final navigationManager = NavigationManager.instance;
      if (navigationManager != null) {
        AppLogger.i('🎯 NavigationManager bulundu, tab değiştiriliyor');
        navigationManager.switchToTab(1);
        AppLogger.i('🚀 Analysis tab\'ına geçiş yapıldı');
      } else {
        AppLogger.w(
            '⚠️ NavigationManager instance bulunamadı, initialize ediliyor');
        NavigationManager.initialize(initialIndex: 1);
        final newNavigationManager = NavigationManager.instance;
        if (newNavigationManager != null) {
          newNavigationManager.switchToTab(1);
          AppLogger.i(
              '🔄 NavigationManager initialize edildi ve tab değiştirildi');
        } else {
          AppLogger.e('❌ NavigationManager initialize edilemedi');
        }
      }
    } catch (e, stack) {
      AppLogger.e('❌ Analysis tab geçiş hatası', e, stack);
    }
  }

  /// Bildirimleri göster
  void _showNotifications(BuildContext context) {
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

  /// Yeniden başlatma denemesi
  void _attemptRestart() {
    AppLogger.i('🚨 Yeniden başlatma deneniyor');
    try {
      _initializeDependencies();
      _initializeHomeCubit();
      setState(() {});
    } catch (e, stackTrace) {
      AppLogger.e('❌ Yeniden başlatma başarısız', e, stackTrace);
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

    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return messages[dayOfYear % messages.length];
  }
}
