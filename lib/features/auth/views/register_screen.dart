import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';

/// Kullanıcı kayıt ekranı
class RegisterScreen extends StatefulWidget {
  /// Constructor
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Kayıt ol butonuna tıklandığında çalışır
  void _signUp() {
    if (_formKey.currentState?.validate() ?? false) {
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
          } else {
            _showErrorDialog(context, state.errorMessage!);
          }

          // Hata mesajını gösterdikten sonra temizle
          Future.delayed(Duration.zero, () {
            context.read<AuthCubit>().clearErrorMessage();
          });
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Kayıt Ol'),
          leading: CupertinoNavigationBarBackButton(
            onPressed: () => context.goNamed(RouteNames.login),
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(dim.paddingM),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo veya uygulama adı
                      SizedBox(height: dim.spaceM),
                      Center(
                        child: Text(
                          'TatarAI',
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: dim.fontSizeXXL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: dim.spaceXS),
                      Center(
                        child: Text(
                          'Yeni Hesap Oluştur',
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: dim.fontSizeM,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                      SizedBox(height: dim.spaceXL),

                      // İsim alanı
                      CupertinoTextField(
                        controller: _displayNameController,
                        placeholder: 'Ad Soyad',
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        prefix: Padding(
                          padding: EdgeInsets.only(left: dim.paddingS),
                          child: Icon(
                            CupertinoIcons.person,
                            color: CupertinoColors.systemGrey,
                            size: dim.iconSizeS,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: dim.paddingM,
                          vertical: dim.paddingS,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                          ),
                          borderRadius: BorderRadius.circular(dim.radiusS),
                        ),
                      ),
                      SizedBox(height: dim.spaceM),

                      // Email alanı
                      CupertinoTextField(
                        controller: _emailController,
                        placeholder: 'E-posta',
                        keyboardType: TextInputType.emailAddress,
                        prefix: Padding(
                          padding: EdgeInsets.only(left: dim.paddingS),
                          child: Icon(
                            CupertinoIcons.mail,
                            color: CupertinoColors.systemGrey,
                            size: dim.iconSizeS,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: dim.paddingM,
                          vertical: dim.paddingS,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                          ),
                          borderRadius: BorderRadius.circular(dim.radiusS),
                        ),
                      ),
                      SizedBox(height: dim.spaceM),

                      // Şifre alanı
                      CupertinoTextField(
                        controller: _passwordController,
                        placeholder: 'Şifre',
                        obscureText: _obscurePassword,
                        prefix: Padding(
                          padding: EdgeInsets.only(left: dim.paddingS),
                          child: Icon(
                            CupertinoIcons.lock,
                            color: CupertinoColors.systemGrey,
                            size: dim.iconSizeS,
                          ),
                        ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: dim.paddingM,
                          vertical: dim.paddingS,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                          ),
                          borderRadius: BorderRadius.circular(dim.radiusS),
                        ),
                      ),
                      SizedBox(height: dim.spaceM),

                      // Şifre doğrulama alanı
                      CupertinoTextField(
                        controller: _confirmPasswordController,
                        placeholder: 'Şifre Tekrar',
                        obscureText: _obscureConfirmPassword,
                        prefix: Padding(
                          padding: EdgeInsets.only(left: dim.paddingS),
                          child: Icon(
                            CupertinoIcons.lock,
                            color: CupertinoColors.systemGrey,
                            size: dim.iconSizeS,
                          ),
                        ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: dim.paddingM,
                          vertical: dim.paddingS,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                          ),
                          borderRadius: BorderRadius.circular(dim.radiusS),
                        ),
                      ),
                      SizedBox(height: dim.spaceM),

                      // Kullanım koşulları
                      Row(
                        children: [
                          CupertinoSwitch(
                            value: _acceptTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptTerms = value;
                              });
                            },
                            activeTrackColor: AppColors.primary,
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
                                'Kullanım koşullarını ve gizlilik politikasını kabul ediyorum.',
                                style: TextStyle(
                                  fontFamily: 'sfpro',
                                  fontSize: dim.fontSizeS,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dim.spaceL),

                      // Kayıt ol butonu
                      AppButton(
                        text: 'Kayıt Ol',
                        isLoading: state.isLoading,
                        onPressed: () {
                          print('Kayıt Ol butonuna basıldı!');
                          _signUp();
                        },
                        height: dim.buttonHeight,
                      ),
                      SizedBox(height: dim.spaceL),
                      // Giriş ekranına dön
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Zaten bir hesabınız var mı?',
                            style: TextStyle(
                              fontSize: dim.fontSizeS,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          SizedBox(width: dim.spaceXS),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              context.goNamed(RouteNames.login);
                            },
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(fontFamily: 'sfpro'),
                            ),
                          ),
                        ],
                      ),

                      // İptal butonu
                      // AppButton(
                      //   text: 'İptal',
                      //   onPressed: () => context.goNamed(RouteNames.login),
                      //   type: AppButtonType.secondary,
                      //   height: dim.buttonHeight,
                      // ),
                    ],
                  ),
                ),
              );
            },
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
        title: const Text('Hata'),
        content: Text(message),
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
