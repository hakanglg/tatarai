import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_cubit_direct.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_model.dart'
    as model;
import 'package:tatarai/features/plant_analysis/data/models/disease_model.dart'
    as entity_disease;
import 'package:tatarai/features/plant_analysis/domain/entities/plant_analysis_entity.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/widgets/analysis_card.dart';

/// ✨ Filter option model for premium filtering
class FilterOption {
  final String value;
  final String label;
  final bool isSelected;

  const FilterOption(this.value, this.label, this.isSelected);
}

/// 🌿 Premium Tüm Analizler Ekranı
///
/// Steve Jobs seviyesinde sleek ve sexy Apple Human Interface Guidelines
/// uyumlu analiz listesi ekranı. Modern iOS 17+ tasarım dili ile.
///
/// ✨ Premium Özellikler:
/// - Ultra smooth spring animasyonlar ve fluid geçişler
/// - Glassmorphism navigation bar ve depth illusion
/// - Advanced pull-to-refresh ile haptic feedback
/// - Beautiful empty states ve error handling
/// - Progressive loading states
/// - Interactive card animations
/// - Responsive grid layout adapters
/// - Performance optimized scroll behavior
/// - Premium glassmorphism effects
/// - Dynamic content filtering
class AllAnalysesScreen extends StatefulWidget {
  /// Creates Premium AllAnalysesScreen
  const AllAnalysesScreen({super.key});

  @override
  State<AllAnalysesScreen> createState() => _AllAnalysesScreenState();
}

