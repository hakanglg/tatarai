part of 'login_screen.dart';

/// LoginScreen için mixin sınıfı
mixin _LoginScreenMixin on State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _rememberMe = false;

  // Animasyon kontrolcüleri
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // SharedPreferences anahtarı
  static const String _rememberedEmailKey = 'remembered_email';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRememberedEmail(); // E-posta otomatik doldurulsun
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Tüm animasyonları ayarlar
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  /// SharedPreferences'tan e-posta adresini yükler ve input'a yazar
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString(_rememberedEmailKey);
    AppLogger.i('[Beni Hatırla] Yüklendi: $rememberedEmail');
    if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = rememberedEmail;
        _rememberMe = true;
      });
      AppLogger.i('[Beni Hatırla] E-posta inputa yazıldı ve toggle açıldı');
    }
  }

  /// E-posta adresini SharedPreferences'a kaydeder
  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
    AppLogger.i('[Beni Hatırla] Kaydedildi: $email');
  }

  /// SharedPreferences'tan e-posta adresini siler
  Future<void> _clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
    AppLogger.i('[Beni Hatırla] E-posta silindi');
  }

  /// Normal e-posta/şifre giriş metodunu çağırır
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Beni hatırla seçiliyse e-posta kaydet, değilse sil
    if (_rememberMe) {
      await _saveRememberedEmail(_emailController.text.trim());
    } else {
      await _clearRememberedEmail();
    }
    AppLogger.i(
        '[Beni Hatırla] Girişte işlem tamamlandı. rememberMe: $_rememberMe, email: ${_emailController.text.trim()}');

    context.read<AuthCubit>().signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  /// Apple ile giriş yapar
  Future<void> _signInWithApple() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<AuthCubit>().signInWithApple();
    } catch (e) {
      // Hata işleme AuthCubit içinde yapılıyor, error state'e düşecek
      AppLogger.e('Apple ile giriş sırasında hata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Google ile giriş yapar
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<AuthCubit>().signInWithGoogle();
    } catch (e) {
      // Hata işleme AuthCubit içinde yapılıyor, error state'e düşecek
      AppLogger.e('Google ile giriş sırasında hata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Hata mesajlarını gösterir
  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: AppColors.error,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Hata',
              style: AppTextTheme.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            message,
            style: AppTextTheme.captionL,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tamam',
              style: AppTextTheme.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Eğer internet bağlantısı hatası ise yeniden deneme butonu ekle
          if (message.contains('internet') ||
              message.contains('bağlantı') ||
              message.contains('Veritabanı') ||
              message.contains('kurulamadı'))
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                _signIn(); // Yeniden dene
              },
              isDefaultAction: true,
              child: Text(
                'Tekrar Dene',
                style: AppTextTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Password reset dialog
  Future<void> _showResetPasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController emailController = TextEditingController();
    String? errorText;

    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.mail,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'password_reset'.locale(context),
                    style: AppTextTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'password_reset_desc'.locale(context),
                    style: AppTextTheme.captionL,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: CupertinoTextField(
                      controller: emailController,
                      placeholder: 'email'.locale(context),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: AppTextTheme.body,
                      placeholderStyle: AppTextTheme.body.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: AppTextTheme.smallCaption.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: Text(
                    'cancel'.locale(context),
                    style: AppTextTheme.body,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: Text(
                    'send'.locale(context),
                    style: AppTextTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() {
                        errorText = 'enter_email'.locale(context);
                      });
                      return;
                    }

                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(email)) {
                      setState(() {
                        errorText = 'enter_valid_email'.locale(context);
                      });
                      return;
                    }

                    try {
                      await context.read<AuthCubit>().sendPasswordResetEmail(
                            email,
                          );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        _showPasswordResetSuccessDialog(context);
                      }
                    } catch (e) {
                      setState(() {
                        errorText = e is FirebaseAuthException
                            ? context.read<AuthCubit>().getErrorMessage(e)
                            : 'password_reset_error'.locale(context);
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show password reset success dialog
  void _showPasswordResetSuccessDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('connection_sent'.locale(context)),
          ],
        ),
        content: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'password_reset_link_sent'.locale(context),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('ok'.locale(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Hesap silindi dialogunu gösterir
  void _showAccountDeletedDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              "Hesap Silindi",
              style: AppTextTheme.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Hesabınız ve tüm verileriniz başarıyla silindi.",
            style: AppTextTheme.captionL,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text("Tamam"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Beni hatırla toggle'ı değiştiğinde e-posta kaydını yönet
  void onRememberMeChanged(bool value) async {
    AppLogger.i('[Beni Hatırla] Toggle değişti: $value');
    setState(() {
      _rememberMe = value;
    });
    if (!value) {
      await _clearRememberedEmail();
    }
  }
}
