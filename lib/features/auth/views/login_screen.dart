// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
// import 'package:tatarai/core/extensions/string_extension.dart';
// import 'package:tatarai/core/routing/route_names.dart';
// import 'package:tatarai/core/theme/color_scheme.dart';
// import 'package:tatarai/core/theme/dimensions.dart';
// import 'package:tatarai/core/theme/text_theme.dart';
// import 'package:tatarai/core/utils/logger.dart';
// import 'package:tatarai/core/widgets/app_button.dart';
// import 'package:tatarai/core/widgets/app_text_field.dart';
// import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
// import 'package:tatarai/features/auth/cubits/auth_state.dart';
// import 'package:sprung/sprung.dart';
// import 'package:flutter_signin_button/flutter_signin_button.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:tatarai/core/widgets/app_dialog_manager.dart';

// part 'login_screen_mixin.dart';

// /// Kullanıcı giriş ekranı
// class LoginScreen extends StatefulWidget {
//   /// Constructor
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen>
//     with SingleTickerProviderStateMixin, _LoginScreenMixin {
//   // Hata mesajlarının tekrarını önlemek için son gösterilen hata
//   String? _lastShownError;
//   // Hesap silindi mesajının tekrar gösterilmesini önlemek için flag
//   final bool _accountDeletedShown = false;

//   @override
//   void dispose() {
//     // Son hata referansını temizle
//     _lastShownError = null;
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Responsive değerler için dimensions
//     final dim = context.dimensions;

//     return BlocListener<AuthCubit, AuthState>(
//       listener: (context, state) async {
//         // Widget kaldırıldı mı kontrolü
//         if (!mounted) return;

//         if (_isSubmitting && !state.isLoading) {
//           setState(() {
//             _isSubmitting = false;
//           });
//         }

//         if (state.isLoading) {
//           // Loading ekranı gösterme
//           AppLogger.i('Giriş yükleniyor durumu: ${state.isLoading}');
//         }

//         if (state.isAuthenticated) {
//           // Başarılı girişte e-posta kaydet/sil
//           if (_rememberMe) {
//             await _saveRememberedEmail(_emailController.text.trim());
//             AppLogger.i(
//                 '[Beni Hatırla] Başarılı giriş sonrası kaydedildi: \\${_emailController.text.trim()}');
//           } else {
//             await _clearRememberedEmail();
//             AppLogger.i('[Beni Hatırla] Başarılı giriş sonrası silindi');
//           }
//           context.goNamed(RouteNames.home);
//         } else if (state.errorMessage != null &&
//             !state.isLoading &&
//             state.errorMessage != _lastShownError) {
//           // Hata durumu - yükleme tamamlandıysa, hata varsa ve daha önce gösterilmediyse göster
//           _lastShownError = state.errorMessage;
//           _showErrorDialog(context, state.errorMessage!);
//         }
//       },
//       child: Scaffold(
//         body: SafeArea(
//           child: BlocBuilder<AuthCubit, AuthState>(
//             builder: (context, state) {
//               // Sadece giriş işlemi sırasında loading göster
//               final isLoading = state.isLoading && _isSubmitting;

//               return Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: dim.paddingL,
//                   vertical: dim.paddingS,
//                 ),
//                 constraints: BoxConstraints(
//                   minHeight: MediaQuery.of(context).size.height -
//                       MediaQuery.of(context).padding.top -
//                       MediaQuery.of(context).padding.bottom,
//                 ),
//                 child: FadeTransition(
//                   opacity: _fadeAnimation,
//                   child: ScaleTransition(
//                     scale: _scaleAnimation,
//                     child: SlideTransition(
//                       position: _slideAnimation,
//                       child: Form(
//                         key: _formKey,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             // Üst kısım (logo ve başlık)
//                             Column(
//                               children: [
//                                 SizedBox(height: dim.spaceS),
//                                 // Logo ve app ismi yan yana
//                                 Text('app_name'.locale(context),
//                                     style: AppTextTheme.headline4.copyWith(
//                                       color: AppColors.primary,
//                                       letterSpacing: -1.0,
//                                     )),
//                                 SizedBox(height: dim.spaceS),
//                                 Text(
//                                   'login_title'.locale(context),
//                                   textAlign: TextAlign.center,
//                                   style: AppTextTheme.bodyLarge.copyWith(
//                                     fontWeight: FontWeight.w600,
//                                     letterSpacing: -0.5,
//                                   ),
//                                 ),
//                                 SizedBox(height: dim.spaceXS),
//                                 Text(
//                                   'login_subtitle'.locale(context),
//                                   textAlign: TextAlign.center,
//                                   style: AppTextTheme.body.copyWith(
//                                     color: AppColors.textSecondary,
//                                     height: 1.0,
//                                   ),
//                                 ),
//                               ],
//                             ),

