part of 'register_screen.dart';

mixin _RegisterScreenMixin on State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isSubmitting = false;

  // Animasyon için controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon controller'ı başlat
    _animationController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 1000),
    );

    // Animasyonları tanımla
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Sprung.custom(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Sprung.custom(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      ),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Sprung.custom(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      ),
    ));

    // Animasyonu başlat
    _animationController.forward();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Kayıt ol butonuna tıklandığında çalışır
  void _signUp() {
    if (_formKey.currentState?.validate() ?? false) {
      // Klavyeyi kapat
      FocusScope.of(context).unfocus();

      if (!_acceptTerms) {
        _showErrorDialog(
          context,
          'Kayıt olmak için kullanım koşullarını kabul etmelisiniz.',
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorDialog(context, 'Şifreler eşleşmiyor.');
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      context.read<AuthCubit>().signUpWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            displayName: _displayNameController.text.trim(),
          );
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
        ],
      ),
    );
  }
}
