part of 'profile_screen.dart';

/// LoginScreen için mixin sınıfı
mixin _ProfileScreenMixin on State<ProfileScreen> {
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
      vsync: this as TickerProvider,
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

      // Navigator'ın mevcut olduğundan emin ol
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Sonuç dialoglarını göster
      if (!mounted) return;

      if (isVerified) {
        _showSuccessDialog(context);
      } else {
        _showNotVerifiedDialog(context);
      }
    } catch (error) {
      // Hata durumunda
      if (!mounted) return;

      // Navigator'ın mevcut olduğundan emin ol
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Dialog'u kapat
      }

      if (!mounted) return;
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

        // Önce dialog'u kapat
        Navigator.of(context).pop();

        // Kısa bir gecikme ile kullanıcı verilerini yenile
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            // State'i yenile
            context.read<ProfileCubit>().refreshUserData();
          }
        });
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
      onConfirmPressed: () async {
        if (!mounted) return;

        // Önce mevcut dialog'u kapat
        Navigator.of(context).pop();

        // Kısa bir gecikme ekle
        await Future.delayed(Duration(milliseconds: 100));

        if (!mounted) return;

        // Yeni doğrulama e-postası gönder
        await context.read<ProfileCubit>().sendEmailVerification();

        if (!mounted) return;

        // E-posta gönderildi dialog'unu göster
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

        // Önce mevcut dialog'u kapat ve ardından durumu kontrol et
        // Bu sayede navigator stack'i düzgün bir şekilde yönetilir
        Navigator.of(context).pop();

        // Kısa bir gecikme ile yeni kontrolü başlat
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            _checkEmailVerification(context);
          }
        });
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

  /// Paywall'ı açar ve kullanıcı bilgilerini yeniler
  void _openPaywall() {
    HapticFeedback.mediumImpact();
    context.showPaywall(
      onComplete: (_) {
        // Paywall kapandıktan sonra kullanıcı bilgilerini yenile
        if (mounted) {
          context.read<ProfileCubit>().refreshUserData();
        }
      },
    );
  }
}
