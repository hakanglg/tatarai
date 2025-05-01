import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:sprung/sprung.dart';

/// Kullanıcı giriş ekranı
class LoginScreen extends StatefulWidget {
  /// Constructor
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
      vsync: this,
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
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Giriş yap butonuna tıklandığında çalışır
  void _signIn() {
    if (_formKey.currentState?.validate() ?? false) {
      // Klavyeyi kapat
      FocusScope.of(context).unfocus();

      setState(() {
        _isSubmitting = true;
      });

      context.read<AuthCubit>().signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive değerler için dimensions sınıfına erişim
    final dim = context.dimensions;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Form durumunu güncelle
        if (_isSubmitting && !state.isLoading) {
          setState(() {
            _isSubmitting = false;
          });
        }

        // Loading durumunu gizle (isLoading durum güncellemesi olduğunda)
        if (state.isLoading) {
          // Loading ekranı gösterme
          AppLogger.i('Giriş yükleniyor durumu: ${state.isLoading}');
        }

        if (state.isAuthenticated) {
          // Başarılı giriş - hata mesajını temizle ve ana sayfaya yönlendir
          context.read<AuthCubit>().clearErrorMessage();
          context.goNamed(RouteNames.home);
        } else if (state.errorMessage != null && !state.isLoading) {
          // Hata durumu - yükleme tamamlandıysa ve hata varsa göster
          if (state.errorMessage!.contains('unavailable')) {
            // Bağlantı hatası durumunda özel mesaj göster
            _showErrorDialog(
              context,
              'Sunucuya bağlanırken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
            );
          } else if (state.errorMessage!.contains('timeout') ||
              state.errorMessage!.contains('zaman aşımı')) {
            _showErrorDialog(
              context,
              'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
            );
          } else {
            _showErrorDialog(context, state.errorMessage!);
          }

          // Hata mesajını gösterdikten sonra temizle
          Future.delayed(Duration.zero, () {
            context.read<AuthCubit>().clearErrorMessage();
          });
        }
      },
      child: Scaffold(
        backgroundColor: CupertinoColors.systemBackground,
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dim.paddingL,
                  vertical: dim.paddingL,
                ),
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Üst kısım (logo ve başlık)
                            Column(
                              children: [
                                SizedBox(height: dim.spaceXL),
                                _buildLogo(dim),
                                SizedBox(height: dim.spaceXL),
                                Text(
                                  'Hesabınıza Giriş Yapın',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'sfpro',
                                    fontSize: dim.fontSizeL,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: dim.spaceS),
                                Text(
                                  'Tarımsal analiz ve öneriler için yapay zeka asistanınıza hoş geldiniz',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'sfpro',
                                    fontSize: dim.fontSizeS,
                                    color: CupertinoColors.secondaryLabel,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),

                            // Orta kısım (form alanları)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildInputField(
                                  controller: _emailController,
                                  placeholder: 'E-posta',
                                  keyboardType: TextInputType.emailAddress,
                                  icon: CupertinoIcons.mail,
                                  dim: dim,
                                ),
                                SizedBox(height: dim.spaceM),
                                _buildInputField(
                                  controller: _passwordController,
                                  placeholder: 'Şifre',
                                  obscureText: _obscurePassword,
                                  icon: CupertinoIcons.lock,
                                  dim: dim,
                                  suffix: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    child: Icon(
                                      _obscurePassword
                                          ? CupertinoIcons.eye
                                          : CupertinoIcons.eye_slash,
                                      color: CupertinoColors.systemGrey,
                                      size: dim.iconSizeS,
                                    ),
                                  ),
                                ),
                                SizedBox(height: dim.spaceXS),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _showResetPasswordDialog(context);
                                    },
                                    child: Text(
                                      'Şifremi Unuttum',
                                      style: TextStyle(
                                        fontFamily: 'sfpro',
                                        fontSize: dim.fontSizeS,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: dim.spaceXL),
                                _buildAuthButton(
                                  text: 'Giriş Yap',
                                  isLoading: state.isLoading || _isSubmitting,
                                  onPressed: (state.isLoading || _isSubmitting)
                                      ? null
                                      : _signIn,
                                  icon: CupertinoIcons.arrow_right,
                                  dim: dim,
                                ),
                              ],
                            ),

                            // Alt kısım (kayıt ol seçeneği)
                            Column(
                              children: [
                                SizedBox(height: dim.spaceXL),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Hesabınız yok mu?',
                                      style: TextStyle(
                                        fontFamily: 'sfpro',
                                        fontSize: dim.fontSizeS,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                    SizedBox(width: dim.spaceXS),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: state.isLoading
                                          ? null
                                          : () {
                                              context
                                                  .goNamed(RouteNames.register);
                                            },
                                      child: Text(
                                        'Kayıt Ol',
                                        style: TextStyle(
                                          fontFamily: 'sfpro',
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: dim.spaceM),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Logo widget'ı
  Widget _buildLogo(AppDimensions dim) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(dim.radiusL),
          ),
          padding: EdgeInsets.all(dim.paddingM),
          child: Icon(
            CupertinoIcons.leaf_arrow_circlepath,
            size: dim.iconSizeXL,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: dim.spaceM),
        Text(
          'TatarAI',
          style: TextStyle(
            fontFamily: 'sfpro',
            fontSize: dim.fontSizeXXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }

  /// Daha güzel input alan widget'ı oluşturur
  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required AppDimensions dim,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill,
        borderRadius: BorderRadius.circular(dim.radiusL),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        obscureText: obscureText,
        prefix: Padding(
          padding: EdgeInsets.only(left: dim.paddingM),
          child: Icon(
            icon,
            color: AppColors.primary.withOpacity(0.7),
            size: dim.iconSizeM,
          ),
        ),
        suffix: suffix != null
            ? Padding(
                padding: EdgeInsets.only(right: dim.paddingS),
                child: suffix,
              )
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: dim.paddingM,
          vertical: dim.paddingM,
        ),
        decoration: const BoxDecoration(
          border: null,
        ),
        style: TextStyle(
          fontFamily: 'sfpro',
          fontSize: dim.fontSizeM,
          color: CupertinoColors.label,
        ),
        placeholderStyle: TextStyle(
          fontFamily: 'sfpro',
          fontSize: dim.fontSizeM,
          color: CupertinoColors.placeholderText,
        ),
      ),
    );
  }

  /// Özel Auth button widget'ı oluşturur
  Widget _buildAuthButton({
    required String text,
    required bool isLoading,
    required VoidCallback? onPressed,
    required IconData icon,
    required AppDimensions dim,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Sprung.custom(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      ),
      height: dim.buttonHeight * 1.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dim.radiusL),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dim.radiusL),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashColor: CupertinoColors.white.withOpacity(0.1),
            highlightColor: CupertinoColors.white.withOpacity(0.05),
            child: Center(
              child: isLoading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: dim.fontSizeM,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: dim.spaceXS),
                        Icon(
                          icon,
                          color: CupertinoColors.white,
                          size: dim.iconSizeS,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
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
