import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/home/cubits/home_cubit.dart';
import 'package:tatarai/features/home/cubits/home_state.dart';
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
import 'package:tatarai/features/plant_analysis/views/widgets/analysis_card.dart';

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

    // HomeCubit'i yenile - Stream subscription otomatik başlayacak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeCubit>().refresh();
      // Not: PlantAnalysisCubit.loadPastAnalyses() çağrısına gerek yok
      // Artık analizler HomeCubit üzerinden stream ile dinleniyor
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
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          AppConstants.appName,
          style: AppTextTheme.headline6.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
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
    return Container(
      margin: EdgeInsets.only(
        left: context.dimensions.paddingM,
        right: context.dimensions.paddingM,
        top: context.dimensions.paddingS,
        bottom: context.dimensions.paddingXS,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                Text(
                  'Merhaba,',
                  style: AppTextTheme.bodyText1.copyWith(
                    color: CupertinoColors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userName,
                  style: AppTextTheme.headline3.copyWith(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: CupertinoColors.black.withOpacity(0.1),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.dimensions.spaceS),
                Text(
                  'Bitkilerinin sağlığını kontrol etmeye hazır mısın?',
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: context.dimensions.paddingXS,
              bottom: context.dimensions.paddingXS,
            ),
            child: Text(
              'Hızlı İşlemler',
              style: AppTextTheme.headline6.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
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
          SizedBox(height: context.dimensions.spaceXS),
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
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey5.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(context.dimensions.radiusS),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                iconData,
                size: 24,
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
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                color: color,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalysesSection(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        // Yükleniyor durumu
        if (state.isLoading == true) {
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
        if (state.recentAnalyses.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(context.dimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: context.dimensions.paddingXS,
                      bottom: context.dimensions.paddingS,
                    ),
                    child: Text(
                      'Son Analizler',
                      style: AppTextTheme.headline6.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
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
              vertical: context.dimensions.paddingXS,
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
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.dimensions.paddingS,
                          vertical: context.dimensions.spaceXXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            context.dimensions.radiusS,
                          ),
                        ),
                        child: Text(
                          'Tümünü Gör',
                          style: AppTextTheme.button.copyWith(
                            color: AppColors.primary,
                            fontSize: context.dimensions.fontSizeS,
                            fontWeight: FontWeight.w600,
                          ),
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
                SizedBox(height: context.dimensions.spaceS),
                ...state.recentAnalyses.take(3).map((analysis) => Padding(
                      padding:
                          EdgeInsets.only(bottom: context.dimensions.spaceS),
                      child: AnalysisCard(
                        analysis: analysis,
                        cardSize: AnalysisCardSize.compact,
                      ),
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
        padding: EdgeInsets.all(context.dimensions.paddingL),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(context.dimensions.radiusM),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey5.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(35),
              ),
              child: Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: context.dimensions.spaceM),
            Text(
              'Henüz analiz yok',
              style: AppTextTheme.headline6.copyWith(
                fontSize: context.dimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: context.dimensions.spaceS),
            Text(
              'İlk bitki analizini yapmak için Yeni Analiz kartına dokunabilirsin',
              textAlign: TextAlign.center,
              style: AppTextTheme.bodyText2.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: context.dimensions.spaceL),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(vertical: 12),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(context.dimensions.radiusM),
                onPressed: _navigateToAnalysis,
                child: Text(
                  'Analiz Yap',
                  style: AppTextTheme.button.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
