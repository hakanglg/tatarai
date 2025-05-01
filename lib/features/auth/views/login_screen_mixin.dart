part of 'login_screen.dart';

/// LoginScreen için mixin sınıfı
mixin _LoginScreenMixin on State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  // Animasyon kontrolcüleri
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  /// Normal e-posta/şifre giriş metodunu çağırır
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    context.read<AuthCubit>().signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
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
              color: CupertinoColors.systemRed,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
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
              child: const Text('Tekrar Dene'),
            ),
        ],
      ),
    );
  }

  // Password reset dialog
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
                  Text('Şifre Sıfırlama'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Şifre sıfırlama bağlantısı gönderilecek e-posta adresinizi giriniz:',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: CupertinoTextField(
                      controller: emailController,
                      placeholder: 'E-posta',
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
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('İptal'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Gönder'),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() {
                        errorText = 'E-posta adresini giriniz';
                      });
                      return;
                    }

                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(email)) {
                      setState(() {
                        errorText = 'Geçerli bir e-posta adresi giriniz';
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
                            : 'Şifre sıfırlama işlemi sırasında bir hata oluştu.';
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
            Text('Bağlantı Gönderildi'),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. '
            'Lütfen e-postanızı kontrol edin ve bağlantıya tıklayarak şifrenizi sıfırlayın.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Tamam'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
