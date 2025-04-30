import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/home/cubits/home_cubit.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/views/analysis_result_screen.dart';
import 'package:tatarai/features/plant_analysis/views/all_analyses_screen.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:sprung/sprung.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Ana ekran tab içeriği - Modern tasarım, hızlı erişim seçenekleri ve bitki analiz geçmişi
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Animasyon kontrolcüsü
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Geçmiş analizleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantAnalysisCubit>().loadPastAnalyses();
      context.read<HomeCubit>().refresh();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Analiz ekranına geçiş için helper metod
  void _navigateToAnalysis() {
    if (NavigationManager.instance != null) {
      NavigationManager.instance!.switchToTab(1); // Analiz tabına geçiş
    } else {
      AppLogger.w('NavigationManager instance bulunamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          AppConstants.appName,
          style: AppTextTheme.headline6.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),
            SliverToBoxAdapter(
              child: _buildQuickActions(context),
            ),
            _buildRecentAnalysesSection(context),
            SliverToBoxAdapter(
              child: SizedBox(height: context.dimensions.spaceL),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingS,
      ),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final userName = state.user?.displayName ?? 'Misafir';

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _animationController.value,
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.dimensions.spaceXS),
                Text(
                  'Merhaba,',
                  style: AppTextTheme.bodyText1.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  userName,
                  style: AppTextTheme.headline3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceXS),
                Text(
                  'Bitkilerinin sağlığını kontrol etmeye hazır mısın?',
                  style: AppTextTheme.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceM),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0,
                    20 *
                        (1 -
                            Sprung.criticallyDamped
                                .transform(_animationController.value))),
                child: Opacity(
                  opacity: _animationController.value,
                  child: child,
                ),
              );
            },
            child: _buildActionCard(
              context,
              title: 'Yeni Analiz',
              subtitle: 'Bir fotoğraf çekerek bitkini analiz et',
              iconData: CupertinoIcons.camera,
              color: AppColors.primary,
              onTap: _navigateToAnalysis,
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0,
                    30 *
                        (1 -
                            Sprung.criticallyDamped
                                .transform(_animationController.value))),
                child: Opacity(
                  opacity: _animationController.value,
                  child: child,
                ),
              );
            },
            child: _buildActionCard(
              context,
              title: 'Tüm Analizler',
              subtitle: 'Geçmiş analiz sonuçlarına göz at',
              iconData: CupertinoIcons.doc_chart,
              color: CupertinoColors.activeOrange,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => AllAnalysesScreen(),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.dimensions.paddingM),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          border: Border.all(
            color: CupertinoColors.systemGrey5,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey6,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.dimensions.radiusS),
              ),
              child: Icon(
                iconData,
                size: 22,
                color: color,
              ),
            ),
            SizedBox(width: context.dimensions.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextTheme.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalysesSection(BuildContext context) {
    return BlocBuilder<PlantAnalysisCubit, PlantAnalysisState>(
      builder: (context, state) {
        // Yükleniyor durumu
        if (state.isLoading) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.dimensions.paddingL),
                child: const CupertinoActivityIndicator(),
              ),
            ),
          );
        }

        // Analiz listesi boş
        if (state.analysisList.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(context.dimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: context.dimensions.paddingXS,
                      bottom: context.dimensions.paddingXS,
                    ),
                    child: Text(
                      'Son Analizler',
                      style: AppTextTheme.headline6.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildEmptyAnalysisState(context),
                ],
              ),
            ),
          );
        }

        // Analizleri göster
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.dimensions.paddingM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Son Analizler',
                      style: AppTextTheme.headline6.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(
                        'Tümünü Gör',
                        style: AppTextTheme.button.copyWith(
                          color: AppColors.primary,
                          fontSize: context.dimensions.fontSizeS,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => const AllAnalysesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: context.dimensions.spaceXS),
                ...state.analysisList.take(3).map((analysis) => Padding(
                      padding:
                          EdgeInsets.only(bottom: context.dimensions.spaceS),
                      child: _buildAnalysisCard(context, analysis),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyAnalysisState(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              0,
              30 *
                  (1 -
                      Sprung.criticallyDamped
                          .transform(_animationController.value))),
          child: Opacity(
            opacity: _animationController.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(context.dimensions.paddingM),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          border: Border.all(
            color: CupertinoColors.systemGrey5,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey6,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(context.dimensions.radiusM),
              ),
              child: Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 28,
                color: CupertinoColors.systemGrey,
              ),
            ),
            SizedBox(height: context.dimensions.spaceM),
            Text(
              'Henüz analiz yok',
              style: AppTextTheme.headline6.copyWith(
                fontSize: context.dimensions.fontSizeM,
              ),
            ),
            SizedBox(height: context.dimensions.spaceXS),
            Text(
              'İlk bitki analizini yapmak için Yeni Analiz kartına dokunabilirsin',
              textAlign: TextAlign.center,
              style: AppTextTheme.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: context.dimensions.spaceM),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(vertical: 12),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(context.dimensions.radiusS),
                onPressed: _navigateToAnalysis,
                child: Text(
                  'Analiz Yap',
                  style: AppTextTheme.button.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Analiz kartı widget'ı
  Widget _buildAnalysisCard(
    BuildContext context,
    PlantAnalysisResult analysis,
  ) {
    // Tarih için temel bir değer kullan, API'den gelmediği için
    final formattedDate = 'Yeni Analiz';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => AnalysisResultScreen(
              analysisId: analysis.id,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(context.dimensions.paddingM),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          border: Border.all(
            color: CupertinoColors.systemGrey5,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey6,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Analiz fotoğrafı
            if (analysis.imageUrl.isNotEmpty)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(context.dimensions.radiusS),
                  border: Border.all(
                    color: CupertinoColors.systemGrey5,
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAnalysisImage(analysis.imageUrl),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: analysis.diseases.isEmpty
                      ? AppColors.primary.withOpacity(0.1)
                      : CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(context.dimensions.radiusS),
                ),
                child: Icon(
                  analysis.diseases.isEmpty
                      ? CupertinoIcons.leaf_arrow_circlepath
                      : CupertinoIcons.exclamationmark_circle,
                  size: 24,
                  color: analysis.diseases.isEmpty
                      ? AppColors.primary
                      : CupertinoColors.systemRed,
                ),
              ),
            SizedBox(width: context.dimensions.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          analysis.plantName ?? 'Bilinmeyen Bitki',
                          style: AppTextTheme.bodyText1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: AppTextTheme.caption,
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  if (analysis.diseases.isNotEmpty)
                    Text(
                      analysis.diseases.first.name,
                      style: AppTextTheme.bodyText2.copyWith(
                        color: CupertinoColors.systemRed,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      'Sağlıklı',
                      style: AppTextTheme.bodyText2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Analiz fotoğrafı için image widget'ı
  Widget _buildAnalysisImage(String imageUrl) {
    // Base64 ile kodlanmış bir görüntü ise
    if (imageUrl.startsWith('data:image')) {
      try {
        // Base64 veriyi ayır
        final dataUri = Uri.parse(imageUrl);
        final mimeType = dataUri.pathSegments.first.split(':').last;
        final data = dataUri.data!.contentAsBytes();
        // Decode ederek kullan
        return Image.memory(
          data,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e('Base64 görüntü hatası: $error', error, stackTrace);
            return const Icon(
              CupertinoIcons.photo,
              size: 24,
              color: CupertinoColors.systemGrey,
            );
          },
        );
      } catch (e) {
        AppLogger.e('Base64 görüntü hatası', e);
        return const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: CupertinoColors.systemGrey,
        );
      }
    }
    // Dosya yolu ise
    else if (imageUrl.startsWith('file://')) {
      try {
        // file:// önekini kaldır
        final filePath = imageUrl.replaceFirst('file://', '');
        // Dosyadan yükle
        return Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e('Dosya görüntü hatası: $error', error, stackTrace);
            return const Icon(
              CupertinoIcons.photo,
              size: 24,
              color: CupertinoColors.systemGrey,
            );
          },
        );
      } catch (e) {
        AppLogger.e('Dosya görüntü hatası', e);
        return const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: CupertinoColors.systemGrey,
        );
      }
    }
    // Normal URL ise ağdan yükle
    else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const Center(
            child: CupertinoActivityIndicator(
              radius: 10,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.e('Network görüntü hatası: $error', error, stackTrace);
          return const Icon(
            CupertinoIcons.photo,
            size: 24,
            color: CupertinoColors.systemGrey,
          );
        },
      );
    }
  }
}
