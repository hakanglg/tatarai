import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:sprung/sprung.dart';

part 'register_screen_mixin.dart';

/// Kullanıcı kayıt ekranı
class RegisterScreen extends StatefulWidget {
  /// Constructor
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin, _RegisterScreenMixin {
  // Hata mesajlarının tekrarını önlemek için son gösterilen hata
  String? _lastShownError;

  @override
  void dispose() {
    // Son hata referansını temizle
    _lastShownError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive değerler için dimensions
    final dim = context.dimensions;

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) {
        // Sadece hata mesajı değiştiğinde ya da yeni bir hata eklendiğinde dinle
        return (previous.errorMessage != current.errorMessage &&
                current.errorMessage != null) ||
            previous.isAuthenticated != current.isAuthenticated;
      },
      listener: (context, state) {
        // Widget kaldırıldı mı kontrolü
        if (!mounted) return;

        // Form durumunu güncelle
        if (_isSubmitting && !state.isLoading) {
          setState(() {
            _isSubmitting = false;
          });
        }

        if (state.isLoading) {
          // Loading ekranı gösterme
          AppLogger.i('Kayıt yükleniyor durumu: ${state.isLoading}');
        }

        if (state.isAuthenticated) {
          // Başarılı kayıt - hata mesajını temizle ve ana sayfaya yönlendir
          context.read<AuthCubit>().clearErrorMessage();
          context.goNamed(RouteNames.home);
        } else if (state.errorMessage != null &&
            !state.isLoading &&
            state.errorMessage != _lastShownError) {
          // Hata durumu - yükleme tamamlandıysa, hata varsa ve daha önce gösterilmediyse göster

          // Son gösterilen hatayı kaydet ve göster
          _lastShownError = state.errorMessage;
          _showErrorDialog(context, state.errorMessage!);

          // Hata mesajını gösterdikten sonra temizle - ancak widget hala mounted ise
          if (mounted) {
            // Context'i güvenli şekilde kullanmak için yerel bir referans alıyoruz
            final cubit = context.read<AuthCubit>();

            Future.delayed(Duration.zero, () {
              if (mounted) {
                cubit.clearErrorMessage();

                // Bir süre sonra son hata referansını temizle
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _lastShownError = null;
                    });
                  }
                });
              }
            });
          }
        }
      },
      child: Scaffold(
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
                                        style: AppTextTheme.captionL.copyWith(
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
                              style: AppTextTheme.headline3,
                            ),
                            SizedBox(height: dim.spaceS),
                            Text(
                              'TatarAI yapay zeka tarım asistanını kullanmak için hesap oluşturun',
                              style: AppTextTheme.captionL.copyWith(
                                color: AppColors.textSecondary,
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
                                  color: AppColors.textSecondary,
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
                                  color: AppColors.textSecondary,
                                  size: dim.iconSizeS,
                                ),
                              ),
                            ),
                            SizedBox(height: dim.spaceM),

                            // Kullanım koşulları onay
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.4),
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
                                        style: AppTextTheme.captionL.copyWith(
                                          color: AppColors.textSecondary,
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
                                  style: AppTextTheme.captionL.copyWith(
                                    color: AppColors.textSecondary,
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
                                    style: AppTextTheme.captionL.copyWith(
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
        style: AppTextTheme.body,
        placeholderStyle: AppTextTheme.body.copyWith(
          color: AppColors.textSecondary.withOpacity(0.7),
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
            splashColor: AppColors.white.withOpacity(0.1),
            highlightColor: AppColors.white.withOpacity(0.05),
            child: Center(
              child: isLoading
                  ? const CupertinoActivityIndicator(color: AppColors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          text,
                          style: AppTextTheme.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: dim.spaceXS),
                        Icon(
                          icon,
                          color: AppColors.white,
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
}
