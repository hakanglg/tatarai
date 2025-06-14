import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../navbar/navigation_manager.dart';
import '../constants/home_constants.dart';

/// Home quick actions widget'ı
///
/// Ana sayfada hızlı erişim butonları içeren grid component'i.
///
/// Özellikler:
/// - 2x1 grid layout
/// - Analiz ve profil quick access
/// - Apple HIG uyumlu cards
/// - Theme colors ve constants kullanımı
/// - NavigationManager ile tab switching
class HomeQuickActionsWidget extends StatelessWidget {
  const HomeQuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context),
          SizedBox(height: context.dimensions.paddingXS),
          _buildQuickActionsGrid(context),
        ],
      ),
    );
  }

  /// Section title widget'ı
  Widget _buildSectionTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.dimensions.paddingXS,
        bottom: context.dimensions.paddingXS,
      ),
      child: Text(
        'quick_actions'.locale(context),
        style: AppTextTheme.headline6.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: HomeConstants.titleLetterSpacing,
        ),
      ),
    );
  }

  /// Quick actions grid widget'ı
  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: HomeConstants.quickActionsGridCrossAxisCount,
      childAspectRatio: HomeConstants.quickActionsGridAspectRatio,
      mainAxisSpacing: context.dimensions.spaceS,
      crossAxisSpacing: context.dimensions.spaceS,
      children: [
        _buildAnalysisCard(context),
        _buildProfileCard(context),
      ],
    );
  }

  /// Analiz kartı widget'ı
  Widget _buildAnalysisCard(BuildContext context) {
    return _buildQuickActionCard(
      context: context,
      title: 'start_analysis'.locale(context),
      subtitle: 'analyze_your_plant'.locale(context),
      icon: CupertinoIcons.leaf_arrow_circlepath,
      color: AppColors.primary,
      onTap: () => _navigateToAnalysis(),
    );
  }

  /// Profil kartı widget'ı
  Widget _buildProfileCard(BuildContext context) {
    return _buildQuickActionCard(
      context: context,
      title: 'profile'.locale(context),
      subtitle: 'view_settings'.locale(context),
      icon: CupertinoIcons.person_circle,
      color: AppColors.info,
      onTap: () => _navigateToProfile(),
    );
  }

  /// Quick action card base widget'ı
  Widget _buildQuickActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        child: Container(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(context.dimensions.radiusL),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardIcon(color, icon),
              const Spacer(),
              _buildCardTitle(title),
              SizedBox(height: context.dimensions.spaceXS),
              _buildCardSubtitle(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  /// Card icon widget'ı
  Widget _buildCardIcon(Color color, IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  /// Card title widget'ı
  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: AppTextTheme.headline5.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: HomeConstants.titleLetterSpacing,
      ),
    );
  }

  /// Card subtitle widget'ı
  Widget _buildCardSubtitle(String subtitle) {
    return Text(
      subtitle,
      style: AppTextTheme.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Analiz ekranına navigate eder
  void _navigateToAnalysis() {
    final navManager = NavigationManager.instance;
    if (navManager != null) {
      navManager.switchToTab(HomeConstants.analysisTabIndex);
    }
  }

  /// Profil ekranına navigate eder
  void _navigateToProfile() {
    final navManager = NavigationManager.instance;
    if (navManager != null) {
      navManager.switchToTab(HomeConstants.profileTabIndex);
    }
  }
}
