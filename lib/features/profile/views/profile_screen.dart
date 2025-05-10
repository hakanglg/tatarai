import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';
import 'package:sprung/sprung.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/utils/permission_manager.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
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
      onTap: _pickImage,
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
                  : _selectedProfileImage != null || user.photoURL != null
                      ? Hero(
                          tag: 'profile_photo',
                          child: _selectedProfileImage != null
                              ? Image.file(
                                  _selectedProfileImage!,
                                  fit: BoxFit.cover,
                                  width: 125,
                                  height: 125,
                                )
                              : Image.network(
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

  void _showLogoutDialog(BuildContext context) {
    HapticFeedback.mediumImpact();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('logout_title'.locale(context)),
        content: Text('logout_confirmation'.locale(context)),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.locale(context)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().signOut();
              context.goNamed(RouteNames.login);
            },
            child: Text('logout_button'.locale(context)),
          ),
        ],
      ),
    );
  }

  void _checkEmailVerification(BuildContext context) async {
    final profileCubit = context.read<ProfileCubit>();

    // Yükleniyor dialog göster
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Center(
          child: CupertinoActivityIndicator(),
        ),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            'checking_verification'.locale(context),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    try {
      final isVerified = await profileCubit.refreshEmailVerificationStatus();
      if (context.mounted) {
        Navigator.of(context).pop(); // Dialogu kapat
      }
      if (isVerified) {
        _showSuccessDialog(context);
      } else {
        _showNotVerifiedDialog(context);
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dialogu kapat
        _showErrorDialog(context, error.toString());
      }
    }
  }

  // Doğrulama başarılı mesajı
  void _showSuccessDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.systemGreen,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('email_verified'.locale(context)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'email_verification_success'.locale(context),
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('done'.locale(context)),
            onPressed: () {
              Navigator.of(context).pop();
              // State'i yenile
              context.read<ProfileCubit>().refreshUserData();
            },
          ),
        ],
      ),
    );
  }

  // Doğrulama başarısız mesajı
  void _showNotVerifiedDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: CupertinoColors.systemYellow,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('not_verified'.locale(context)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'email_not_verified_message'.locale(context),
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('resend'.locale(context)),
            onPressed: () {
              Navigator.of(context).pop();
              // Yeni doğrulama e-postası gönder
              context.read<ProfileCubit>().sendEmailVerification();
              _showVerificationEmailSentDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // Doğrulama e-postası gönderildi mesajı
  void _showVerificationEmailSentDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.mail_solid,
              color: CupertinoColors.activeBlue,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('email_sent'.locale(context)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            children: [
              Text(
                'verification_email_sent'.locale(context),
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'check_email'.locale(context),
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('done'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('check_status'.locale(context)),
            onPressed: () {
              Navigator.of(context).pop();
              _checkEmailVerification(context);
            },
          ),
        ],
      ),
    );
  }

  // Hata mesajı
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.systemRed,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('error'.locale(context)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'verification_error'.locale(context),
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('done'.locale(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.heavyImpact();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemRed,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('delete_account_title'.locale(context)),
          ],
        ),
        content: Column(
          children: [
            SizedBox(height: 12),
            Text(
              'delete_account_warning'.locale(context),
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'data_to_be_deleted'.locale(context),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'user_data'.locale(context) +
                        '\n' +
                        'analysis_history'.locale(context) +
                        '\n' +
                        'purchased_credits'.locale(context),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.locale(context)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().deleteAccount();
            },
            child: Text('delete_account_title'.locale(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.lightImpact();

      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text('choose_profile_photo'.locale(context)),
          message: Text('photo_source'.locale(context)),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
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
                _pickImageFromSource(ImageSource.gallery);
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
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.locale(context)),
          ),
        ),
      );
    } catch (e) {
      AppLogger.e('Profil fotoğrafı seçme hatası', e);
    }
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final profileCubit = context.read<ProfileCubit>();

      AppLogger.i(
          'Profil fotoğrafı seçimi başlatılıyor, kaynak: ${source == ImageSource.camera ? 'Kamera' : 'Galeri'}');

      // İzin kontrolü - yeni merkezi PermissionManager kullanımı
      final permissionType = source == ImageSource.camera
          ? AppPermissionType.camera
          : AppPermissionType.photos;

      bool hasPermission = await PermissionManager.requestPermission(
        permissionType,
        context: context,
      );

      if (!hasPermission) {
        AppLogger.w(
            '${source == ImageSource.camera ? 'Kamera' : 'Galeri'} izni alınamadı');
        return;
      }

      // Resim seçme işlemi
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front, // Ön kamera tercih edilsin
      );

      if (image == null) {
        AppLogger.i('Görüntü seçimi iptal edildi');
        return;
      }

      // Dosya kontrolü
      final File imageFile = File(image.path);
      if (!imageFile.existsSync()) {
        AppLogger.e('Seçilen dosya bulunamadı: ${image.path}');
        if (mounted) {
          _showSnackBar(
              context, 'file_not_found_or_accessible'.locale(context));
        }
        return;
      }

      // Dosya boyutu kontrolü (5MB sınırı)
      final fileSize = await imageFile.length();
      AppLogger.i(
          'Seçilen resim: ${image.path}, boyut: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // 5MB'dan büyükse kullanıcıya hata mesajı gösterelim
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          _showSnackBar(context, 'file_too_large'.locale(context));
        }
        return;
      }

      // Yüklemeye geç
      if (mounted) {
        setState(() {
          _selectedProfileImage = imageFile;
          _isUploading = true;
        });

        // Firebase Token'ını yenile ve yükleme durumunu ayarla
        await profileCubit.prepareForImageUpload();

        try {
          // Resmi Firebase Storage'a yükle
          final String imageUrl =
              await _uploadProfileImage(_selectedProfileImage!);

          // Kullanıcı profilini güncelle
          await profileCubit.updateProfile(photoURL: imageUrl);

          // Başarılı mesajı göster
          if (mounted) {
            _showSnackBar(context, 'photo_updated'.locale(context));
          }
        } catch (e) {
          AppLogger.e('Profil fotoğrafı yükleme hatası', e.toString());
          if (mounted) {
            String errorMsg = _getErrorMessage(e);
            _showSnackBar(context, errorMsg);
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });

            // ProfileCubit'e yükleme durumunu bildir
            profileCubit.setImageUploading(false);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      context.read<ProfileCubit>().setImageUploading(false);

      // Çeşitli hata tiplerini ele alalım
      AppLogger.e('Profil fotoğrafı seçme hatası', e.toString());

      if (mounted) {
        _showSnackBar(context, _getPlatformErrorMessage(e));
      }
    }
  }

  // Kaynak türüne göre izin kontrolü yapar
  Future<bool> _checkPermission(ImageSource source) async {
    try {
      final permissionType = source == ImageSource.camera
          ? AppPermissionType.camera
          : AppPermissionType.photos;

      return await PermissionManager.requestPermission(
        permissionType,
        context: context,
      );
    } catch (e) {
      AppLogger.e('İzin kontrolü hatası', e.toString());
      return false;
    }
  }

  // Hata mesajlarını kullanıcı dostu hale getir
  String _getErrorMessage(dynamic error) {
    String errorMsg = 'upload_error'.locale(context);

    // Hata mesajını kullanıcı dostu hale getirelim
    if (error.toString().contains('storage/unauthorized')) {
      errorMsg = 'auth_error'.locale(context);
    } else if (error.toString().contains('storage/quota-exceeded')) {
      errorMsg = 'storage_full'.locale(context);
    } else if (error.toString().contains('storage/retry-limit-exceeded')) {
      errorMsg = 'connection_error'.locale(context);
    } else if (error.toString().contains('dosya bulunamadı')) {
      errorMsg = 'file_not_found'.locale(context);
    } else if (error.toString().contains('dosya boyutu')) {
      errorMsg = 'file_size_error'.locale(context);
    } else if (error.toString().contains('network')) {
      errorMsg = 'network_error'.locale(context);
    }

    return errorMsg;
  }

  // Platform hatalarını kullanıcı dostu hale getir
  String _getPlatformErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'photo_access_denied':
        case 'camera_access_denied':
          return 'access_denied'.locale(context);
        case 'camera_not_available':
          return 'camera_not_available'.locale(context);
        case 'camera_in_use':
          return 'camera_in_use'.locale(context);
        case 'invalid_image':
          return 'invalid_image'.locale(context);
        default:
          return 'error'.locale(context) + ': ${error.message}';
      }
    } else {
      return 'unexpected_error'.locale(context);
    }
  }

  /// Profil fotoğrafını Firebase Storage'a yükler
  Future<String> _uploadProfileImage(File imageFile) async {
    try {
      AppLogger.i('Profil fotoğrafı yükleme başlatılıyor');

      // Firebase Storage referansını al
      final userId = context.read<ProfileCubit>().state.user?.id;
      if (userId == null || userId.isEmpty) {
        AppLogger.e('Kullanıcı ID bulunamadı veya boş');
        throw Exception('Kullanıcı oturum açmamış veya ID bulunamadı');
      }

      AppLogger.i('Profil fotoğrafı yükleniyor, User ID: $userId');

      // Dosya kontrolü
      if (!imageFile.existsSync()) {
        AppLogger.e('Dosya bulunamadı: ${imageFile.path}');
        throw Exception('Seçilen dosya bulunamadı veya erişilemiyor');
      }

      final fileSize = await imageFile.length();
      AppLogger.i('Dosya boyutu: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize > 5 * 1024 * 1024) {
        // 5MB'dan büyük dosyaları reddet
        AppLogger.e(
            'Dosya çok büyük: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        throw Exception(
            'Dosya boyutu çok büyük, lütfen daha küçük bir fotoğraf seçin (maks. 5MB)');
      }

      // Kullanıcı oturum açık mı kontrol et ve token yenile
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        AppLogger.e('Firebase kullanıcısı null, oturum açık değil');
        throw Exception(
            'Oturum süresi dolmuş olabilir, lütfen tekrar giriş yapın');
      }

      // Token yenileme denemesi
      try {
        await firebaseUser.getIdToken(true);
        AppLogger.i('Firebase token yenilendi');
      } catch (tokenError) {
        AppLogger.w('Token yenilenemedi: $tokenError');
        // Token yenilenemese bile devam et
      }

      // Firebase Storage'a profil fotoğrafını yükle
      final storageRef = FirebaseStorage.instance.ref();

      // Storage kurallarına göre yol belirleme
      final profileImageRef = storageRef.child(
          'profile_images/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      AppLogger.i('Storage referansı oluşturuldu: ${profileImageRef.fullPath}');

      // İmajı sıkıştırmayı dene
      Uint8List? imageData;
      try {
        AppLogger.i('Görüntü sıkıştırma başlıyor');
        final compressedImage = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: 85,
          minWidth: 500,
          minHeight: 500,
        );

        if (compressedImage != null) {
          imageData = compressedImage;
          AppLogger.i('Görüntü sıkıştırıldı: ${imageData.length} bytes');
        } else {
          AppLogger.w('Sıkıştırma başarısız, orijinal görüntü kullanılacak');
          imageData = await imageFile.readAsBytes();
          AppLogger.i('Orijinal görüntü: ${imageData.length} bytes');
        }
      } catch (compressError) {
        AppLogger.w(
            'Sıkıştırma hatası: $compressError, orijinal görüntü kullanılacak');
        imageData = await imageFile.readAsBytes();
      }

      // Yüklemeyi başlat
      try {
        // Metadata ile içerik tipini belirle
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': userId},
        );

        // Yükleme işlemini başlat
        final uploadTask = profileImageRef.putData(imageData!, metadata);

        // İlerleme takibi
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          AppLogger.i(
              'Yükleme ilerlemesi: ${(progress * 100).toStringAsFixed(1)}%');
        }, onError: (e) {
          AppLogger.e('Yükleme takibi sırasında hata', e.toString());
        });

        // Yükleme bitene kadar bekle
        final snapshot = await uploadTask
            .whenComplete(() => AppLogger.i('Yükleme tamamlandı'));

        // İndirme URL'sini al
        final downloadUrl = await snapshot.ref.getDownloadURL();
        AppLogger.i('Profil fotoğrafı başarıyla yüklendi: $downloadUrl');
        return downloadUrl;
      } on FirebaseException catch (storageError) {
        AppLogger.e(
            'Firebase Storage hatası: ${storageError.code}', storageError);

        switch (storageError.code) {
          case 'storage/unauthorized':
            throw Exception('Yetki hatası: Dosyayı yükleme izniniz yok');
          case 'storage/canceled':
            throw Exception('Yükleme iptal edildi');
          case 'storage/retry-limit-exceeded':
            throw Exception(
                'Bağlantı hatası: İnternet bağlantınızı kontrol edin');
          case 'storage/invalid-checksum':
            throw Exception('Dosya bozuk veya transfer sırasında hata oluştu');
          case 'storage/server-file-wrong-size':
            throw Exception(
                'Dosya boyutu hataları, lütfen daha küçük bir dosya deneyin');
          case 'storage/quota-exceeded':
            throw Exception('Depolama kotası aşıldı');
          default:
            throw Exception('Firebase Storage hatası: ${storageError.code}');
        }
      } catch (error) {
        AppLogger.e('Dosya yükleme işlemi başarısız', error.toString());
        throw Exception(
            'Dosya yüklenirken beklenmeyen bir hata oluştu: ${error.toString()}');
      }
    } catch (e) {
      AppLogger.e('Profil fotoğrafı yükleme hatası', e.toString());
      rethrow; // Asıl hatayı ilet
    }
  }

  /// Bildirim göster
  void _showSnackBar(BuildContext context, String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.darkColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                message.contains('success') || message.contains('başarı')
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.info_circle_fill,
                color: message.contains('success') || message.contains('başarı')
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.activeBlue,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Icon(
                  CupertinoIcons.xmark,
                  color: CupertinoColors.systemGrey,
                  size: 16,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelectionTile(BuildContext context) {
    return InkWell(
      onTap: () => _showLanguageSelectionDialog(context),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.dimensions.paddingM,
          vertical: context.dimensions.paddingM,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.language_rounded,
              color: AppColors.primary,
            ),
            SizedBox(width: context.dimensions.spaceM),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'language'.locale(context),
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceXS),
                Text(
                  _getCurrentLanguageName(context),
                  style: AppTextTheme.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
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
}
