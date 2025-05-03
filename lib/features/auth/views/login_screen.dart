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
import 'package:flutter_signin_button/flutter_signin_button.dart';

part 'login_screen_mixin.dart';

/// Kullanıcı giriş ekranı
class LoginScreen extends StatefulWidget {
  /// Constructor
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, _LoginScreenMixin {
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
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dim.paddingL,
                  vertical: dim.paddingS,
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Üst kısım (logo ve başlık)
                            Column(
                              children: [
                                SizedBox(height: dim.spaceS),
                                // Logo ve app ismi yan yana
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(dim.radiusM),
                                      ),
                                      padding: EdgeInsets.all(dim.paddingS),
                                      child: Icon(
                                        CupertinoIcons.leaf_arrow_circlepath,
                                        size: dim.iconSizeL,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(width: dim.spaceS),
                                    Text(
                                      'TatarAI',
                                      style: TextStyle(
                                        fontFamily: 'sfpro',
                                        fontSize: dim.fontSizeXL,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: dim.spaceS),
                                Text(
                                  'Hesabınıza Giriş Yapın',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'sfpro',
                                    fontSize: dim.fontSizeM,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: dim.spaceXS),
                                Text(
                                  'Yapay zeka asistanınıza hoş geldiniz',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'sfpro',
                                    fontSize: dim.fontSizeXS,
                                    color: CupertinoColors.secondaryLabel,
                                    height: 1.0,
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
                                  context: context,
                                  isLoading: state.isLoading || _isSubmitting,
                                  onPressed: (state.isLoading || _isSubmitting)
                                      ? null
                                      : _signIn,
                                ),
                                SizedBox(height: dim.spaceS),
                                // VEYA Ayırıcı
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.onSecondary,
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: dim.spaceM),
                                      child: Text(
                                        'VEYA',
                                        style: TextStyle(
                                          fontFamily: 'sfpro',
                                          fontSize: dim.fontSizeXS,
                                          color: CupertinoColors.secondaryLabel,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.onSecondary,
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: dim.spaceS),
                                // Google ve Apple butonlarını yan yana yerleştirme
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: SignInButton(
                                        Buttons.GoogleDark,
                                        text: "Google",
                                        onPressed: _signInWithGoogle,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    SizedBox(width: dim.spaceXS),
                                    Expanded(
                                      child: SignInButton(
                                        Buttons.AppleDark,
                                        text: "Apple",
                                        onPressed: () {},
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Alt kısım (kayıt ol seçeneği)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hesabınız yok mu?',
                                  style: TextStyle(
                                    fontFamily: 'sfpro',
                                    fontSize: dim.fontSizeS,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                                AppButton(
                                  type: AppButtonType.text,
                                  text: 'Kayıt Ol',
                                  onPressed: state.isLoading
                                      ? null
                                      : () =>
                                          context.goNamed(RouteNames.register),
                                )
                              ],
                            ),
                            SizedBox(height: dim.spaceM),
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
    required BuildContext context,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return AppButton(
      text: 'Giriş Yap',
      isLoading: isLoading,
      onPressed: onPressed,
      isFullWidth: true,
    );
  }
}
