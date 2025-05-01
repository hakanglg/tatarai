import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:sprung/sprung.dart';

/// Kullanıcı kayıt ekranı
class RegisterScreen extends StatefulWidget {
  /// Constructor
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    // Responsive değerler için dimensions
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
          AppLogger.i('Kayıt yükleniyor durumu: ${state.isLoading}');
        }

        if (state.isAuthenticated) {
          // Başarılı kayıt - hata mesajını temizle ve ana sayfaya yönlendir
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
          } else if (state.errorMessage!.contains('email-already-in-use')) {
            _showErrorDialog(
              context,
              'Bu e-posta adresi zaten kullanılıyor. Farklı bir e-posta adresi deneyin veya giriş yapın.',
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
                          children: [
                            // Başlık ve geri butonu
                            Row(
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      context.goNamed(RouteNames.login),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.back,
                                        color: AppColors.primary,
                                        size: dim.iconSizeS,
                                      ),
                                      SizedBox(width: dim.spaceXXS),
                                      Text(
                                        'Giriş',
                                        style: TextStyle(
                                          fontFamily: 'sfpro',
                                          fontSize: dim.fontSizeS,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: dim.spaceL),

                            // Başlık ve açıklama
                            Text(
                              'Hesap Oluştur',
                              style: TextStyle(
                                fontFamily: 'sfpro',
                                fontSize: dim.fontSizeXL,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.label,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: dim.spaceS),
                            Text(
                              'TatarAI yapay zeka tarım asistanını kullanmak için hesap oluşturun',
                              style: TextStyle(
                                fontFamily: 'sfpro',
                                fontSize: dim.fontSizeS,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                            SizedBox(height: dim.spaceXL),

                            // Form alanları
                            _buildInputField(
                              controller: _displayNameController,
                              placeholder: 'Ad Soyad',
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              icon: CupertinoIcons.person,
                              dim: dim,
                            ),
                            SizedBox(height: dim.spaceM),

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
                            SizedBox(height: dim.spaceM),

                            _buildInputField(
                              controller: _confirmPasswordController,
                              placeholder: 'Şifre Tekrar',
                              obscureText: _obscureConfirmPassword,
                              icon: CupertinoIcons.lock,
                              dim: dim,
                              suffix: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                child: Icon(
                                  _obscureConfirmPassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: CupertinoColors.systemGrey,
                                  size: dim.iconSizeS,
                                ),
                              ),
                            ),
                            SizedBox(height: dim.spaceM),

                            // Kullanım koşulları onay
                            Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGreen
                                    .withOpacity(0.4),
                                borderRadius:
                                    BorderRadius.circular(dim.radiusM),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: dim.paddingS,
                                vertical: dim.paddingS,
                              ),
                              child: Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: CupertinoSwitch(
                                      value: _acceptTerms,
                                      onChanged: (value) {
                                        setState(() {
                                          _acceptTerms = value;
                                        });
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: dim.spaceXS),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _acceptTerms = !_acceptTerms;
                                        });
                                      },
                                      child: Text(
                                        'Kullanım koşullarını ve gizlilik politikasını kabul ediyorum',
                                        style: TextStyle(
                                          fontFamily: 'sfpro',
                                          fontSize: dim.fontSizeS,
                                          color: CupertinoColors.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: dim.spaceXL),

                            // Kayıt ol butonu
                            _buildAuthButton(
                              text: 'Kayıt Ol',
                              isLoading: state.isLoading || _isSubmitting,
                              onPressed: (state.isLoading || _isSubmitting)
                                  ? null
                                  : _signUp,
                              icon: CupertinoIcons.person_add,
                              dim: dim,
                            ),

                            SizedBox(height: dim.spaceXL),

                            // Giriş yönlendirmesi
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Zaten bir hesabınız var mı?',
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
                                          context.goNamed(RouteNames.login);
                                        },
                                  child: Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontFamily: 'sfpro',
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
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

  /// Daha güzel input alan widget'ı oluşturur
  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required AppDimensions dim,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
        textCapitalization: textCapitalization,
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
        ],
      ),
    );
  }
}