//                             // Orta kısım (form alanları)
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.stretch,
//                               children: [
//                                 _buildInputField(
//                                   controller: _emailController,
//                                   placeholder: 'email'.locale(context),
//                                   keyboardType: TextInputType.emailAddress,
//                                   icon: CupertinoIcons.mail,
//                                   dim: dim,
//                                 ),
//                                 SizedBox(height: dim.spaceM),
//                                 _buildInputField(
//                                   controller: _passwordController,
//                                   placeholder: 'password'.locale(context),
//                                   obscureText: true,
//                                   icon: CupertinoIcons.lock,
//                                   dim: dim,
//                                 ),
//                                 SizedBox(height: dim.spaceXS),
//                                 // Beni hatırla seçeneği
//                                 Row(
//                                   children: [
//                                     CupertinoSwitch(
//                                       value: _rememberMe,
//                                       onChanged: onRememberMeChanged,
//                                       activeTrackColor: AppColors.primary,
//                                     ),
//                                     SizedBox(width: dim.spaceXS),
//                                     Text(
//                                       'remember_me'.locale(context),
//                                       style: AppTextTheme.captionL.copyWith(
//                                         color: AppColors.textSecondary,
//                                       ),
//                                     ),
//                                     Spacer(),
//                                     CupertinoButton(
//                                       padding: EdgeInsets.zero,
//                                       onPressed: () {
//                                         _showResetPasswordDialog(context);
//                                       },
//                                       child: Text(
//                                         'forgot_password'.locale(context),
//                                         style: AppTextTheme.captionL.copyWith(
//                                           color: AppColors.primary,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 SizedBox(height: dim.spaceXL),
//                                 _buildAuthButton(
//                                   context: context,
//                                   isLoading: isLoading,
//                                   onPressed: (isLoading) ? null : _signIn,
//                                 ),
//                                 SizedBox(height: dim.spaceS),
//                                 // VEYA Ayırıcı
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: Divider(
//                                         color: AppColors.disabled,
//                                         thickness: 1,
//                                       ),
//                                     ),
//                                     Padding(
//                                       padding: EdgeInsets.symmetric(
//                                           horizontal: dim.spaceM),
//                                       child: Text(
//                                         'or'.locale(context),
//                                         style:
//                                             AppTextTheme.smallCaption.copyWith(
//                                           color: AppColors.textSecondary,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Divider(
//                                         color: AppColors.disabled,
//                                         thickness: 1,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 SizedBox(height: dim.spaceS),
//                                 // Google ve Apple butonlarını yan yana yerleştirme
//                                 Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     Expanded(
//                                       child: SignInButton(
//                                         Buttons.GoogleDark,
//                                         text:
//                                             'login_with_google'.locale(context),
//                                         onPressed: _signInWithGoogle,
//                                         padding: EdgeInsets.zero,
//                                       ),
//                                     ),
//                                     SizedBox(width: dim.spaceXS),
//                                     Expanded(
//                                       child: SignInButton(
//                                         Buttons.AppleDark,
//                                         text:
//                                             'login_with_apple'.locale(context),
//                                         onPressed: _signInWithApple,
//                                         padding: EdgeInsets.zero,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                             // Alt kısım (kayıt ol seçeneği)
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   'no_account'.locale(context),
//                                   style: AppTextTheme.captionL.copyWith(
//                                     color: AppColors.textSecondary,
//                                   ),
//                                 ),
//                                 AppButton(
//                                   type: AppButtonType.text,
//                                   text: 'signup'.locale(context),
//                                   onPressed: () =>
//                                       context.goNamed(RouteNames.register),
//                                 )
//                               ],
//                             ),
//                             SizedBox(height: dim.spaceM),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   /// Logo widget'ı
//   Widget _buildLogo(AppDimensions dim) {
//     return Column(
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             color: AppColors.primary.withValues(alpha: 0.08),
//             borderRadius: BorderRadius.circular(dim.radiusL),
//           ),
//           padding: EdgeInsets.all(dim.paddingM),
//           child: Icon(
//             CupertinoIcons.leaf_arrow_circlepath,
//             size: dim.iconSizeXL,
//             color: AppColors.primary,
//           ),
//         ),
//         SizedBox(height: dim.spaceM),
//         Text(
//           'app_name'.locale(context),
//           style: AppTextTheme.headline1.copyWith(
//             color: AppColors.primary,
//             letterSpacing: -1.0,
//           ),
//         ),
//       ],
//     );
//   }

//   /// Daha güzel input alan widget'ı oluşturur
//   Widget _buildInputField({
//     required TextEditingController controller,
//     required String placeholder,
//     required IconData icon,
//     required AppDimensions dim,
//     TextInputType keyboardType = TextInputType.text,
//     bool obscureText = false,
//   }) {
//     return AppTextField(
//       controller: controller,
//       hintText: placeholder,
//       prefixIcon: icon,
//       keyboardType: keyboardType,
//       obscureText: obscureText,
//       suffixIcon: obscureText ? CupertinoIcons.eye : null,
//       onSuffixIconTap: obscureText
//           ? () {
//               setState(() {
//                 _obscurePassword = !_obscurePassword;
//               });
//             }
//           : null,
//     );
//   }

//   /// Özel Auth button widget'ı oluşturur
//   Widget _buildAuthButton({
//     required BuildContext context,
//     required bool isLoading,
//     required VoidCallback? onPressed,
//   }) {
//     return AppButton(
//       text: 'login'.locale(context),
//       isLoading: isLoading,
//       onPressed: onPressed,
//       isFullWidth: true,
//     );
//   }

//   /// Normal e-posta/şifre giriş metodunu çağırır
//   @override
//   Future<void> _signIn() async {
//     if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
//       return;
//     }

//     setState(() {
//       _isSubmitting = true;
//     });

//     context.read<AuthCubit>().signInWithEmail(
//           _emailController.text.trim(),
//           _passwordController.text,
//           // rememberMe: _rememberMe,
//         );
//   }
// }
