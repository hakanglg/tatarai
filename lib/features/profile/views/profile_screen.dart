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
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';
import 'package:sprung/sprung.dart';

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
    return _buildScreenContent(context);
  }

  Widget _buildScreenContent(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        // Scroll pozisyonuna göre başlık gösterimi
        middle: AnimatedOpacity(
          opacity: _showTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Profilim',
            style: AppTextTheme.headline6.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Modern ve hafif görünüm için arkaplan efekti
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
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
                      'Yükleniyor...',
                      style: AppTextTheme.subtitle2.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Hata durumu - daha modern, minimal hata mesajı
            if (state.errorMessage != null) {
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
                        'Hata Oluştu',
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
                        child: const Text('Tekrar Dene'),
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
              return const Center(
                child: Text('Oturum açık değil',
                    style: TextStyle(color: CupertinoColors.systemGrey)),
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
                        style: AppTextTheme.subtitle2.copyWith(
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
                                'E-posta doğrulanmadı',
                                style: TextStyle(
                                  color: CupertinoColors.black,
                                  fontSize: 13,
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

        // Ayarlar Başlığı
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: context.dimensions.paddingL,
              right: context.dimensions.paddingL,
              top: context.dimensions.paddingM,
              bottom: context.dimensions.paddingS,
            ),
            child: Text(
              'Ayarlar',
              style: AppTextTheme.headline5.copyWith(
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
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
                  header: 'Hesap Doğrulama',
                  items: [
                    _buildSettingsItem(
                      icon: CupertinoIcons.mail_solid,
                      iconColor: CupertinoColors.systemIndigo,
                      title: 'E-posta Doğrulama',
                      subtitle:
                          'E-posta adresini doğrula ve daha fazla özelliğe eriş',
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'Gönder',
                          style: TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.read<ProfileCubit>().sendEmailVerification();
                          _showVerificationDialog(context);
                        },
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showVerificationDialog(context);
                      },
                    ),
                  ],
                ),

              // Satın Alma Ayarları
              _buildSettingsGroup(
                header: 'Abonelik ve Satın Alma',
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.star_circle_fill,
                    iconColor: CupertinoColors.systemYellow,
                    title: user.isPremium
                        ? 'Premium Üyelik'
                        : 'Premium\'a Yükselt',
                    subtitle: user.isPremium
                        ? 'Premium aboneliğin aktif'
                        : 'Sınırsız analiz ve daha fazla özellik',
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
                              'Aktif',
                              style: TextStyle(
                                color: CupertinoColors.systemGreen,
                                fontSize: 12,
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
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const PremiumScreen(),
                              ),
                            );
                          },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.creditcard_fill,
                    iconColor: CupertinoColors.systemTeal,
                    title: 'Kredi Satın Al',
                    subtitle: user.isPremium
                        ? 'Premium üyelikle sınırsız analiz yapabilirsin'
                        : 'Tek seferlik analiz kredileri al',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // TODO: Kredi satın alma ekranı
                    },
                  ),
                ],
              ),

              // Uygulama Ayarları
              _buildSettingsGroup(
                header: 'Uygulama',
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.question_circle_fill,
                    iconColor: CupertinoColors.systemBlue,
                    title: 'Yardım ve Destek',
                    subtitle: 'Sorular, geri bildirim ve destek',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // TODO: Yardım ekranı
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.info_circle_fill,
                    iconColor: CupertinoColors.systemGrey,
                    title: 'Hakkında',
                    subtitle: 'Uygulama bilgileri ve lisanslar',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // TODO: Hakkında ekranı
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.delete,
                    iconColor: CupertinoColors.systemRed,
                    title: 'Hesabı Sil',
                    subtitle: 'Hesabını ve tüm verilerini kalıcı olarak sil',
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
                        'Çıkış Yap',
                        style: TextStyle(
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
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
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
        horizontal: context.dimensions.paddingL,
        vertical: context.dimensions.paddingL,
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
        borderRadius: BorderRadius.circular(20),
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
                    width: 46,
                    height: 46,
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
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: context.dimensions.spaceM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.isPremium ? 'Premium Üye' : 'Standart Üye',
                        style: AppTextTheme.headline6.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        user.isPremium
                            ? 'Sınırsız analiz hakkınız var'
                            : 'Sınırlı erişim',
                        style: AppTextTheme.caption.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
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
                    horizontal: context.dimensions.paddingS,
                    vertical: 7,
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
                    borderRadius: BorderRadius.circular(14),
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
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: context.dimensions.spaceL),

          // Kalan analiz bilgisi - Daha görsel ve modern
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    color: Colors.white.withOpacity(0.9),
                    size: 15,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Kalan Analiz',
                    style: AppTextTheme.bodyText2.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Haptic feedback ve yenileme
                  HapticFeedback.lightImpact();
                  context.read<ProfileCubit>().refreshUserData();
                },
                child: Row(
                  children: [
                    user.isPremium
                        ? Icon(
                            CupertinoIcons.infinite,
                            color: highlightColor,
                            size: 20,
                          )
                        : Text(
                            '${user.analysisCredits}',
                            style: AppTextTheme.headline5.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    if (!user.isPremium) SizedBox(width: 6),
                    if (!user.isPremium)
                      Icon(
                        CupertinoIcons.refresh_thin,
                        color: Colors.white.withOpacity(0.7),
                        size: 15,
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: context.dimensions.spaceM),

          // İlerleme çubuğu - Modern tasarım
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
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
                      height: 8,
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SizedBox(height: context.dimensions.spaceL),

          // Premium olmayan kullanıcılar için yükseltme butonu - Modern iOS 17 stili
          if (!user.isPremium)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const PremiumScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 14,
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
                  borderRadius: BorderRadius.circular(14),
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
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Premium\'a Yükselt',
                      style: TextStyle(
                        color: const Color(0xFF0A8D48),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
        title: const Text('Çıkış Yap'),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().signOut();
              context.goNamed(RouteNames.login);
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.mail,
              color: CupertinoColors.activeBlue,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('Doğrulama E-postası'),
          ],
        ),
        content: Column(
          children: [
            SizedBox(height: 8),
            Text(
              'E-posta adresinize bir doğrulama bağlantısı gönderdik.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Lütfen e-postanızı kontrol edin ve bağlantıya tıklayarak hesabınızı doğrulayın.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info,
                    color: CupertinoColors.systemGrey,
                    size: 14,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Doğrulama durumunuz otomatik olarak kontrol edilecektir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().refreshEmailVerificationStatus();
            },
            child: const Text('Durumu Kontrol Et'),
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
            Text('Hesabı Sil'),
          ],
        ),
        content: Column(
          children: [
            SizedBox(height: 12),
            Text(
              'Hesabınızı silmek üzeresiniz. Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinecektir.',
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
                    'Silinecek veriler:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Tüm kullanıcı bilgileriniz\n• Analiz geçmişiniz\n• Satın alınan krediler ve abonelikler',
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
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().deleteAccount();
            },
            child: const Text('Hesabı Sil'),
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
          title: const Text('Profil Fotoğrafı'),
          message:
              const Text('Profil fotoğrafınızı nereden seçmek istersiniz?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
              child: const Text('Kamera'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
              child: const Text('Galeri'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
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

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024, // Daha yüksek çözünürlük sağlayalım
        maxHeight: 1024,
        imageQuality: 90, // Kaliteyi artıralım
      );

      if (image != null) {
        final File imageFile = File(image.path);

        // Dosya boyutu kontrolü (5MB sınırı)
        final fileSize = await imageFile.length();
        AppLogger.i(
            'Seçilen resim: ${image.path}, boyut: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        // 5MB'dan büyükse kullanıcıya hata mesajı gösterelim
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            _showSnackBar(context,
                'Seçilen fotoğraf çok büyük (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB). Lütfen 5MB\'dan küçük bir fotoğraf seçin.');
          }
          return;
        }

        setState(() {
          _selectedProfileImage = File(image.path);
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
            _showSnackBar(context, 'Profil fotoğrafınız başarıyla güncellendi');
          }
        } catch (e) {
          AppLogger.e('Profil fotoğrafı yükleme hatası', e.toString());
          if (mounted) {
            String errorMsg = 'Fotoğraf yüklenirken bir hata oluştu';

            // Hata mesajını kullanıcı dostu hale getirelim
            if (e.toString().contains('storage/unauthorized')) {
              errorMsg =
                  'Yetki hatası: Lütfen tekrar giriş yapın ve tekrar deneyin';
            } else if (e.toString().contains('storage/quota-exceeded')) {
              errorMsg =
                  'Depolama alanı doldu. Lütfen daha sonra tekrar deneyin';
            } else if (e.toString().contains('storage/retry-limit-exceeded')) {
              errorMsg =
                  'Bağlantı hatası: Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin';
            } else if (e.toString().contains('dosya bulunamadı')) {
              errorMsg = 'Seçilen dosya artık mevcut değil veya erişilemiyor';
            } else if (e.toString().contains('dosya boyutu çok büyük')) {
              errorMsg =
                  'Dosya boyutu 5MB sınırını aşıyor, lütfen daha küçük bir fotoğraf seçin';
            }

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
      } else {
        AppLogger.i('Görüntü seçimi iptal edildi');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      context.read<ProfileCubit>().setImageUploading(false);

      // Çeşitli hata tiplerini ele alalım
      String errorMessage = 'Profil fotoğrafı seçme hatası: ${e.toString()}';
      AppLogger.e(errorMessage, e.toString());

      if (mounted) {
        if (e is PlatformException) {
          switch (e.code) {
            case 'photo_access_denied':
            case 'camera_access_denied':
              _showSnackBar(context,
                  'Erişim izni verilmedi. Lütfen uygulama ayarlarından izinleri kontrol edin.');
              break;
            case 'camera_not_available':
              _showSnackBar(context, 'Kamera şu anda kullanılamıyor.');
              break;
            default:
              _showSnackBar(
                  context, 'Fotoğraf seçilirken bir hata oluştu: ${e.message}');
          }
        } else {
          _showSnackBar(
              context, 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
        }
      }
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

      // Firebase Storage'a profil fotoğrafını yükle
      final storageRef = FirebaseStorage.instance.ref();

      // Storage kurallarına göre yol belirleme (userId/'profile.jpg' şeklinde)
      final profileImageRef =
          storageRef.child('profile_images/$userId/profile.jpg');

      AppLogger.i(
          'Storage referansı oluşturuldu: profile_images/$userId/profile.jpg');

      try {
        // İmajı sıkıştır
        AppLogger.i('Görüntü sıkıştırma başlıyor');
        final Uint8List? compressedImage =
            await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: 85,
          minWidth: 500,
          minHeight: 500,
        );

        if (compressedImage == null) {
          AppLogger.w('Sıkıştırma başarısız, orijinal görüntü kullanılacak');
          // Sıkıştırma başarısız olursa orijinal dosyayı kullan
          final originalBytes = await imageFile.readAsBytes();

          // Storage'a yükle
          AppLogger.i(
              'Orijinal görüntü yükleniyor: ${originalBytes.length} bytes');
          final uploadTask = profileImageRef.putData(
            originalBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          // İlerleme izleme
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            AppLogger.i(
                'Yükleme ilerlemesi: ${(progress * 100).toStringAsFixed(2)}%');
          }, onError: (e) {
            AppLogger.e('Yükleme takibi sırasında hata', e.toString());
          });

          // Yükleme tamamlanana kadar bekle
          final TaskSnapshot taskSnapshot = await uploadTask;
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();

          AppLogger.i('Profil fotoğrafı başarıyla yüklendi: $downloadUrl');
          return downloadUrl;
        } else {
          // Sıkıştırılmış görüntüyü kullan
          AppLogger.i(
              'Sıkıştırılmış görüntü yükleniyor: ${compressedImage.length} bytes');

          // Storage'a yükle
          final uploadTask = profileImageRef.putData(
            compressedImage,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          // İlerleme izleme
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            AppLogger.i(
                'Yükleme ilerlemesi: ${(progress * 100).toStringAsFixed(2)}%');
          }, onError: (e) {
            AppLogger.e('Yükleme takibi sırasında hata', e.toString());
          });

          // Yükleme tamamlanana kadar bekle
          final TaskSnapshot taskSnapshot = await uploadTask;
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();

          AppLogger.i('Profil fotoğrafı başarıyla yüklendi: $downloadUrl');
          return downloadUrl;
        }
      } catch (storageError) {
        AppLogger.e(
            'Firebase Storage işlemi sırasında hata', storageError.toString());

        // Hata tipine göre özel mesajlar
        if (storageError is FirebaseException) {
          switch (storageError.code) {
            case 'storage/unauthorized':
              throw Exception('Yetki hatası: Storage erişimi reddedildi');
            case 'storage/canceled':
              throw Exception('Yükleme iptal edildi');
            case 'storage/quota-exceeded':
              throw Exception('Storage kotası aşıldı');
            case 'storage/invalid-checksum':
              throw Exception(
                  'Dosya bozuk veya transfer sırasında veri kaybı oldu');
            case 'storage/retry-limit-exceeded':
              throw Exception(
                  'Yükleme denemesi sınırı aşıldı, lütfen daha sonra tekrar deneyin');
            case 'storage/object-not-found':
              throw Exception('Yüklenen dosya bulunamadı');
            default:
              throw Exception('Firebase Storage hatası: ${storageError.code}');
          }
        } else {
          throw Exception(
              'Dosya yükleme işlemi başarısız: ${storageError.toString()}');
        }
      }
    } catch (e) {
      AppLogger.e('Profil fotoğrafı yükleme hatası (detay)', e.toString());
      throw Exception('⛔ Profil fotoğrafı yükleme hatası: ${e.toString()}');
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
                message.contains('başarı')
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.info_circle_fill,
                color: message.contains('başarı')
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
}