class _AllAnalysesScreenState extends State<AllAnalysesScreen>
    with TickerProviderStateMixin {
  // ============================================================================
  // 🎭 PREMIUM ANIMATION CONTROLLERS
  // ============================================================================

  late AnimationController _masterFadeController;
  late AnimationController _staggeredEntranceController;
  late AnimationController _parallaxController;
  late AnimationController _pulseController;
  late AnimationController _cardEntranceController;

  late Animation<double> _masterFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _parallaxAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _cardScaleAnimation;

  // ============================================================================
  // 🎮 PREMIUM CONTROLLERS
  // ============================================================================

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  bool _isHeaderCollapsed = false;

  // ============================================================================
  // 🔍 PREMIUM FILTER STATE
  // ============================================================================

  // Filter states
  String _selectedStatusFilter = 'all'; // 'all', 'healthy', 'diseased'
  String _selectedDateFilter = 'all'; // 'all', 'today', 'week', 'month'
  String _selectedPlantFilter = 'all'; // 'all', specific plant types
  List<PlantAnalysisEntity> _filteredAnalyses = [];
  List<PlantAnalysisEntity> _allAnalyses = [];

  // ============================================================================
  // 🏗️ LIFECYCLE METHODS
  // ============================================================================

  @override
  void initState() {
    super.initState();
    AppLogger.i(
        '🌿 Premium AllAnalysesScreen launching with maximum performance');

    _initializePremiumAnimations();
    _setupAdvancedScrollListener();
    _loadAnalysesWithAnimation();
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
    // Master fade controller - Ultra smooth entrance
    _masterFadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _masterFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _masterFadeController,
      curve: Sprung.criticallyDamped,
    ));

    // Staggered entrance controller - Cinematic effect
    _staggeredEntranceController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggeredEntranceController,
      curve: Interval(0.0, 0.6, curve: Sprung.overDamped),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _staggeredEntranceController,
      curve: Interval(0.3, 1.0, curve: Sprung.criticallyDamped),
    ));

    // Parallax controller for scroll effects
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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Card entrance controller
    _cardEntranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardEntranceController,
      curve: Sprung.criticallyDamped,
    ));

    // Start cinematic entrance sequence
    _orchestratePremiumEntrance();

    AppLogger.i('✨ Premium animations initialized with spring physics');
  }

  /// Sinematik giriş orkestrasyon
  void _orchestratePremiumEntrance() {
    _masterFadeController.forward();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggeredEntranceController.forward();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardEntranceController.forward();
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
          _isHeaderCollapsed = newOffset > 60;
        });

        // Parallax effect for navigation bar
        final parallaxValue = (newOffset / 150).clamp(0.0, 1.0);
        _parallaxController.animateTo(parallaxValue);
      }
    });
  }

  /// Premium kaynakları temizler
  void _disposePremiumResources() {
    _masterFadeController.dispose();
    _staggeredEntranceController.dispose();
    _parallaxController.dispose();
    _pulseController.dispose();
    _cardEntranceController.dispose();
    _scrollController.dispose();
    AppLogger.i('🧹 Premium AllAnalysesScreen resources disposed successfully');
  }

  // ============================================================================
  // 🔄 PREMIUM DATA METHODS
  // ============================================================================

  /// Premium animasyonla veri yükleme
  void _loadAnalysesWithAnimation() {
    context.read<PlantAnalysisCubitDirect>().loadPastAnalyses();
  }

  // ============================================================================
  // 🔍 PREMIUM FILTER METHODS
  // ============================================================================

  /// Aktif filtrelerin varlığını kontrol eder
  bool _hasActiveFilters() {
    return _selectedStatusFilter != 'all' ||
        _selectedDateFilter != 'all' ||
        _selectedPlantFilter != 'all';
  }

  /// Premium filter modal'ını gösterir
  void _showPremiumFilterModal() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => _buildPremiumFilterModal(),
    );
  }

  /// Premium filter modal'ı oluşturur
  Widget _buildPremiumFilterModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Modal header
              Container(
                padding: EdgeInsets.all(context.dimensions.paddingM),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.divider.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'İptal',
                        style: AppTextTheme.bodyText1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Filtrele',
                      style: AppTextTheme.headline6.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _applyFilters();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Uygula',
                        style: AppTextTheme.bodyText1.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.dimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Durum filtresi
                      _buildFilterSection(
                        'Analiz Durumu',
                        CupertinoIcons.heart_fill,
                        [
                          FilterOption(
                              'all', 'Tümü', _selectedStatusFilter == 'all'),
                          FilterOption('healthy', 'Sağlıklı',
                              _selectedStatusFilter == 'healthy'),
                          FilterOption('diseased', 'Hastalıklı',
                              _selectedStatusFilter == 'diseased'),
                        ],
                        (value) =>
                            setModalState(() => _selectedStatusFilter = value),
                      ),

                      SizedBox(height: context.dimensions.spaceL),

                      // Tarih filtresi
                      _buildFilterSection(
                        'Tarih Aralığı',
                        CupertinoIcons.calendar,
                        [
                          FilterOption(
                              'all', 'Tümü', _selectedDateFilter == 'all'),
                          FilterOption(
                              'today', 'Bugün', _selectedDateFilter == 'today'),
                          FilterOption('week', 'Bu Hafta',
                              _selectedDateFilter == 'week'),
                          FilterOption(
                              'month', 'Bu Ay', _selectedDateFilter == 'month'),
                        ],
                        (value) =>
                            setModalState(() => _selectedDateFilter = value),
                      ),

                      SizedBox(height: context.dimensions.spaceL),

                      // Clear filters button
                      if (_hasActiveFilters())
                        Container(
                          width: double.infinity,
                          height: 50,
                          margin:
                              EdgeInsets.only(top: context.dimensions.spaceL),
                          child: CupertinoButton(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              setModalState(() {
                                _clearAllFilters();
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.clear,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                SizedBox(width: context.dimensions.spaceS),
                                Text(
                                  'Filtreleri Temizle',
                                  style: AppTextTheme.bodyText1.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Filter section builder
  Widget _buildFilterSection(
    String title,
    IconData icon,
    List<FilterOption> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            SizedBox(width: context.dimensions.spaceM),
            Text(
              title,
              style: AppTextTheme.headline6.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.dimensions.spaceM),
        ...options.map((option) => _buildFilterOption(option, onChanged)),
      ],
    );
  }

  /// Filter option builder
  Widget _buildFilterOption(FilterOption option, Function(String) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: context.dimensions.spaceS),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => onChanged(option.value),
        child: Container(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          decoration: BoxDecoration(
            color: option.isSelected
                ? AppColors.primary.withOpacity(0.1)
                : CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: option.isSelected
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.divider.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option.isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: option.isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20,
              ),
              SizedBox(width: context.dimensions.spaceM),
              Text(
                option.label,
                style: AppTextTheme.bodyText1.copyWith(
                  color: option.isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      option.isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filtreleri uygular
  void _applyFilters() {
    setState(() {
      _filteredAnalyses = _filterAnalyses(_allAnalyses);
    });
  }

  /// Tüm filtreleri temizler
  void _clearAllFilters() {
    _selectedStatusFilter = 'all';
    _selectedDateFilter = 'all';
    _selectedPlantFilter = 'all';
  }

  /// Analiz listesini filtreler
  List<PlantAnalysisEntity> _filterAnalyses(
      List<PlantAnalysisEntity> analyses) {
    List<PlantAnalysisEntity> filtered = List.from(analyses);

    // Durum filtreleme
    if (_selectedStatusFilter == 'healthy') {
      filtered = filtered.where((analysis) => analysis.isHealthy).toList();
    } else if (_selectedStatusFilter == 'diseased') {
      filtered = filtered.where((analysis) => !analysis.isHealthy).toList();
    }

    // Tarih filtreleme
    if (_selectedDateFilter != 'all') {
      final now = DateTime.now();
      filtered = filtered.where((analysis) {
        if (analysis.timestamp == null) return false;
        final analysisDate = analysis.timestamp!;

        switch (_selectedDateFilter) {
          case 'today':
            return analysisDate.day == now.day &&
                analysisDate.month == now.month &&
                analysisDate.year == now.year;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            return analysisDate.isAfter(weekAgo);
          case 'month':
            final monthAgo = now.subtract(const Duration(days: 30));
            return analysisDate.isAfter(monthAgo);
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  /// Premium refresh handling
  Future<void> _onPremiumRefresh() async {
    // Haptic feedback would go here
    _loadAnalysesWithAnimation();

    // Smooth animation delay
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Premium analiz detayına navigasyon
  void _navigateToAnalysisDetail(PlantAnalysisEntity analysis) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AnalysisResultScreen(analysisId: analysis.id),
      ),
    );
  }

  /// Entity'den Model'e premium dönüşüm
  model.PlantAnalysisModel _convertEntityToModel(PlantAnalysisEntity entity) {
    return model.PlantAnalysisModel(
      id: entity.id,
      plantName: entity.plantName,
      probability: entity.probability,
      isHealthy: entity.isHealthy,
      diseases: entity.diseases,
      description: entity.description,
      suggestions: entity.suggestions,
      imageUrl: entity.imageUrl,
      similarImages: entity.similarImages,
      location: entity.location,
      fieldName: entity.fieldName,
      timestamp: entity.timestamp?.millisecondsSinceEpoch,
      diseaseName: entity.diseaseName,
      diseaseDescription: entity.diseaseDescription,
      treatmentName: entity.treatmentName,
      dosagePerDecare: entity.dosagePerDecare,
      applicationMethod: entity.applicationMethod,
      applicationTime: entity.applicationTime,
      applicationFrequency: entity.applicationFrequency,
      waitingPeriod: entity.waitingPeriod,
      effectiveness: entity.effectiveness,
      notes: entity.notes,
      suggestion: entity.suggestion,
      intervention: entity.intervention,
      agriculturalTip: entity.agriculturalTip,
    );
  }

  // ============================================================================
  // 🎨 PREMIUM BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 Premium AllAnalysesScreen rendering');

    return CupertinoPageScaffold(
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
    );
  }

  /// Premium navigation bar with glassmorphism
  Widget _buildPremiumNavigationBar(BuildContext context) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_parallaxAnimation, _headerSlideAnimation]),
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return SlideTransition(
          position: _headerSlideAnimation,
          child: Container(
            padding: EdgeInsets.only(
              left: context.dimensions.paddingM,
              right: context.dimensions.paddingM,
              top: context.dimensions.paddingS,
              bottom: context.dimensions.paddingS,
            ),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground
                  .resolveFrom(context)
                  .withOpacity(0.85 + (_parallaxAnimation.value * 0.15)),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider
                      .withOpacity(_parallaxAnimation.value * 0.5),
                  width: 0.5,
                ),
              ),
              boxShadow: _isHeaderCollapsed
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Premium back button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.divider.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.all(context.dimensions.paddingS),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Tüm Analizlerim',
                                style: AppTextTheme.headline5.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (_isHeaderCollapsed)
                                Text(
                                  'Geçmiş Analiz Sonuçları',
                                  style: AppTextTheme.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Premium filter button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _hasActiveFilters()
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasActiveFilters()
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.primary.withOpacity(0.2),
                            width: 0.5,
                          ),
                          boxShadow: _hasActiveFilters()
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.all(context.dimensions.paddingS),
                          onPressed: _showPremiumFilterModal,
                          child: Stack(
                            children: [
                              Icon(
                                CupertinoIcons.line_horizontal_3_decrease,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              if (_hasActiveFilters())
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(width: context.dimensions.spaceS),

                // Premium delete all button - Only show if there are analyses
                BlocBuilder<PlantAnalysisCubitDirect, PlantAnalysisState>(
                  builder: (context, state) {
                    if (state is PlantAnalysisSuccess &&
                        (_filteredAnalyses.isNotEmpty ||
                            state.pastAnalyses.isNotEmpty)) {
                      return AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    CupertinoColors.systemRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.systemRed
                                      .withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: CupertinoButton(
                                padding:
                                    EdgeInsets.all(context.dimensions.paddingS),
                                onPressed: _showDeleteAllConfirmation,
                                child: Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.systemRed,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Premium ana içerik with enhanced physics
  Widget _buildPremiumMainContent() {
    return BlocBuilder<PlantAnalysisCubitDirect, PlantAnalysisState>(
      builder: (context, state) {
        // Safety check for mounted state
        if (!mounted) {
          return Container();
        }

        return AnimatedBuilder(
          animation: _masterFadeAnimation,
          builder: (context, child) {
            // Additional safety check inside builder
            if (!mounted) {
              return Container();
            }
            return FadeTransition(
              opacity: _masterFadeAnimation,
              child: _buildStateContent(context, state),
            );
          },
        );
      },
    );
  }

  /// State'e göre içerik builder
  Widget _buildStateContent(BuildContext context, PlantAnalysisState state) {
    if (state.isLoading) {
      return _buildPremiumLoadingView(context);
    }

    if (state.isError) {
      return _buildPremiumErrorView(
          context, state.errorMessage ?? 'Bir hata oluştu');
    }

    if (state.isSuccess && state.pastAnalyses.isNotEmpty) {
      return _buildPremiumAnalysesListView(context, state.pastAnalyses);
    }

    return _buildPremiumEmptyState(context);
  }

  /// Premium loading view with beautiful animations
  Widget _buildPremiumLoadingView(BuildContext context) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    return AnimatedBuilder(
      animation: _cardScaleAnimation,
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(context.dimensions.paddingXL),
              padding: EdgeInsets.all(context.dimensions.paddingXL),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
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
                  // Premium loading animation container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Center(
                      child: CupertinoActivityIndicator(
                        radius: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceL),
                  Text(
                    'Analizleriniz Yükleniyor',
                    style: AppTextTheme.headline5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceS),
                  Text(
                    'Geçmiş analiz sonuçlarınız hazırlanıyor...',
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Premium analyses list with enhanced animations
  Widget _buildPremiumAnalysesListView(
    BuildContext context,
    List<PlantAnalysisEntity> analyses,
  ) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    // Store all analyses for filtering and get filtered results
    if (_allAnalyses != analyses) {
      _allAnalyses = analyses;
      _filteredAnalyses = _filterAnalyses(analyses);
    }

    // Determine which analyses to show
    final analysesToShow = _hasActiveFilters() ? _filteredAnalyses : analyses;

    // Show no results state if filters are active but no results
    if (analysesToShow.isEmpty && _hasActiveFilters()) {
      return _buildPremiumNoFilterResultsState(context);
    }

    return AnimatedBuilder(
      animation: _cardScaleAnimation,
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Premium pull-to-refresh header
              CupertinoSliverRefreshControl(
                onRefresh: _onPremiumRefresh,
                builder: (context, refreshState, pulledExtent,
                    refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CupertinoActivityIndicator(
                        color: AppColors.primary,
                        radius: 12,
                      ),
                    ),
                  );
                },
              ),

              // Stats header
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.only(
                    left: context.dimensions.paddingM,
                    right: context.dimensions.paddingM,
                    bottom: context.dimensions.paddingS,
                  ),
                  padding: EdgeInsets.all(context.dimensions.paddingM),
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
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.chart_bar_alt_fill,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: context.dimensions.spaceS),
                      Text(
                        '${analysesToShow.length} Analiz Sonucu',
                        style: AppTextTheme.bodyText1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Premium analyses list
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.dimensions.paddingM,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final analysis = analysesToShow[index];
                      return AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          // Safety check inside list item builder
                          if (!mounted) {
                            return Container();
                          }
                          return Transform.translate(
                            offset: Offset(0, -2 * _pulseAnimation.value),
                            child: Container(
                              margin: EdgeInsets.only(
                                bottom: context.dimensions.spaceM,
                              ),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(
                                        0.05 * _pulseAnimation.value),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: AnalysisCard(
                                analysis: _convertEntityToModel(analysis),
                                cardSize: AnalysisCardSize.large,
                                showDeleteButton: true,
                                onTap: () =>
                                    _navigateToAnalysisDetail(analysis),
                                onDelete: () => _deleteAnalysis(analysis.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: analysesToShow.length,
                  ),
                ),
              ),

              // Bottom spacing
              SliverToBoxAdapter(
                child: SizedBox(height: context.dimensions.spaceXL),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Premium error view with beautiful design
  Widget _buildPremiumErrorView(BuildContext context, String errorMessage) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    // Get error information based on current state
    final PlantAnalysisState currentState =
        context.read<PlantAnalysisCubitDirect>().state;
    final ErrorInfo errorInfo = _getErrorInfo(
      currentState is PlantAnalysisError ? currentState.errorType : null,
    );

    return AnimatedBuilder(
      animation: _cardScaleAnimation,
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(context.dimensions.paddingXL),
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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: errorInfo.color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: errorInfo.color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium error icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          errorInfo.color.withOpacity(0.2),
                          errorInfo.color.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      errorInfo.icon,
                      size: 40,
                      color: errorInfo.color,
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceL),

                  // Error title
                  Text(
                    errorInfo.title,
                    style: AppTextTheme.headline5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.dimensions.spaceM),

                  // Error description
                  Text(
                    errorInfo.description,
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Additional error information
                  if (errorInfo.additionalInfo != null) ...[
                    SizedBox(height: context.dimensions.spaceS),
                    Container(
                      padding: EdgeInsets.all(context.dimensions.paddingM),
                      decoration: BoxDecoration(
                        color: errorInfo.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorInfo.additionalInfo!,
                        style: AppTextTheme.caption.copyWith(
                          color: errorInfo.color,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  SizedBox(height: context.dimensions.spaceXL),

                  // Premium retry button
                  Container(
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
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: _loadAnalysesWithAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.refresh,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          SizedBox(width: context.dimensions.spaceS),
                          Text(
                            'Tekrar Dene',
                            style: AppTextTheme.bodyText1.copyWith(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Premium empty state with beautiful animations
  Widget _buildPremiumEmptyState(BuildContext context) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_cardScaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(context.dimensions.paddingXL),
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
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 50,
                    offset: const Offset(0, 20),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium empty state illustration
                  Transform.scale(
                    scale: 0.95 + (0.1 * _pulseAnimation.value),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
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
                      child: Icon(
                        CupertinoIcons.leaf_arrow_circlepath,
                        size: 64,
                        color: AppColors.primary.withOpacity(
                            (0.8 + (0.2 * (_pulseAnimation.value ?? 0.0)))
                                .clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXL),

                  // Premium empty state title
                  Text(
                    'Henüz Hiç Analiz Yok',
                    style: AppTextTheme.headline4.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.dimensions.spaceM),

                  // Premium empty state description
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingM,
                      vertical: context.dimensions.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Bitki fotoğrafı yükleyerek ilk analizinizi yapın.\nTüm analiz sonuçlarınız burada güvenle saklanır.',
                      style: AppTextTheme.bodyText1.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXXL),

                  // Premium navigate back button
                  Container(
                    width: double.infinity,
                    height: 58,
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
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(
                              (0.1 * (_pulseAnimation.value ?? 0.0))
                                  .clamp(0.0, 1.0)),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                EdgeInsets.all(context.dimensions.paddingS),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.house_fill,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: context.dimensions.spaceM),
                          Text(
                            'Ana Sayfaya Dön',
                            style: AppTextTheme.bodyText1.copyWith(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(width: context.dimensions.spaceS),
                          Icon(
                            CupertinoIcons.arrow_right,
                            color: CupertinoColors.white.withOpacity(0.8),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Premium no filter results state
  Widget _buildPremiumNoFilterResultsState(BuildContext context) {
    // Safety check for mounted state
    if (!mounted) {
      return Container();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_cardScaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        // Additional safety check inside builder
        if (!mounted) {
          return Container();
        }
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(context.dimensions.paddingXL),
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
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter no results icon
                  Transform.scale(
                    scale: 0.95 + (0.1 * _pulseAnimation.value),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
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
                      child: Icon(
                        CupertinoIcons.search_circle,
                        size: 56,
                        color: AppColors.primary.withOpacity(
                            (0.8 + (0.2 * (_pulseAnimation.value ?? 0.0)))
                                .clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXL),

                  // No results title
                  Text(
                    'Filtre Sonucu Bulunamadı',
                    style: AppTextTheme.headline4.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.dimensions.spaceM),

                  // No results description
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingM,
                      vertical: context.dimensions.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Seçilen filtrelere uygun analiz sonucu bulunamadı.\nFiltreleri temizleyerek tekrar deneyin.',
                      style: AppTextTheme.bodyText1.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXXL),

                  // Clear filters button
                  Container(
                    width: double.infinity,
                    height: 58,
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
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () {
                        setState(() {
                          _clearAllFilters();
                          _applyFilters();
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                EdgeInsets.all(context.dimensions.paddingS),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.clear,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: context.dimensions.spaceM),
                          Text(
                            'Filtreleri Temizle',
                            style: AppTextTheme.bodyText1.copyWith(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Gets error information based on error type
  ///
  /// Maps ErrorType enum values to user-friendly error information
  /// with appropriate icons, colors, and messages.
  ///
  /// @param errorType - The type of error that occurred
  /// @return ErrorInfo object with display properties
  ErrorInfo _getErrorInfo(ErrorType? errorType) {
    switch (errorType) {
      // Network-related errors
      case ErrorType.networkError:
        return ErrorInfo(
          icon: CupertinoIcons.wifi_slash,
          color: CupertinoColors.systemOrange,
          title: 'Bağlantı Hatası',
          description: 'İnternet bağlantınızda bir sorun var.',
          additionalInfo: 'Bağlantınızı kontrol edip tekrar deneyin.',
        );

      // Server-related errors
      case ErrorType.serverError:
        return ErrorInfo(
          icon: CupertinoIcons.exclamationmark_circle,
          color: CupertinoColors.systemRed,
          title: 'Sunucu Hatası',
          description: 'Sunucularımızda geçici bir sorun yaşanıyor.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );

      // Authentication/authorization errors
      case ErrorType.unauthorized:
        return ErrorInfo(
          icon: CupertinoIcons.person_badge_minus,
          color: CupertinoColors.systemRed,
          title: 'Oturum Hatası',
          description: 'Oturumunuz sonlanmış veya yetkiniz bulunmuyor.',
          additionalInfo: 'Lütfen yeniden giriş yapın.',
        );

      // Subscription/premium errors
      case ErrorType.subscription:
        return ErrorInfo(
          icon: CupertinoIcons.star_slash,
          color: CupertinoColors.systemYellow,
          title: 'Premium Gerekiyor',
          description:
              'Bu özelliği kullanmak için premium aboneliğe sahip olmanız gerekiyor.',
          additionalInfo: "Premium'a geçerek sınırsız analiz yapabilirsiniz.",
        );

      // Data not found errors
      case ErrorType.notFound:
        return ErrorInfo(
          icon: CupertinoIcons.doc_text_search,
          color: CupertinoColors.systemYellow,
          title: 'Veri Bulunamadı',
          description: 'Aradığınız analiz sonuçları bulunamadı.',
          additionalInfo: 'Henüz hiç analiz yapmamış olabilirsiniz.',
        );

      // Storage/database errors
      case ErrorType.storageError:
        return ErrorInfo(
          icon: CupertinoIcons.cloud_download,
          color: CupertinoColors.systemOrange,
          title: 'Veritabanı Hatası',
          description: 'Veritabanından veriler alınırken bir sorun oluştu.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );

      // Timeout errors
      case ErrorType.timeout:
        return ErrorInfo(
          icon: CupertinoIcons.clock,
          color: CupertinoColors.systemBlue,
          title: 'Zaman Aşımı',
          description: 'İşlem çok uzun sürdü ve zaman aşımına uğradı.',
          additionalInfo: 'Lütfen tekrar deneyin.',
        );

      // File-related errors
      case ErrorType.fileError:
        return ErrorInfo(
          icon: CupertinoIcons.doc_on_clipboard,
          color: CupertinoColors.systemRed,
          title: 'Dosya Hatası',
          description: 'Dosya işlemi sırasında bir hata oluştu.',
          additionalInfo: 'Lütfen dosyayı kontrol edip tekrar deneyin.',
        );

      // Analysis-specific errors
      case ErrorType.analysisFailure:
        return ErrorInfo(
          icon: CupertinoIcons.camera_on_rectangle,
          color: CupertinoColors.systemRed,
          title: 'Analiz Hatası',
          description: 'Bitki analizi sırasında bir hata oluştu.',
          additionalInfo: 'Lütfen farklı bir fotoğraf ile tekrar deneyin.',
        );

      // Validation errors
      case ErrorType.validation:
        return ErrorInfo(
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemYellow,
          title: 'Geçersiz Veri',
          description: 'Girilen veriler geçerli değil.',
          additionalInfo: 'Lütfen bilgileri kontrol edip tekrar deneyin.',
        );

      // Default/unknown errors
      case ErrorType.general:
      case ErrorType.unknown:
      default:
        return ErrorInfo(
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemGrey,
          title: 'Beklenmeyen Bir Hata Oluştu',
          description: 'Sistemde geçici bir sorun yaşanıyor.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );
    }
  }

  // ============================================================================
  // 🗑️ DELETE OPERATIONS
  // ============================================================================

  /// Silme işlemini başlatır
  void _deleteAnalysis(String analysisId) {
    final cubit = context.read<PlantAnalysisCubitDirect>();
    cubit.deleteAnalysis(analysisId);
  }

  /// Çoklu silme işlemini başlatır
  void _deleteMultipleAnalyses(List<String> analysisIds) {
    final cubit = context.read<PlantAnalysisCubitDirect>();
    cubit.deleteMultipleAnalyses(analysisIds);
  }

  /// Tüm analizleri silme işlemini başlatır
  void _deleteAllAnalyses() {
    final cubit = context.read<PlantAnalysisCubitDirect>();
    cubit.deleteAllAnalyses();
  }

  /// Tüm analizleri silme onay dialog'unu gösterir
  Future<void> _showDeleteAllConfirmation() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            'Tüm Analizleri Sil',
            style: AppTextTheme.headline6.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Tüm analiz verilerinizi kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
              style: AppTextTheme.bodyText2.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'İptal',
                style: AppTextTheme.bodyText1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(
                'Tümünü Sil',
                style: AppTextTheme.bodyText1.copyWith(
                  color: CupertinoColors.systemRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteAllAnalyses();
    }
  }
}

// ============================================================================
// ERROR INFO MODEL
// ============================================================================

/// Error Information Model
///
/// Contains display information for different types of errors,
/// including icons, colors, titles, and descriptions for
/// user-friendly error presentation.
class ErrorInfo {
  /// Icon to display for the error
  final IconData icon;

  /// Color theme for the error
  final Color color;

  /// Error title/heading
  final String title;

  /// Main error description
  final String description;

  /// Additional information about the error
  final String? additionalInfo;

  /// Creates ErrorInfo instance
  ///
  /// @param icon - Error icon
  /// @param color - Error color theme
  /// @param title - Error title
  /// @param description - Error description
  /// @param additionalInfo - Additional error details
  const ErrorInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.additionalInfo,
  });
}
