// part of 'register_screen.dart';

// mixin _RegisterScreenMixin on State<RegisterScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _displayNameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;
//   bool _acceptTerms = false;
//   bool _isSubmitting = false;

//   // Animasyon için controller
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();

//     // Animasyon controller'ı başlat
//     _animationController = AnimationController(
//       vsync: this as TickerProvider,
//       duration: const Duration(milliseconds: 1000),
//     );

//     // Animasyonları tanımla
//     _fadeAnimation = CurvedAnimation(
//       parent: _animationController,
//       curve: Sprung.custom(
//         mass: 1.0,
//         stiffness: 400.0,
//         damping: 15.0,
//       ),
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, 0.1),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Sprung.custom(
//         mass: 1.0,
//         stiffness: 400.0,
//         damping: 15.0,
//       ),
//     ));

//     _scaleAnimation = Tween<double>(
//       begin: 0.95,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Sprung.custom(
//         mass: 1.0,
//         stiffness: 400.0,
//         damping: 15.0,
//       ),
//     ));

//     // Animasyonu başlat
//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     // Controller'ları temizle
//     _displayNameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();

//     // Animasyon kontrolcüsünü temizle
//     _animationController.dispose();

//     super.dispose();
//   }

//   /// Kayıt ol butonuna tıklandığında çalışır
//   void _signUp() {
//     // Widget kaldırıldıysa işlemi pas geçiyoruz
//     if (!mounted) return;

//     // Form validasyonu
//     if (_formKey.currentState?.validate() ?? false) {
//       // Klavyeyi kapat
//       FocusScope.of(context).unfocus();

//       // Yerel kontroller
//       if (!_acceptTerms) {
//         _showErrorDialog(
//           context,
//           'Kayıt olmak için kullanım koşullarını kabul etmelisiniz.',
//         );
//         return;
//       }

//       if (_passwordController.text != _confirmPasswordController.text) {
//         _showErrorDialog(context, 'Şifreler eşleşmiyor.');
//         return;
//       }

//       if (_passwordController.text.length < 6) {
//         _showErrorDialog(context, 'Şifre en az 6 karakter olmalıdır.');
//         return;
//       }

//       if (_displayNameController.text.isEmpty) {
//         _showErrorDialog(context, 'Kullanıcı adı boş olamaz.');
//         return;
//       }

//       if (_emailController.text.isEmpty) {
//         _showErrorDialog(context, 'E-posta adresi boş olamaz.');
//         return;
//       }

//       // Sadece widget hala etkinse setState çağır
//       if (mounted) {
//         setState(() {
//           _isSubmitting = true;
//         });

//         // Firebase kayıt işlemi
//         context.read<AuthCubit>().signUpWithEmail(
//               _emailController.text.trim(),
//               _passwordController.text.trim(),
//               displayName: _displayNameController.text.trim(),
//             );
//       }
//     } else {
//       // Form validasyonu başarısız olduğunda hata mesajı göster
//       _showErrorDialog(
//         context,
//         'Lütfen tüm alanları doğru şekilde doldurun.',
//       );
//     }
//   }

//   /// Hata mesajlarını gösterir
//   void _showErrorDialog(BuildContext context, String message) {
//     // Widget kaldırıldıysa dialog göstermeyi pas geçiyoruz
//     if (!mounted) return;

//     // Firebase hata mesajlarını kullanıcı dostu hale getir
//     String userFriendlyMessage = message;

//     // Exception: içeren veya teknik detaylı tüm hataları kullanıcı dostu hale getir
//     if (message.contains('Exception:') ||
//         message.contains('Error:') ||
//         message.contains('firebase') ||
//         message.contains('Firebase')) {
//       // Özel hata durumları
//       if (message.toLowerCase().contains('email-already-in-use') ||
//           message.toLowerCase().contains('already in use')) {
//         userFriendlyMessage =
//             'Bu e-posta adresi zaten kullanılıyor. Başka bir e-posta adresi kullanabilir veya giriş yapmayı deneyebilirsiniz.';
//       } else if (message.toLowerCase().contains('weak-password') ||
//           message.toLowerCase().contains('weak password')) {
//         userFriendlyMessage =
//             'Şifreniz çok zayıf. Lütfen en az 6 karakter içeren daha güçlü bir şifre belirleyin.';
//       } else if (message.toLowerCase().contains('invalid-email') ||
//           message.toLowerCase().contains('invalid email')) {
//         userFriendlyMessage =
//             'Geçersiz e-posta adresi. Lütfen düzgün bir e-posta formatı kullanın.';
//       } else if (message.toLowerCase().contains('network') ||
//           message.toLowerCase().contains('connection') ||
//           message.toLowerCase().contains('unavailable') ||
//           message.toLowerCase().contains('internet')) {
//         userFriendlyMessage =
//             'İnternet bağlantınızda bir sorun var. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.';
//       } else if (message.toLowerCase().contains('timeout') ||
//           message.toLowerCase().contains('timed out')) {
//         userFriendlyMessage =
//             'İşlem çok uzun sürdü. Lütfen daha sonra tekrar deneyin.';
//       } else if (message
//               .toLowerCase()
//               .contains('createuserwithemailandpassword') ||
//           message.toLowerCase().contains('create user')) {
//         userFriendlyMessage =
//             'Hesap oluşturulurken bir sorun oluştu. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
//       } else {
//         // Genel hata durumu
//         userFriendlyMessage =
//             'Hesap oluşturulurken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.';
//       }
//     }

//     // Dialog'u yalnızca widget hala kullanımdaysa göster
//     if (mounted) {
//       showCupertinoDialog(
//         context: context,
//         builder: (dialogContext) => CupertinoAlertDialog(
//           title: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 CupertinoIcons.exclamationmark_triangle,
//                 color: AppColors.error,
//                 size: 22,
//               ),
//               SizedBox(width: 8),
//               Text(
//                 'Bir sorun oluştu',
//                 style: AppTextTheme.body.copyWith(
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           content: Padding(
//             padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
//             child: Text(
//               userFriendlyMessage,
//               style: AppTextTheme.captionL,
//               textAlign: TextAlign.center,
//             ),
//           ),
//           actions: [
//             CupertinoDialogAction(
//               onPressed: () {
//                 // Dialog'u kapat - güvenli erişim için dialogContext kullanıyoruz
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text(
//                 'Anladım',
//                 style: AppTextTheme.body.copyWith(
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//   }
// }
