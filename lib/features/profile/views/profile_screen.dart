import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircleAvatar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/auth_state.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';

/// Kullanıcı profil bilgilerini gösteren ve düzenleyen ekran
class ProfileScreen extends StatelessWidget {
  /// Constructor
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Profil')),
      child: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final user = state.user;

            if (user == null) {
              return const Center(child: Text('Oturum açık değil'));
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Profil fotoğrafı
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: CupertinoColors.systemGrey5,
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Kullanıcı adı
                        Text(
                          user.displayName ?? user.email.split('@')[0],
                          style: AppTextTheme.headline2,
                        ),
                        const SizedBox(height: 8),
                        // E-posta
                        Text(user.email, style: AppTextTheme.subtitle1),
                        const SizedBox(height: 8),
                        // Premium durumu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              user.isPremium
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.star,
                              color:
                                  user.isPremium
                                      ? CupertinoColors.systemYellow
                                      : CupertinoColors.systemGrey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user.isPremium ? 'Premium Üye' : 'Ücretsiz Üye',
                              style: AppTextTheme.subtitle2.copyWith(
                                color:
                                    user.isPremium
                                        ? CupertinoColors.systemYellow
                                        : CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Analiz kredisi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.leaf_arrow_circlepath,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kalan Analiz: ${user.analysisCredits}',
                              style: AppTextTheme.subtitle2.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSettingsItem(
                      title: 'Profili Düzenle',
                      icon: CupertinoIcons.person_crop_circle_fill_badge_exclam,
                      onTap: () {},
                    ),

                    if (!user.isEmailVerified) ...[
                      _buildSettingsItem(
                        title: 'E-posta Doğrulama',
                        icon: CupertinoIcons.mail_solid,
                        showTrailingIcon: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemRed.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: const Text(
                                'Doğrulanmadı',
                                style: TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 4.0,
                              ),
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6.0),
                              minSize: 0,
                              child: const Text(
                                'Doğrulama Gönder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.white,
                                ),
                              ),
                              onPressed: () {
                                context
                                    .read<AuthCubit>()
                                    .sendEmailVerification();
                                _showVerificationDialog(context);
                              },
                            ),
                          ],
                        ),
                        onTap: () {},
                      ),

                      // E-posta doğrulama durumunu yenileme butonu
                      _buildSettingsItem(
                        title: 'Doğrulama Durumunu Güncelle',
                        icon: CupertinoIcons.refresh,
                        showTrailingIcon: false,
                        trailing: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4.0,
                          ),
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(6.0),
                          minSize: 0,
                          child: const Text(
                            'Güncelle',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.white,
                            ),
                          ),
                          onPressed: () {
                            context
                                .read<AuthCubit>()
                                .refreshEmailVerificationStatus();
                            _showRefreshEmailDialog(context);
                          },
                        ),
                        onTap: () {},
                      ),
                    ],

                    _buildSettingsItem(
                      title: 'Premium\'a Yükselt',
                      icon: CupertinoIcons.star_circle_fill,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => const PremiumScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      title: 'Kredi Satın Al',
                      icon: CupertinoIcons.cart_fill,
                      onTap: () {},
                    ),
                    _buildSettingsItem(
                      title: 'Analiz Geçmişi',
                      icon: CupertinoIcons.clock_fill,
                      onTap: () {},
                    ),
                    _buildSettingsItem(
                      title: 'Yardım',
                      icon: CupertinoIcons.question_circle_fill,
                      onTap: () {},
                    ),
                    _buildSettingsItem(
                      title: 'Hakkında',
                      icon: CupertinoIcons.info_circle_fill,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AppButton(
                        type: AppButtonType.destructive,
                        text: 'Çıkış Yap',
                        isLoading: state.isLoading,
                        onPressed: () => _showLogoutDialog(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Ayarlar öğesi oluşturur
  Widget _buildSettingsItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool showTrailingIcon = true,
    Widget? trailing,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: AppTextTheme.bodyText1)),
            if (showTrailingIcon)
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey,
              ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// Çıkış diyaloğu gösterir
  void _showLogoutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Çıkış Yap'),
            content: const Text(
              'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AuthCubit>().signOut();
                  context.goNamed(RouteNames.login);
                },
                child: const Text('Çıkış Yap'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            ],
          ),
    );
  }

  /// Doğrulama e-postası gönderildiğini bildiren diyalog
  void _showVerificationDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Doğrulama E-postası Gönderildi'),
            content: const Text(
              'E-posta adresinize bir doğrulama bağlantısı gönderdik. '
              'Lütfen e-postanızı kontrol edin ve bağlantıya tıklayarak hesabınızı doğrulayın. '
              'Doğrulama durumunuz otomatik olarak kontrol edilecektir.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Tamam'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  /// Doğrulama durumu güncellendiğinde gösterilen diyalog
  void _showRefreshEmailDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Doğrulama Durumu Güncellendi'),
            content: const Text(
              'E-posta doğrulama durumunuz kontrol edildi. '
              'Eğer e-postanızı doğruladıysanız, profil bilgileriniz güncellenecektir.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Tamam'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
}
