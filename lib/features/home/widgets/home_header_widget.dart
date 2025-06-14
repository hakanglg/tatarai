import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/text_theme.dart';
import '../../auth/cubits/auth_cubit.dart';
import '../../auth/cubits/auth_state.dart';
import '../constants/home_constants.dart';

/// Home screen header widget'ı
///
/// Kullanıcı karşılama mesajı ve gradient background
/// içeren üst banner component'i.
///
/// Özellikler:
/// - Animated gradient background
/// - User'a özel welcome mesajı
/// - Apple HIG uyumlu tasarım
/// - Theme colors kullanımı
/// - Constants ile hardcoded değer kontrolü
class HomeHeaderWidget extends StatelessWidget {
  const HomeHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
      decoration: _buildGradientDecoration(),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return _buildHeaderContent(context, state);
        },
      ),
    );
  }

  /// Gradient decoration oluşturur
  BoxDecoration _buildGradientDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary
              .withOpacity(HomeConstants.headerGradientStartOpacity),
          AppColors.primary.withOpacity(HomeConstants.headerGradientEndOpacity),
        ],
      ),
      borderRadius: BorderRadius.circular(
          16.0), // Using explicit value since context not available here
      boxShadow: [
        BoxShadow(
          color:
              AppColors.primary.withOpacity(HomeConstants.headerShadowOpacity),
          blurRadius: HomeConstants.headerShadowBlurRadius,
          offset: const Offset(0, HomeConstants.headerShadowOffsetY),
        ),
      ],
    );
  }

  /// Header içeriğini oluşturur
  Widget _buildHeaderContent(BuildContext context, AuthState authState) {
    final userName = _getUserName(authState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeText(context),
        const SizedBox(height: 4),
        _buildUserNameText(context, userName),
        SizedBox(height: context.dimensions.spaceS),
        _buildDescriptionText(context),
      ],
    );
  }

  /// Welcome text widget'ı
  Widget _buildWelcomeText(BuildContext context) {
    return Text(
      'welcome'.locale(context),
      style: AppTextTheme.largeBody.copyWith(
        color: AppColors.white.withOpacity(HomeConstants.welcomeTextOpacity),
        fontWeight: FontWeight.w500,
        letterSpacing: HomeConstants.welcomeTextLetterSpacing,
      ),
    );
  }

  /// User name text widget'ı
  Widget _buildUserNameText(BuildContext context, String userName) {
    return Text(
      userName,
      style: AppTextTheme.headline3.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.bold,
        letterSpacing: HomeConstants.headerLetterSpacing,
        shadows: [
          Shadow(
            color: AppColors.black
                .withOpacity(HomeConstants.headerTextShadowOpacity),
            offset: const Offset(0, 1),
            blurRadius: HomeConstants.headerTextShadowBlurRadius,
          ),
        ],
      ),
    );
  }

  /// Description text widget'ı
  Widget _buildDescriptionText(BuildContext context) {
    return Text(
      'plant_analysis_desc'.locale(context),
      style: AppTextTheme.body.copyWith(
        color: AppColors.white.withOpacity(HomeConstants.welcomeTextOpacity),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  /// Auth state'den kullanıcı adını çıkarır
  String _getUserName(AuthState authState) {
    if (authState is AuthAuthenticated) {
      return authState.user.name;
    }
    return 'Misafir Kullanıcı';
  }
}
