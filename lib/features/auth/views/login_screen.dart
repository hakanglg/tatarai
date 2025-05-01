import 'package:firebase_auth/firebase_auth.dart';
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

/// Kullanıcı giriş ekranı
class LoginScreen extends StatefulWidget {
  /// Constructor
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Giriş Yap')),
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
                      SizedBox(height: dim.spaceXL),
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
                          'Yapay Zeka ile Tarım Asistanı',
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: dim.fontSizeM,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                      SizedBox(height: dim.spaceXXL),

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
                      SizedBox(height: dim.spaceXS),

                      // Şifremi unuttum
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
                      SizedBox(height: dim.spaceL),

                      // Giriş butonu
                      AppButton(
                        text: 'Giriş Yap',
                        isLoading: state.isLoading || _isSubmitting,
                        onPressed:
                            (state.isLoading || _isSubmitting) ? null : _signIn,
                        icon: CupertinoIcons.arrow_right,
                      ),
                      SizedBox(height: dim.spaceL),

                      // Kayıt ol yönlendirmesi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabınız yok mu?',
                            style: TextStyle(
                              fontFamily: 'sfpro',
                              fontSize: dim.fontSizeS,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          SizedBox(width: dim.spaceXS),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    context.goNamed(RouteNames.register);
                                  },
                            child: const Text('Kayıt Ol'),
                          ),
                        ],
                      ),
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
              title: const Text('Şifre Sıfırlama'),
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
                        color: CupertinoColors.systemGrey6,
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
        title: const Text('Bağlantı Gönderildi'),
        content: const Text(
          'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. '
          'Lütfen e-postanızı kontrol edin ve bağlantıya tıklayarak şifrenizi sıfırlayın.',
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
