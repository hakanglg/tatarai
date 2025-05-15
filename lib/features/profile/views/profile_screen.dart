import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';
import 'package:tatarai/features/profile/cubits/profile_state.dart';
import 'package:sprung/sprung.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';

/// Kullanıcı profil bilgilerini gösteren ve düzenleyen ekran
/// Apple Human Interface Guidelines'a uygun modern tasarım
class ProfileScreen extends StatefulWidget {
  /// Constructor
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedProfileImage;
  bool _isUploading = false;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  // Profil başlığının görünürlüğü için değişken
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();

    // Kaydırma kontrolcüsünü dinleyerek başlık animasyonunu yönetelim
    _scrollController.addListener(_scrollListener);

    // Animasyon kontrolcüsü başlat
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Kullanıcı verilerini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileCubit>().refreshUserData();
    });
  }

  // Scroll pozisyonunu takip ederek başlığı göster/gizle
  void _scrollListener() {
    // 140 değeri profil fotoğrafı ve isim bölümünün yüksekliği baz alınarak belirlendi
    if (_scrollController.offset > 140 && !_showTitle) {
      setState(() {
        _showTitle = true;
      });
    } else if (_scrollController.offset <= 140 && _showTitle) {
      setState(() {
        _showTitle = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentCubit()..fetchOfferings(),
      child: _buildScreenContent(context),
    );
  }

  Widget _buildScreenContent(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Scroll pozisyonuna göre başlık gösterimi
        middle: AnimatedOpacity(
          opacity: _showTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'my_profile'.locale(context),
            style: AppTextTheme.headline6.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Modern ve hafif görünüm için arkaplan efekti
        // Blur efekti için
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        bottom: false, // Alt kenarı ekranın sonuna kadar uzatmak için
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            // Yükleniyor durumu - daha zarif bir spinner
            if (state.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(radius: 14),
                    SizedBox(height: context.dimensions.spaceM),
                    Text(
                      'loading_text'.locale(context),
                      style: AppTextTheme.caption.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Hata durumu - daha modern, minimal hata mesajı
            if (state.errorMessage != null && state.user != null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(context.dimensions.paddingL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle,
                        color: CupertinoColors.systemRed,
                        size: 50,
                      ),
                      SizedBox(height: context.dimensions.spaceM),
                      Text(
                        'error_occurred'.locale(context),
                        style: AppTextTheme.headline5.copyWith(
                          color: CupertinoColors.systemRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.dimensions.spaceS),
                      Text(
                        state.errorMessage!,
                        style: AppTextTheme.bodyText1.copyWith(
                          color: CupertinoColors.systemGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.dimensions.spaceL),
                      CupertinoButton(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.dimensions.paddingL,
                          vertical: context.dimensions.paddingS,
                        ),
                        color: CupertinoColors.systemRed,
                        borderRadius:
                            BorderRadius.circular(context.dimensions.radiusL),
                        child: Text('retry'.locale(context)),
                        onPressed: () {
                          context.read<ProfileCubit>().refreshUserData();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            final user = state.user;

            if (user == null) {
              // Hesap silindiyse veya oturum kapandıysa eski mesajları temizle
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<ProfileCubit>().clearMessages();
              });
              return BlocBuilder<AuthCubit, AuthState>(
                builder: (context, authState) {
                  if (authState.isLoading) {
                    return const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    );
                  }

                  if (authState.isAuthenticated && authState.user != null) {
                    // AuthCubit üzerinden kullanıcı verisini al
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<ProfileCubit>().refreshUserData();
                    });

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CupertinoActivityIndicator(radius: 14),
                          SizedBox(height: context.dimensions.spaceM),
                          Text(
                            'Profil bilgileri yükleniyor...',
                            style: AppTextTheme.captionL
                                .copyWith(color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.person_crop_circle_badge_xmark,
                          size: 48,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(height: context.dimensions.spaceM),
                        Text(
                          'not_logged_in'.locale(context),
                          style: AppTextTheme.headline6
                              .copyWith(color: CupertinoColors.systemGrey),
                        ),
                        SizedBox(height: context.dimensions.spaceS),
                        Text(
                          'login_to_see_profile'.locale(context),
                          style: AppTextTheme.captionL
                              .copyWith(color: CupertinoColors.systemGrey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return _buildUserProfile(context, user);
          },
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, UserModel user) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Profil Başlık Alanı - Hero bölümü
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(context.dimensions.paddingL),
            child: AnimatedBuilder(
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
              child: Column(
                children: [
                  // Profil Fotoğrafı Bölümü
                  _buildProfilePhoto(user),

                  // Kullanıcı Bilgileri - Modernize edilmiş tasarım
                  SizedBox(height: context.dimensions.spaceL),
                  Text(
                    user.displayName ?? user.email.split('@')[0],
                    style: AppTextTheme.headline1.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                      fontSize: 30,
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXS),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.mail,
                        size: 14,
                        color: AppColors.textSecondary.withOpacity(0.85),
                      ),
                      SizedBox(width: 7),
                      Text(
                        user.email,
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.85),
                          letterSpacing: -0.3,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  // E-posta doğrulama durumu göstergesi - Daha belirgin ve kontrast artan tasarım
                  if (!user.isEmailVerified) ...[
                    SizedBox(height: context.dimensions.spaceM),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                CupertinoColors.systemYellow.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  CupertinoColors.systemYellow.withOpacity(0.5),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: CupertinoColors.black,
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'email_not_verified'.locale(context),
                                style: AppTextTheme.caption.copyWith(
                                  color: CupertinoColors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Üyelik Bilgileri Kartı
                  SizedBox(height: context.dimensions.spaceL),
                  _buildMembershipCard(user),
                ],
              ),
            ),
          ),
        ),

        // Ayarlar Grupları
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Email Doğrulama Ayarları
              if (!user.isEmailVerified)
                _buildSettingsGroup(
                  header: 'account_verification'.locale(context),
                  items: [
                    _buildSettingsItem(
                      icon: CupertinoIcons.mail_solid,
                      iconColor: CupertinoColors.systemIndigo,
                      title: 'email_verification'.locale(context),
                      subtitle: 'verify_email'.locale(context),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'send'.locale(context),
                          style: AppTextTheme.button.copyWith(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.read<ProfileCubit>().sendEmailVerification();
                          _checkEmailVerification(context);
                        },
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _checkEmailVerification(context);
                      },
                    ),
                  ],
                ),

              // Satın Alma Ayarları
              _buildSettingsGroup(
                header: 'subscription'.locale(context),
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.star_circle_fill,
                    iconColor: CupertinoColors.systemYellow,
                    title: user.isPremium
                        ? 'premium_membership'.locale(context)
                        : 'upgrade_to_premium'.locale(context),
                    subtitle: user.isPremium
                        ? 'unlimited_analysis'.locale(context)
                        : 'premium_features'.locale(context),
                    trailing: user.isPremium
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  CupertinoColors.systemGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'active'.locale(context),
                              style: AppTextTheme.caption.copyWith(
                                color: CupertinoColors.systemGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Icon(
                            CupertinoIcons.chevron_right,
                            color: CupertinoColors.systemGrey,
                            size: 16,
                          ),
                    onTap: user.isPremium
                        ? () {
                            HapticFeedback.selectionClick();
                          }
                        : () async {
                            HapticFeedback.mediumImpact();
                            // Direk PremiumScreen açmak yerine paywall gösteriyoruz
                            try {
                              AppLogger.i(
                                  'Premium paywall açılıyor... (Settings Item)');

                              // Context'ten PaymentCubit'i al
                              final paymentCubit = context.read<PaymentCubit>();
                              final offerings =
                                  await paymentCubit.fetchOfferings();

                              if (offerings?.current != null) {
                                AppLogger.i(
                                    'Paywall için offerings kullanılıyor: ${offerings!.current!.identifier}');
                                RevenueCatUI.presentPaywall(
                                  offering: offerings.current!,
                                  displayCloseButton: true,
                                ).then((result) {
                                  AppLogger.i(
                                      'Paywall kapatıldı. Result: $result');
                                  // Paywall kapandıktan sonra kullanıcı bilgilerini yenile
                                  context
                                      .read<ProfileCubit>()
                                      .refreshUserData();
                                }).catchError((e) {
                                  AppLogger.e('Paywall future hatası: $e');
                                });
                              } else {
                                AppLogger.w(
                                    'Offerings bulunamadı, varsayılan paywall gösteriliyor');
                                RevenueCatUI.presentPaywall(
                                  displayCloseButton: true,
                                ).then((result) {
                                  AppLogger.i(
                                      'Varsayılan paywall kapatıldı. Result: $result');
                                  context
                                      .read<ProfileCubit>()
                                      .refreshUserData();
                                }).catchError((e) {
                                  AppLogger.e('Paywall future hatası: $e');
                                });
                              }
                            } catch (e) {
                              AppLogger.e('Premium ekranı açılırken hata: $e');
                              // Hata durumunda eski yönteme geri dön
                              // Navigator.of(context).push(
                              //   CupertinoPageRoute(
                              //     builder: (context) => const PremiumScreen(),
                              //   ),
                              // );
                            }
                          },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.creditcard_fill,
                    iconColor: CupertinoColors.systemTeal,
                    title: 'buy_credits'.locale(context),
                    subtitle: user.isPremium
                        ? 'coming_soon'.locale(context)
                        : 'coming_soon'.locale(context),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // TODO: Kredi satın alma ekranı
                    },
                  ),
                ],
              ),

              // Uygulama Ayarları
              _buildSettingsGroup(
                header: 'app_settings'.locale(context),
                items: [
                  // Dil seçimi ayarı
                  _buildSettingsItem(
                    icon: CupertinoIcons.globe,
                    iconColor: CupertinoColors.activeBlue,
                    title: 'language'.locale(context),
                    subtitle: _getCurrentLanguageName(context),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showLanguageSelectionDialog(context);
                    },
                  ),

                  _buildSettingsItem(
                    icon: CupertinoIcons.delete,
                    iconColor: CupertinoColors.systemRed,
                    title: 'delete_account_title'.locale(context),
                    subtitle: 'delete_account_subtitle'.locale(context),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _showDeleteAccountDialog();
                    },
                  ),
                ],
              ),

              // Çıkış Yap Butonu
              Padding(
                padding: EdgeInsets.only(
                  left: context.dimensions.paddingL,
                  right: context.dimensions.paddingL,
                  top: context.dimensions.paddingL,
                  bottom: context.dimensions.paddingXL,
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.square_arrow_right,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'logout_button'.locale(context),
                        style: AppTextTheme.button.copyWith(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    _showLogoutDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ayarlar grubu oluşturur
  Widget _buildSettingsGroup({String? header, required List<Widget> items}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.dimensions.paddingM,
        left: context.dimensions.paddingL,
        right: context.dimensions.paddingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                bottom: 8,
                top: 4,
              ),
              child: Text(
                header.toUpperCase(),
                style: AppTextTheme.overline.copyWith(
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: items,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ayar satırı oluşturur
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: subtitle != null ? 12 : 14,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.systemGrey6,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Sol taraftaki ikon
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    (iconColor ?? CupertinoColors.systemBlue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? CupertinoColors.systemBlue,
                size: 18,
              ),
            ),

            SizedBox(width: 16),

            // Başlık ve alt başlık
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextTheme.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextTheme.caption.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Sağ taraftaki bileşen
            trailing ??
                Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey3,
                  size: 16,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(UserModel user) {
    return GestureDetector(
      onTap: _showPhotoSourceDialog,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Profil fotoğrafı - Arkaplan rengi güçlendirildi
          Container(
            width: 125,
            height: 125,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.white,
              border: Border.all(
                color: CupertinoColors.white,
                width: 4,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CupertinoColors.systemGrey4,
                  CupertinoColors.systemGrey5,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: CupertinoColors.white.withOpacity(0.9),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(62.5),
              child: _isUploading
                  ? const Center(child: CupertinoActivityIndicator(radius: 20))
                  : _selectedProfileImage != null
                      ? Hero(
                          tag: 'profile_photo',
                          child: Image.file(
                            _selectedProfileImage!,
                            fit: BoxFit.cover,
                            width: 125,
                            height: 125,
                          ),
                        )
                      : user.photoURL != null
                          ? Hero(
                              tag: 'profile_photo',
                              child: Image.network(
                                user.photoURL!,
                                fit: BoxFit.cover,
                                width: 125,
                                height: 125,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 15,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  AppLogger.e(
                                      'Profil resmi yükleme hatası: $error');
                                  return Icon(
                                    CupertinoIcons.person_fill,
                                    size: 62,
                                    color: AppColors.primary,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              CupertinoIcons.person_fill,
                              size: 62,
                              color: AppColors.primary,
                            ),
            ),
          ),

          // Değiştir butonu - Daha belirgin
          Positioned(
            bottom: 0,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: CupertinoColors.white,
                  width: 3,
                ),
              ),
              child: const Icon(
                CupertinoIcons.camera_fill,
                color: CupertinoColors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard(UserModel user) {
    // Modern Apple-style renkler
    final Color cardBgColor = user.isPremium
        ? const Color(0xFF0A8D48) // Daha parlak premium yeşil
        : const Color(0xFF2C2C2E); // Daha koyu ve şık gri

    final Color highlightColor = user.isPremium
        ? const Color(0xFFF9CF58) // Premium altın vurgu
        : CupertinoColors.systemGrey; // Standard gri

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardBgColor,
            cardBgColor.withOpacity(0.95),
            Color.lerp(cardBgColor, Colors.black, 0.15) ?? cardBgColor,
          ],
          stops: const [0.1, 0.6, 0.9],
        ),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          // Modern gölgelendirme
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 10),
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.07),
            blurRadius: 4,
            offset: const Offset(0, -1),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sol taraf - Modern ikon ve üyelik bilgisi
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.12),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        user.isPremium
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.person_crop_circle_fill,
                        color: Colors.white,
                        size: context.dimensions.iconSizeS,
                      ),
                    ),
                  ),
                  SizedBox(width: context.dimensions.spaceS),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.isPremium
                            ? 'premium_account'.locale(context)
                            : 'standard_member'.locale(context),
                        style: AppTextTheme.headline6.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: context.dimensions.spaceXXS),
                      Text(
                        user.isPremium
                            ? 'unlimited_analysis'.locale(context)
                            : 'limited_access'.locale(context),
                        style: AppTextTheme.caption.copyWith(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Sağ taraf - Premium rozeti
              if (user.isPremium)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.dimensions.spaceXS,
                    vertical: context.dimensions.spaceXXS + 1,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        highlightColor.withOpacity(0.9),
                        highlightColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(context.dimensions.radiusS),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.star_fill,
                        color: Colors.white,
                        size: context.dimensions.iconSizeXS * 0.75,
                      ),
                      SizedBox(width: context.dimensions.spaceXXS),
                      Text(
                        'premium_tag'.locale(context),
                        style: AppTextTheme.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: context.dimensions.spaceM),

          // Kalan analiz bilgisi - Daha görsel ve modern
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.chart_bar_alt_fill,
                        color: Colors.white.withOpacity(0.9),
                        size: context.dimensions.iconSizeXS * 0.9,
                      ),
                      SizedBox(width: context.dimensions.spaceXXS + 2),
                      Text(
                        'remaining_analysis'.locale(context),
                        style: AppTextTheme.bodyText2.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Değer ve yenileme butonu
                  GestureDetector(
                    onTap: () {
                      // Haptic feedback ve yenileme
                      HapticFeedback.lightImpact();
                      context.read<ProfileCubit>().refreshUserData();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.dimensions.paddingXS,
                        vertical: context.dimensions.spaceXXS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(context.dimensions.radiusS),
                      ),
                      child: Row(
                        children: [
                          user.isPremium
                              ? Icon(
                                  CupertinoIcons.infinite,
                                  color: highlightColor,
                                  size: context.dimensions.iconSizeS * 0.9,
                                )
                              : Text(
                                  '${user.analysisCredits}',
                                  style: AppTextTheme.headline6.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          SizedBox(width: context.dimensions.spaceXXS),
                          Icon(
                            CupertinoIcons.refresh_thin,
                            color: Colors.white.withOpacity(0.7),
                            size: context.dimensions.iconSizeXS * 0.75,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: context.dimensions.spaceXS),

              // İlerleme çubuğu - Modern tasarım
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(context.dimensions.radiusXS),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Sprung.criticallyDamped,
                          width: user.isPremium
                              ? width
                              : (width * user.analysisCredits / 10)
                                  .clamp(0.0, width),
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: user.isPremium
                                  ? [
                                      highlightColor,
                                      highlightColor.withOpacity(0.85),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.7),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusXS),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: context.dimensions.spaceM),

          // Premium olmayan kullanıcılar için yükseltme butonu - Modern iOS 17 stili
          if (!user.isPremium)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.mediumImpact();
                try {
                  AppLogger.i('Premium paywall açılıyor... (Membership Card)');

                  // Context'ten PaymentCubit'i al
                  final paymentCubit = context.read<PaymentCubit>();

                  // Asenkron şekilde fetchOfferings çağır ve offerings ile devam et
                  paymentCubit.fetchOfferings().then((offerings) {
                    if (offerings?.current != null) {
                      AppLogger.i(
                          'Paywall için offerings kullanılıyor: ${offerings!.current!.identifier}');
                      return RevenueCatUI.presentPaywall(
                        offering: offerings.current!,
                        displayCloseButton: true,
                      );
                    } else {
                      AppLogger.w(
                          'Offerings bulunamadı, varsayılan paywall gösteriliyor');
                      return RevenueCatUI.presentPaywall(
                        displayCloseButton: true,
                      );
                    }
                  }).then((result) {
                    AppLogger.i('Paywall kapatıldı. Result: $result');
                    // Paywall kapandıktan sonra kullanıcı bilgilerini yenile
                    context.read<ProfileCubit>().refreshUserData();
                  }).catchError((e) {
                    AppLogger.e('Paywall future hatası: $e');
                  });
                } catch (e) {
                  AppLogger.e('Premium ekranı açılırken hata: $e');
                  // Hata durumunda eski yönteme geri dön
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: context.dimensions.paddingS,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CupertinoColors.white,
                      CupertinoColors.white.withOpacity(0.92),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(context.dimensions.radiusS),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up_circle_fill,
                      color: const Color(0xFF0A8D48),
                      size: context.dimensions.iconSizeS * 0.9,
                    ),
                    SizedBox(width: context.dimensions.spaceXS),
                    Text(
                      'upgrade_to_premium'.locale(context),
                      style: AppTextTheme.headline5.copyWith(
                        color: const Color(0xFF0A8D48),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    AppDialogManager.showConfirmDialog(
      context: context,
      title: 'delete_account_title'.locale(context),
      message: 'delete_account_warning'.locale(context) +
          '\n\n' +
          'data_to_be_deleted'.locale(context) +
          ':\n' +
          '• ' +
          'user_data'.locale(context) +
          '\n' +
          '• ' +
          'analysis_history'.locale(context) +
          '\n' +
          '• ' +
          'purchased_credits'.locale(context),
      confirmText: 'delete_account_title'.locale(context),
      cancelText: 'cancel'.locale(context),
      onConfirmPressed: () {
        if (!mounted) return;
        context.read<ProfileCubit>().deleteAccount();
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    AppDialogManager.showConfirmDialog(
      context: context,
      title: 'logout_title'.locale(context),
      message: 'logout_confirmation'.locale(context),
      confirmText: 'logout_button'.locale(context),
      cancelText: 'cancel'.locale(context),
      onConfirmPressed: () {
        if (!mounted) return;
        context.read<ProfileCubit>().signOut();
        context.goNamed(RouteNames.login);
      },
    );
  }

  void _checkEmailVerification(BuildContext context) async {
    final profileCubit = context.read<ProfileCubit>();

    // Yükleniyor dialkogu göster
    if (!mounted) return;

    AppDialogManager.showLoadingDialog(
      context: context,
      message: 'checking_verification'.locale(context),
    );

    try {
      // ProfileCubit üzerinden doğrulama durumunu kontrol et
      final isVerified =
          await profileCubit.checkAndUpdateEmailVerificationStatus();

      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context).pop();

      // Sonuç dialoglarını göster
      if (isVerified) {
        _showSuccessDialog(context);
      } else {
        _showNotVerifiedDialog(context);
      }
    } catch (error) {
      // Hata durumunda
      if (!mounted) return;
      Navigator.of(context).pop(); // Dialog'u kapat
      _showErrorDialog(context, error.toString());
    }
  }

  // Doğrulama başarılı mesajı
  void _showSuccessDialog(BuildContext context) {
    if (!mounted) return;

    AppDialogManager.showIconDialog(
      context: context,
      title: 'email_verified'.locale(context),
      message: 'email_verification_success'.locale(context),
      icon: CupertinoIcons.checkmark_circle_fill,
      iconColor: CupertinoColors.systemGreen,
      buttonText: 'done'.locale(context),
      onPressed: () {
        if (!mounted) return;
        // State'i yenile
        context.read<ProfileCubit>().refreshUserData();
      },
    );
  }

  // Doğrulama başarısız mesajı
  void _showNotVerifiedDialog(BuildContext context) {
    if (!mounted) return;

    AppDialogManager.showConfirmDialog(
      context: context,
      title: 'not_verified'.locale(context),
      message: 'email_not_verified_message'.locale(context),
      confirmText: 'resend'.locale(context),
      cancelText: 'cancel'.locale(context),
      onConfirmPressed: () {
        if (!mounted) return;
        // Yeni doğrulama e-postası gönder
        context.read<ProfileCubit>().sendEmailVerification();
        _showVerificationEmailSentDialog(context);
      },
    );
  }

  // Doğrulama e-postası gönderildi mesajı
  void _showVerificationEmailSentDialog(BuildContext context) {
    if (!mounted) return;

    AppDialogManager.showConfirmDialog(
      context: context,
      title: 'email_sent'.locale(context),
      message: 'verification_email_sent'.locale(context) +
          '\n' +
          'check_email'.locale(context),
      confirmText: 'check_status'.locale(context),
      cancelText: 'done'.locale(context),
      onConfirmPressed: () {
        if (!mounted) return;
        _checkEmailVerification(context);
      },
    );
  }

  // Hata mesajı
  void _showErrorDialog(BuildContext context, String errorMessage) {
    if (!mounted) return;

    AppDialogManager.showErrorDialog(
      context: context,
      title: 'error'.locale(context),
      message: 'verification_error'.locale(context),
      onPressed: () {
        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }

  /// Fotoğraf seçim menüsünü göster
  Future<void> _showPhotoSourceDialog() async {
    if (!mounted) return;

    HapticFeedback.lightImpact();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'choose_profile_photo'.locale(context),
          style: AppTextTheme.bodyLarge,
        ),
        message: Text(
          'photo_source'.locale(context),
          style: AppTextTheme.bodyMedium,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text(
              'camera'.locale(context),
              style: AppTextTheme.largeBody.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text(
              'gallery'.locale(context),
              style: AppTextTheme.largeBody.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  // Fotoğraf seç - Business Logic'i ProfileCubit'e taşınmış, sadece UI işlemleri burada
  Future<void> _pickImage(ImageSource source) async {
    try {
      final profileCubit = context.read<ProfileCubit>();
      HapticFeedback.lightImpact();

      // UI'da yükleme durumunu göster
      setState(() {
        _isUploading = true;
      });

      // ProfileCubit üzerinden görüntü seç
      final imageFile = await profileCubit.pickImage(source);

      if (imageFile == null) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
        return;
      }

      // UI'da seçilen fotoğrafı göster
      if (mounted) {
        setState(() {
          _selectedProfileImage = imageFile;
        });
      }

      try {
        // ProfileCubit'in updateUserPhotoAndRefresh metodunu kullanarak fotoğrafı işle
        final imageUrl =
            await profileCubit.updateUserPhotoAndRefresh(imageFile);

        if (imageUrl != null && mounted) {
          _showSnackBar(context, 'photo_updated'.locale(context));
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        AppLogger.e('Profil fotoğrafı işleme hatası', e.toString());
        if (mounted) {
          String errorMsg = profileCubit.getPhotoUploadErrorMessage(e);
          _showSnackBar(context, errorMsg);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Profil fotoğrafı seçme hatası: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showSnackBar(context, 'unexpected_error'.locale(context));
      }
    }
  }

  String _getCurrentLanguageName(BuildContext context) {
    final currentLocale = LocalizationManager.instance.currentLocale;

    if (currentLocale.languageCode == 'tr') {
      return 'language_tr'.locale(context);
    } else {
      return 'language_en'.locale(context);
    }
  }

  void _showLanguageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('select_language'.locale(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context,
              'language_tr'.locale(context),
              LocaleConstants.trLocale,
            ),
            const SizedBox(height: 8),
            _buildLanguageOption(
              context,
              'language_en'.locale(context),
              LocaleConstants.enLocale,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.locale(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, String languageName, Locale locale) {
    final isSelected =
        LocalizationManager.instance.currentLocale.languageCode ==
            locale.languageCode;

    return ListTile(
      title: Text(languageName),
      leading: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined),
      tileColor: isSelected ? AppColors.surfaceVariant : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        LocalizationManager.instance.changeLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  /// Bildirim göster
  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;

    // AppDialogManager'daki adaptif metodu kullan
    AppDialogManager.showSnackBar(
      context: context,
      message: message,
    );
  }
}
