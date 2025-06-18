import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
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

/// All Plant Analyses Screen
///
/// Displays a comprehensive list of all user's past plant analyses.
/// Follows Clean Architecture principles with proper state management,
/// error handling, and user experience patterns.
///
/// Features:
/// - Past analyses list with cards
/// - Pull-to-refresh functionality
/// - Empty state handling
/// - Comprehensive error handling
/// - Loading states with shimmer effects
/// - Navigation to detailed analysis results
class AllAnalysesScreen extends StatefulWidget {
  /// Creates AllAnalysesScreen
  const AllAnalysesScreen({super.key});

  @override
  State<AllAnalysesScreen> createState() => _AllAnalysesScreenState();
}

class _AllAnalysesScreenState extends State<AllAnalysesScreen> {
  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Loads past analyses from the cubit
  void _loadAnalyses() {
    context.read<PlantAnalysisCubitDirect>().loadPastAnalyses();
  }

  /// Handles refresh action
  Future<void> _onRefresh() async {
    _loadAnalyses();
    // Wait for state change to complete refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Navigates to detailed analysis result screen
  void _navigateToAnalysisDetail(PlantAnalysisEntity analysis) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AnalysisResultScreen(analysisId: analysis.id),
      ),
    );
  }

  /// Converts PlantAnalysisEntity to PlantAnalysisModel
  ///
  /// Entity'den UI gösterimi için uygun model formatına dönüştürür
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
      // Yeni alanlar entity'den al
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

  /// Disease dönüştürme artık gerekmiyor - aynı modeli kullanıyoruz

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Tüm Analizlerim',
          style: AppTextTheme.headline5.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: BlocBuilder<PlantAnalysisCubitDirect, PlantAnalysisState>(
          builder: (context, state) {
            // Loading state
            if (state.isLoading) {
              return _buildLoadingView(context);
            }

            // Error state
            if (state.isError) {
              return _buildErrorView(
                  context, state.errorMessage ?? 'Bir hata oluştu');
            }

            // Success state with data
            if (state.isSuccess && state.pastAnalyses.isNotEmpty) {
              return _buildAnalysesListView(context, state.pastAnalyses);
            }

            // Empty state
            return _buildEmptyState(context);
          },
        ),
      ),
    );
  }

  /// Builds loading view with shimmer effects
  Widget _buildLoadingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 20),
          SizedBox(height: context.dimensions.spaceM),
          Text(
            'Analizleriniz yükleniyor...',
            style: AppTextTheme.body.copyWith(
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds analyses list view with pull-to-refresh
  Widget _buildAnalysesListView(
    BuildContext context,
    List<PlantAnalysisEntity> analyses,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Pull-to-refresh header
        CupertinoSliverRefreshControl(
          onRefresh: _onRefresh,
        ),

        // Analyses list
        SliverPadding(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final analysis = analyses[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: context.dimensions.spaceM,
                  ),
                  child: AnalysisCard(
                    analysis: _convertEntityToModel(analysis),
                    cardSize: AnalysisCardSize.large,
                    onTap: () => _navigateToAnalysisDetail(analysis),
                  ),
                );
              },
              childCount: analyses.length,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds error view with contextual information
  Widget _buildErrorView(BuildContext context, String errorMessage) {
    // Get error information based on current state
    final PlantAnalysisState currentState =
        context.read<PlantAnalysisCubitDirect>().state;
    final ErrorInfo errorInfo = _getErrorInfo(
      currentState is PlantAnalysisError ? currentState.errorType : null,
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.dimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Icon(
              errorInfo.icon,
              size: context.dimensions.iconSizeXL,
              color: errorInfo.color,
            ),
            SizedBox(height: context.dimensions.spaceM),

            // Error title
            Text(
              errorInfo.title,
              style: AppTextTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.dimensions.spaceS),

            // Error description
            Text(
              errorInfo.description,
              style: AppTextTheme.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // Additional error information
            if (errorInfo.additionalInfo != null) ...[
              SizedBox(height: context.dimensions.spaceXS),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.dimensions.paddingS,
                ),
                child: Text(
                  errorInfo.additionalInfo!,
                  style: AppTextTheme.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            SizedBox(height: context.dimensions.spaceL),

            // Retry button
            AppButton(
              text: 'Tekrar Dene',
              icon: CupertinoIcons.refresh,
              onPressed: _loadAnalyses,
              type: AppButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds empty state view when no analyses found
  Widget _buildEmptyState(BuildContext context) {
    final dim = context.dimensions;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dim.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state illustration
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 80,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: dim.spaceL),

            // Empty state title
            Text(
              'Henüz Hiç Analiz Yok',
              style: AppTextTheme.headline2.copyWith(
                fontWeight: FontWeight.bold,
                color: CupertinoColors.label,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: dim.spaceM),

            // Empty state description
            Text(
              'Bitki fotoğrafı yükleyerek ilk analizinizi yapabilirsiniz. Analizleriniz burada listelenecek.',
              style: AppTextTheme.body.copyWith(
                color: CupertinoColors.secondaryLabel,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: dim.spaceXL),

            // Navigate back button
            AppButton(
              text: 'Ana Sayfaya Dön',
              onPressed: () => Navigator.of(context).pop(),
              isFullWidth: true,
              type: AppButtonType.primary,
              icon: CupertinoIcons.home,
            ),
          ],
        ),
      ),
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
