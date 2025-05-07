import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/views/analyses_result/analysis_result_screen.dart';
import 'package:tatarai/features/plant_analysis/views/widgets/analysis_card.dart';

/// Tüm analizleri gösteren ekran
class AllAnalysesScreen extends StatefulWidget {
  const AllAnalysesScreen({super.key});

  @override
  State<AllAnalysesScreen> createState() => _AllAnalysesScreenState();
}

class _AllAnalysesScreenState extends State<AllAnalysesScreen> {
  @override
  void initState() {
    super.initState();
    // Geçmiş analizleri yükle
    context.read<PlantAnalysisCubit>().loadPastAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Tüm Analizler',
              style: AppTextTheme.headline5
                  .copyWith(color: AppColors.textPrimary)),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(
              CupertinoIcons.back,
              color: AppColors.textPrimary, // Ok simgesinin rengi güncellendi
            ),
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<PlantAnalysisCubit, PlantAnalysisState>(
            builder: (context, state) {
              if (state.isLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator.adaptive(),
                      SizedBox(height: context.dimensions.spaceXS),
                      Text(
                        'Analizler yükleniyor...',
                        style: AppTextTheme.bodyMedium
                            .copyWith(color: AppTextTheme.bodyMedium.color),
                      ),
                      SizedBox(height: context.dimensions.spaceXS),
                      Text('Lütfen bekleyin...',
                          style: AppTextTheme.smallCaption),
                    ],
                  ),
                );
              }

              if (state.errorMessage != null) {
                return _buildErrorView(context, state.errorMessage ?? '');
              }

              if (state.analysisList.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: EdgeInsets.only(top: context.dimensions.paddingM),
                itemCount: state.analysisList.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingM,
                      vertical: context.dimensions.paddingXS,
                    ),
                    child: AnalysisCard(
                      analysis: state.analysisList[index],
                      cardSize: AnalysisCardSize.large,
                      onTap: () => _showAnalysisDetails(
                          context, state.analysisList[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String errorMessage) {
    // Hata mesajını analiz ederek daha spesifik bir mesaj ve icon seçelim
    final ErrorInfo errorInfo =
        _getErrorInfo(context.read<PlantAnalysisCubit>().state.errorType);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.dimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hata tipine göre ikon
                Icon(
                  errorInfo.icon,
                  size: context.dimensions.iconSizeXL,
                  color: errorInfo.color,
                ),
                SizedBox(height: context.dimensions.spaceM),

                // Hata başlığı
                Text(
                  errorInfo.title,
                  style: AppTextTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.dimensions.spaceS),

                // Hata açıklaması
                Text(
                  errorInfo.description,
                  style: AppTextTheme.caption
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),

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
                AppButton(
                  text: 'Tekrar Dene',
                  icon: CupertinoIcons.refresh,
                  onPressed: () =>
                      context.read<PlantAnalysisCubit>().loadPastAnalyses(),
                  type: AppButtonType.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Analiz sonucu olmadığında gösterilecek boş durum
  Widget _buildEmptyState(BuildContext context) {
    final dim = context.dimensions;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dim.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Boş durum illüstrasyonu
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 80,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            SizedBox(height: dim.spaceL),

            // Başlık
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

            // Açıklama
            Text(
              'Bitki fotoğrafı yükleyerek ilk analizinizi yapabilirsiniz. Analizleriniz burada listelenecek.',
              style: AppTextTheme.body.copyWith(
                color: CupertinoColors.secondaryLabel,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: dim.spaceXL),

            // Ana sayfaya dön butonu
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

  /// Cubit'in belirlediği hata türüne göre hata bilgisini döndürür
  ErrorInfo _getErrorInfo(ErrorType? errorType) {
    switch (errorType) {
      case ErrorType.network:
        return ErrorInfo(
          icon: CupertinoIcons.wifi_slash,
          color: CupertinoColors.systemOrange,
          title: 'Bağlantı Hatası',
          description: 'İnternet bağlantınızda bir sorun var.',
          additionalInfo: 'Bağlantınızı kontrol edip tekrar deneyin.',
        );

      case ErrorType.server:
        return ErrorInfo(
          icon: CupertinoIcons.exclamationmark_circle,
          color: CupertinoColors.systemRed,
          title: 'Sunucu Hatası',
          description: 'Sunucularımızda geçici bir sorun yaşanıyor.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );

      case ErrorType.auth:
        return ErrorInfo(
          icon: CupertinoIcons.person_badge_minus,
          color: CupertinoColors.systemRed,
          title: 'Oturum Hatası',
          description: 'Oturumunuz sonlanmış veya yetkiniz bulunmuyor.',
          additionalInfo: 'Lütfen yeniden giriş yapın.',
        );

      case ErrorType.premium:
        return ErrorInfo(
          icon: CupertinoIcons.star_slash,
          color: CupertinoColors.systemYellow,
          title: 'Premium Gerekiyor',
          description:
              'Bu özelliği kullanmak için premium aboneliğe sahip olmanız gerekiyor.',
          additionalInfo: "Premium'a geçerek sınırsız analiz yapabilirsiniz.",
        );

      case ErrorType.notFound:
        return ErrorInfo(
          icon: CupertinoIcons.doc_text_search,
          color: CupertinoColors.systemYellow,
          title: 'Veri Bulunamadı',
          description: 'Aradığınız analiz sonuçları bulunamadı.',
          additionalInfo: 'Henüz hiç analiz yapmamış olabilirsiniz.',
        );

      case ErrorType.database:
        return ErrorInfo(
          icon: CupertinoIcons.cloud_download,
          color: CupertinoColors.systemOrange,
          title: 'Veritabanı Hatası',
          description: 'Veritabanından veriler alınırken bir sorun oluştu.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );

      default:
        return ErrorInfo(
          icon: CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemGrey,
          title: 'Beklenmeyen Bir Hata Oluştu',
          description: 'Analizleriniz yüklenirken bir sorun oluştu.',
          additionalInfo: 'Lütfen daha sonra tekrar deneyin.',
        );
    }
  }

  void _showAnalysisDetails(
      BuildContext context, PlantAnalysisResult analysis) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AnalysisResultScreen(analysisId: analysis.id),
      ),
    );
  }
}

/// Hata bilgisi modeli - UI/UX için
class ErrorInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? additionalInfo;

  ErrorInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.additionalInfo,
  });
}
