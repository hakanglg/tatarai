import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircleAvatar;
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
import 'package:tatarai/features/auth/models/auth_state.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';

/// Kullanıcı profil bilgilerini gösteren ve düzenleyen ekran
class ProfileScreen extends StatefulWidget {
  /// Constructor
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedProfileImage;
  bool _isUploading = false;

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
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedProfileImage = File(image.path);
          _isUploading = true;
        });

        try {
          // Resmi Firebase Storage'a yükle
          final String imageUrl =
              await _uploadProfileImage(_selectedProfileImage!);

          // Kullanıcı profilini güncelle
          await context.read<AuthCubit>().updateProfile(photoURL: imageUrl);

          // Başarılı mesajı göster
          if (mounted) {
            _showSnackBar(context, 'Profil fotoğrafınız başarıyla güncellendi');
          }
        } catch (e) {
          AppLogger.e('Profil fotoğrafı yükleme hatası', e);
          if (mounted) {
            _showSnackBar(context,
                'Fotoğraf yüklenirken bir hata oluştu: ${e.toString()}');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      AppLogger.e('Profil fotoğrafı seçme hatası', e);
    }
  }

  /// Profil fotoğrafını Firebase Storage'a yükler
  Future<String> _uploadProfileImage(File imageFile) async {
    try {
      // Firebase Storage referansını al
      final userId = context.read<AuthCubit>().state.user?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      // Firebase Storage'da profil fotoğrafları için klasör oluştur
      final storageRef = FirebaseStorage.instance.ref();
      final profileImageRef = storageRef.child('profile_images/$userId.jpg');

      // İmajı sıkıştır
      final Uint8List compressedImage =
          await FlutterImageCompress.compressWithFile(
                imageFile.absolute.path,
                quality: 85,
                minWidth: 500,
                minHeight: 500,
              ) ??
              await imageFile.readAsBytes();

      // Storage'a yükle
      final uploadTask = profileImageRef.putData(
        compressedImage,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Yükleme tamamlanana kadar bekle
      final TaskSnapshot taskSnapshot = await uploadTask;

      // Yüklenen resmin URL'ini al
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      AppLogger.i('Profil fotoğrafı başarıyla yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      AppLogger.e('Profil fotoğrafı yükleme hatası (detay)', e);
      throw Exception('Profil fotoğrafı yüklenirken bir hata oluştu');
    }
  }

  /// Bildirim göster
  void _showSnackBar(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Bilgi'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.mediumImpact();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinecektir.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().deleteAccount();
            },
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profil'),
      ),
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
                    padding: EdgeInsets.all(context.dimensions.paddingL),
                    child: Column(
                      children: [
                        // Profil Fotoğrafı Bölümü
                        _buildProfilePhoto(user),

                        // Kullanıcı Bilgileri
                        SizedBox(height: context.dimensions.spaceL),
                        Text(
                          user.displayName ?? user.email.split('@')[0],
                          style: AppTextTheme.headline2,
                        ),
                        SizedBox(height: context.dimensions.spaceXS),
                        Text(user.email,
                            style: AppTextTheme.subtitle1.copyWith(
                              color: CupertinoColors.systemGrey,
                            )),

                        // Üyelik Bilgileri Kartı
                        SizedBox(height: context.dimensions.spaceL),
                        _buildMembershipCard(user),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingL,
                      vertical: context.dimensions.paddingM,
                    ),
                    child: Text(
                      'Hesap Ayarları',
                      style: AppTextTheme.headline5.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSettingsGroup(
                      items: [
                        if (!user.isEmailVerified) ...[
                          _buildSettingsItem(
                            title: 'E-posta Doğrulama',
                            icon: CupertinoIcons.mail_solid,
                            showTrailingIcon: false,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.dimensions.paddingXS,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                        context.dimensions.radiusXS),
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
                                  borderRadius: BorderRadius.circular(
                                      context.dimensions.radiusXS),
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
                              borderRadius: BorderRadius.circular(
                                  context.dimensions.radiusXS),
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
                      ],
                    ),
                    SizedBox(height: context.dimensions.spaceM),
                    _buildSettingsGroup(
                      header: 'Satın Alma',
                      items: [
                        _buildSettingsItem(
                          title: 'Premium\'a Yükselt',
                          subtitle: user.isPremium
                              ? 'Premium üyeliğiniz aktif'
                              : 'Sınırsız analiz ve özel özellikler',
                          icon: CupertinoIcons.star_circle_fill,
                          iconColor: CupertinoColors.systemYellow,
                          showTrailingIcon: !user.isPremium,
                          trailing: user.isPremium
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.dimensions.paddingXS,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGreen
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                        context.dimensions.radiusXS),
                                  ),
                                  child: const Text(
                                    'Aktif',
                                    style: TextStyle(
                                      color: CupertinoColors.systemGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: user.isPremium
                              ? () {}
                              : () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (context) =>
                                          const PremiumScreen(),
                                    ),
                                  );
                                },
                        ),
                        _buildSettingsItem(
                          title: 'Kredi Satın Al',
                          subtitle: 'Mevcut krediniz: ${user.analysisCredits}',
                          icon: CupertinoIcons.cart_fill,
                          iconColor: AppColors.secondary,
                          onTap: () {
                            // TODO: Kredi satın alma ekranına yönlendir
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: context.dimensions.spaceM),
                    _buildSettingsGroup(
                      header: 'Uygulama',
                      items: [
                        _buildSettingsItem(
                          title: 'Yardım',
                          subtitle: 'Sık sorulan sorular ve destek',
                          icon: CupertinoIcons.question_circle_fill,
                          iconColor: CupertinoColors.systemBlue,
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          title: 'Hakkında',
                          subtitle: 'Uygulama bilgileri ve sürüm',
                          icon: CupertinoIcons.info_circle_fill,
                          iconColor: CupertinoColors.systemGrey,
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          title: 'Hesabı Sil',
                          subtitle:
                              'Tüm verileriniz kalıcı olarak silinecektir',
                          icon: CupertinoIcons.delete,
                          iconColor: CupertinoColors.systemGrey,
                          onTap: _showDeleteAccountDialog,
                        ),
                      ],
                    ),
                    SizedBox(height: context.dimensions.spaceXL),

                    // Çıkış yap butonu
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.dimensions.paddingL),
                      child: AppButton(
                        type: AppButtonType.destructive,
                        text: 'Çıkış Yap',
                        isLoading: state.isLoading,
                        icon: CupertinoIcons.square_arrow_right,
                        onPressed: () => _showLogoutDialog(context),
                      ),
                    ),

                    SizedBox(height: context.dimensions.spaceXXL),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(user) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Profil fotoğrafı
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CupertinoColors.systemGrey5,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isUploading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : CircleAvatar(
                    radius: 48,
                    backgroundColor: CupertinoColors.systemGrey6,
                    backgroundImage: _selectedProfileImage != null
                        ? FileImage(_selectedProfileImage!)
                        : user.photoURL != null
                            ? NetworkImage(user.photoURL!) as ImageProvider
                            : null,
                    child:
                        user.photoURL == null && _selectedProfileImage == null
                            ? Icon(
                                CupertinoIcons.person_fill,
                                size: 60,
                                color: AppColors.primary.withOpacity(0.7),
                              )
                            : null,
                  ),
          ),

          // Değiştir butonu
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                CupertinoIcons.camera_fill,
                color: CupertinoColors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard(user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.dimensions.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: user.isPremium
              ? [AppColors.primary, AppColors.secondary]
              : [
                  const Color(0xFF4CAF50),
                  const Color(0xFF8BC34A),
                  const Color(0xFF7CB342),
                  const Color(0xFF43A047),
                ],
          stops: user.isPremium ? null : const [0.0, 0.4, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: user.isPremium
                ? AppColors.primary.withOpacity(0.3)
                : const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.isPremium ? 'Premium Üye' : 'Standart Üye',
                style: AppTextTheme.subtitle1.copyWith(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                user.isPremium
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.leaf_arrow_circlepath,
                color: CupertinoColors.white,
                size: 24,
              ),
            ],
          ),
          SizedBox(height: context.dimensions.spaceM),
          Text(
            'Kalan Analiz: ${user.analysisCredits}',
            style: AppTextTheme.bodyText1.copyWith(
              color: CupertinoColors.white,
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),
          if (!user.isPremium)
            CupertinoButton(
              padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.paddingM,
                vertical: context.dimensions.paddingXS,
              ),
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(context.dimensions.radiusM),
              minSize: 0,
              child: Text(
                'Premium\'a Yükselt',
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const PremiumScreen(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({String? header, required List<Widget> items}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.dimensions.paddingL),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey5.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: EdgeInsets.only(
                left: context.dimensions.paddingM,
                top: context.dimensions.paddingM,
                bottom: context.dimensions.paddingXS,
              ),
              child: Text(
                header,
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    String? subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
    bool showTrailingIcon = true,
    Widget? trailing,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.dimensions.paddingM,
          vertical: context.dimensions.paddingM,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.dimensions.paddingXS),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.dimensions.radiusS),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: context.dimensions.spaceXXS),
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
            if (showTrailingIcon)
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey,
                size: 18,
              ),
            if (trailing != null) trailing,
          ],
        ),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().signOut();
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

  void _showRefreshEmailDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
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
