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
import 'package:tatarai/features/plant_analysis/views/analysis_result_screen.dart';
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
          backgroundColor: CupertinoColors.systemBackground,
          middle: Text('Tüm Analizler', style: TextStyle(color: Colors.black)),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(
              CupertinoIcons.back,
              color: Colors.black, // Ok simgesinin rengi burada
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
                            .copyWith(color: AppTextTheme.bodySmall.color),
                      ),
                      SizedBox(height: context.dimensions.spaceXS),
                      Text('Lütfen bekleyin...', style: AppTextTheme.bodySmall),
                    ],
                  ),
                );
              }

              if (state.errorMessage != null) {
                return _buildErrorView(context, state.errorMessage ?? '');
              }

              if (state.analysisList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.dimensions.paddingM),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.dimensions.paddingM),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusM),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Henüz hiç analiz yapmadınız',
                                style: TextStyle(
                                  fontSize: context.dimensions.fontSizeL,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: context.dimensions.spaceXS),
                              Text(
                                'Bitki analizi yapmak için ana sayfaya dönün',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.dimensions.fontSizeM,
                                  color: CupertinoColors.systemGrey,
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
                  style: AppTextTheme.subtitle2
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
