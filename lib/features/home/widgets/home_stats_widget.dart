import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../cubits/home_cubit.dart';
import '../cubits/home_state.dart';

/// Modern Ana Ekran İstatistik Widget'ı
///
/// Kullanıcı-agnostic genel istatistikler ve motivasyonel
/// bilgiler gösteren modern card tasarımı.
///
/// Özellikler:
/// - Genel uygulama istatistikleri
/// - Modern horizontal card tasarımı
/// - Soft shadows ve subtle gradients
/// - Apple HIG uyumlu animasyonlar
/// - Theme colors kullanımı
/// - Translation desteği
/// - Responsive design
class HomeStatsWidget extends StatelessWidget {
  const HomeStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section başlığı
          Padding(
            padding: EdgeInsets.only(
              left: context.dimensions.paddingXS,
              bottom: context.dimensions.paddingM,
            ),
            child: Text(
              'stats_overview'.locale(context),
              style: AppTextTheme.headline6.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Stats cards
          BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              return _buildStatsCards(context, state);
            },
          ),
        ],
      ),
    );
  }

  /// Modern stats cards oluşturur
  Widget _buildStatsCards(BuildContext context, HomeState state) {
    final stats = _getStatsData(context, state);

    return Column(
      children: [
        // İlk satır - Ana istatistikler
        Row(
          children: [
            Expanded(child: _buildMainStatCard(context, stats[0])),
            SizedBox(width: context.dimensions.spaceM),
            Expanded(child: _buildMainStatCard(context, stats[1])),
          ],
        ),

        SizedBox(height: context.dimensions.spaceM),

        // İkinci satır - Detay istatistikler
        Row(
          children: [
            Expanded(child: _buildDetailStatCard(context, stats[2])),
            SizedBox(width: context.dimensions.spaceM),
            Expanded(child: _buildDetailStatCard(context, stats[3])),
          ],
        ),
      ],
    );
  }

  /// Ana istatistik kartı (büyük)
  Widget _buildMainStatCard(BuildContext context, StatData stat) {
    return Container(
      height: 130,
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: stat.color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: stat.color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // İkon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              stat.icon,
              color: stat.color,
              size: 22,
            ),
          ),

          // İçerik
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Değer
                Text(
                  stat.value,
                  style: AppTextTheme.headline4.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),

                SizedBox(height: 2),

                // Başlık
                Text(
                  stat.title,
                  style: AppTextTheme.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Detay istatistik kartı (küçük)
  Widget _buildDetailStatCard(BuildContext context, StatData stat) {
    return Container(
      height: 85,
      padding: EdgeInsets.all(context.dimensions.paddingS),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stat.color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              stat.icon,
              color: stat.color,
              size: 18,
            ),
          ),

          SizedBox(width: context.dimensions.spaceS),

          // İçerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Değer
                Text(
                  stat.value,
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),

                SizedBox(height: 2),

                // Başlık
                Text(
                  stat.title,
                  style: AppTextTheme.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stats verilerini getirir
  List<StatData> _getStatsData(BuildContext context, HomeState state) {
    // State'e göre gerçek veriler
    int totalAnalyses = 0;
    int healthyPlants = 0;
    int thisMonthAnalyses = 0;

    if (!state.isLoading) {
      totalAnalyses = state.totalAnalysisCount;
      healthyPlants = state.healthyPlantsCount;
      thisMonthAnalyses = state.thisMonthAnalysisCount;
    }

    return [
      StatData(
        title: 'stats_total_analysis'.locale(context),
        value: totalAnalyses.toString(),
        icon: CupertinoIcons.chart_bar_alt_fill,
        color: AppColors.primary,
      ),
      StatData(
        title: 'stats_healthy_plants'.locale(context),
        value: healthyPlants.toString(),
        icon: CupertinoIcons.leaf_arrow_circlepath,
        color: AppColors.success,
      ),
      StatData(
        title: 'stats_this_month'.locale(context),
        value: thisMonthAnalyses.toString(),
        icon: CupertinoIcons.calendar_today,
        color: AppColors.info,
      ),
      StatData(
        title: 'stats_success_rate'.locale(context),
        value: totalAnalyses > 0
            ? '${((healthyPlants / totalAnalyses) * 100).round()}%'
            : '0%',
        icon: CupertinoIcons.star_fill,
        color: AppColors.warning,
      ),
    ];
  }
}

/// Stat verisi modeli
class StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
