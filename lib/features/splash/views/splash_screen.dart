import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/routing/route_paths.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/splash/services/splash_service.dart';
import 'package:tatarai/features/splash/widgets/splash_logo_widget.dart';
import '../constants/splash_constants.dart';

/// TatarAI uygulamasının giriş ekranı
///
/// Bu ekran uygulama başlangıcında gösterilir ve aşağıdaki işlemleri gerçekleştirir:
/// - AppInitializer durumu kontrolü
/// - Versiyon kontrolü ve güncelleme yönlendirmesi
/// - Authentication durumu kontrolü
/// - Onboarding kontrolü ve yönlendirme
/// - Animasyonlu logo gösterimi
///
/// Clean Architecture prensiplerine uygun olarak business logic
/// SplashService'e taşınmış, UI sadece presentation layer'ı içerir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================================
  // ANIMATION PROPERTIES
  // ============================================================================

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // ============================================================================
  // SERVICE DEPENDENCIES
  // ============================================================================

  final SplashService _splashService = SplashService.instance;

  // ============================================================================
  // STREAM SUBSCRIPTIONS
  // ============================================================================

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    AppLogger.i('🚀 SplashScreen başlatılıyor');

    _initializeAnimations();
    _startSplashFlow();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  /// Animasyonları başlatır
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: SplashConstants.logoAnimationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Sprung.underDamped,
    ));

    _animationController.forward();
    AppLogger.i('✨ Splash animasyonları başlatıldı');
  }

  /// Ana splash flow'unu başlatır
  void _startSplashFlow() {
    // Timeout mekanizması başlat
    _splashService.startInitializationTimeout(
      onTimeout: _handleTimeout,
    );

    // AppInitializer durumunu kontrol et
    _checkAppInitializerStatus();
  }

  /// Kaynakları temizler
  void _disposeResources() {
    _animationController.dispose();
    _authSubscription?.cancel();
    _splashService.dispose();
    AppLogger.i('🧹 SplashScreen kaynakları temizlendi');
  }

  // ============================================================================
  // APP INITIALIZER METHODS
  // ============================================================================

  /// AppInitializer durumunu kontrol eder
  void _checkAppInitializerStatus() {
    if (_splashService.isAppReady) {
      AppLogger.i('✅ AppInitializer hazır, auth kontrolüne geçiliyor');
      _splashService.cancelTimeout();
      _startAuthFlow();
    } else {
      AppLogger.i('⏳ AppInitializer bekleniyor...');
      _waitForAppInitializer();
    }
  }

  /// AppInitializer'ın hazır olmasını bekler
  void _waitForAppInitializer() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_splashService.isAppReady) {
        timer.cancel();
        AppLogger.i('✅ AppInitializer hazır oldu');
        _splashService.cancelTimeout();
        _startAuthFlow();
      }
    });
  }

  // ============================================================================
  // AUTHENTICATION FLOW METHODS
  // ============================================================================

  /// Authentication flow'unu başlatır
  void _startAuthFlow() async {
    // Permissions will be requested when user actually tries to use camera/gallery
    // await _splashService.initializePermissions();

    _authSubscription = context.read<AuthCubit>().stream.listen(
          _handleAuthStateChange,
          onError: _handleAuthError,
        );

    // Mevcut auth durumunu kontrol et
    final currentAuthState = context.read<AuthCubit>().state;
    _handleAuthStateChange(currentAuthState);
  }

  /// Auth state değişikliklerini işler
  Future<void> _handleAuthStateChange(AuthState authState) async {
    if (_splashService.isNavigationStarted) return;

    await runFutureSafe<void>(
      _processAuthStateChange(),
      errorMessage: 'Auth state change işleme hatası',
    );
  }

  /// Auth state değişikliğini işler
  Future<void> _processAuthStateChange() async {
    final authState = context.read<AuthCubit>().state;
    final navigationType =
        await _splashService.checkAuthAndGetNavigation(authState);

    switch (navigationType) {
      case SplashNavigationType.wait:
        // Bekle, henüz hazır değil
        break;

      case SplashNavigationType.signInAnonymously:
        await _performAnonymousSignIn();
        break;

      case SplashNavigationType.home:
        await _checkVersionAndNavigate();
        break;

      default:
        AppLogger.w('⚠️ Beklenmeyen navigation tipi: $navigationType');
        await _checkVersionAndNavigate();
        break;
    }
  }

  /// Auth hatalarını işler
  void _handleAuthError(dynamic error, StackTrace stackTrace) {
    AppLogger.e('❌ Auth stream hatası', error, stackTrace);
    runIfMounted(() async {
      await _performAnonymousSignIn();
    });
  }

  /// Anonim giriş gerçekleştirir
  Future<void> _performAnonymousSignIn() async {
    try {
      AppLogger.i('🔐 Anonim giriş yapılıyor...');
      final authCubit = context.read<AuthCubit>();
      await authCubit.signInAnonymously();
    } catch (e) {
      AppLogger.e('❌ Anonim giriş hatası', e);
      // Hata durumunda da devam et
      await _checkVersionAndNavigate();
    }
  }

  // ============================================================================
  // VERSION CHECK AND NAVIGATION METHODS
  // ============================================================================

  /// Versiyon kontrolü yapar ve uygun ekrana yönlendirir
  Future<void> _checkVersionAndNavigate() async {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;

      final navigationType = await _splashService.checkVersionAndGetNavigation(
        locale: locale,
        isAndroid: isAndroid,
      );

      await _handleNavigationType(navigationType);
    } catch (e, stackTrace) {
      AppLogger.e('❌ Versiyon kontrolü hatası', e, stackTrace);
      await _navigateToNextScreen();
    }
  }

  /// Navigation tipine göre yönlendirme yapar
  Future<void> _handleNavigationType(
      SplashNavigationType navigationType) async {
    if (!mounted) return;

    switch (navigationType) {
      case SplashNavigationType.forceUpdate:
        await _showForceUpdateScreen();
        break;

      case SplashNavigationType.optionalUpdate:
        await _showOptionalUpdateDialog();
        break;

      case SplashNavigationType.continueFlow:
        await _navigateToNextScreen();
        break;

      default:
        AppLogger.w('⚠️ Beklenmeyen navigation tipi: $navigationType');
        await _navigateToNextScreen();
        break;
    }
  }

  /// Zorunlu güncelleme ekranını gösterir
  Future<void> _showForceUpdateScreen() async {
    try {
      AppLogger.i('🔄 Zorunlu güncelleme ekranına yönlendiriliyor');
      // TODO: Update config'i geç
      context.pushReplacement(RoutePaths.forceUpdate);
    } catch (e) {
      AppLogger.e('❌ Force update screen hatası', e);
      await _navigateToNextScreen();
    }
  }

  /// Opsiyonel güncelleme dialog'unu gösterir
  Future<void> _showOptionalUpdateDialog() async {
    try {
      AppLogger.i('📦 Opsiyonel güncelleme dialog\'u gösteriliyor');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              // TODO: Update config'i geç - şimdilik dialog kapatılınca devam et
              builder: (_) => AlertDialog(
                title: const Text('Güncelleme Mevcut'),
                content: const Text(
                    'Yeni bir sürüm mevcut. Güncellemek ister misiniz?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Şimdi Değil'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Güncelle'),
                  ),
                ],
              ),
            ).then((_) {
              _navigateToNextScreen();
            });
          }
        });
      }
    } catch (e) {
      AppLogger.e('❌ Optional update dialog hatası', e);
      await _navigateToNextScreen();
    }
  }

  // ============================================================================
  // FINAL NAVIGATION METHODS
  // ============================================================================

  /// Sonraki ekrana yönlendirir (onboarding veya home)
  Future<void> _navigateToNextScreen() async {
    try {
      AppLogger.i('🧭 Sonraki ekrana yönlendirme başlatılıyor');

      // Navigation flag'ini set et
      _splashService.setNavigationStarted();

      final isOnboardingCompleted =
          await _splashService.isOnboardingCompleted();

      if (!mounted) return;

      if (!isOnboardingCompleted) {
        _navigateToOnboarding();
      } else {
        _navigateToHome();
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Final navigation hatası', e, stackTrace);
      _handleNavigationError();
    }
  }

  /// Onboarding ekranına yönlendirir
  void _navigateToOnboarding() {
    try {
      AppLogger.i('📚 Onboarding ekranına yönlendiriliyor');

      // Navigation flag'ini set et
      _splashService.setNavigationStarted();

      GoRouter.of(context).goNamed(RouteNames.onboarding);
    } catch (e) {
      AppLogger.e('❌ Onboarding navigation hatası', e);
      _handleNavigationError();
    }
  }

  /// Ana sayfaya yönlendirir
  void _navigateToHome() {
    try {
      AppLogger.i('🏠 Ana sayfaya yönlendiriliyor');

      // Navigation flag'ini set et
      _splashService.setNavigationStarted();

      _splashService.initializeNavigationManager();
      GoRouter.of(context).goNamed(RouteNames.home);
    } catch (e) {
      AppLogger.e('❌ Home navigation hatası', e);
      _handleNavigationError();
    }
  }

  // ============================================================================
  // ERROR HANDLING METHODS
  // ============================================================================

  /// Timeout durumunu işler
  void _handleTimeout() {
    AppLogger.w('⏰ Splash timeout gerçekleşti');
    runIfMounted(() {
      _splashService.forceNavigateToHome(GoRouter.of(context));
    });
  }

  /// Navigation hatalarını işler
  void _handleNavigationError() {
    if (!mounted) return;

    try {
      AppLogger.e('🚨 Kritik navigation hatası, son çare yönlendirme');

      // Son çare olarak home'a git
      _splashService.forceNavigateToHome(GoRouter.of(context));

      // Kullanıcıya hata mesajı göster
      _showErrorSnackBar();
    } catch (e) {
      AppLogger.e('💥 Son çare navigation da başarısız', e);
    }
  }

  /// Hata snackbar'ı gösterir
  void _showErrorSnackBar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Uygulama başlatılırken bir sorun oluştu. Lütfen tekrar deneyin.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================================
  // UI BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 SplashScreen build - mounted: $mounted');

    return Scaffold(
      body: CupertinoPageScaffold(
        child: SafeArea(
          child: _buildSplashContent(),
        ),
      ),
    );
  }

  /// Splash içeriğini oluşturur
  Widget _buildSplashContent() {
    return Center(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildLogoSection(),
          );
        },
      ),
    );
  }

  /// Logo bölümünü oluşturur
  Widget _buildLogoSection() {
    final screenSize = MediaQuery.of(context).size;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: screenSize.width * SplashConstants.logoMaxWidthRatio,
        minWidth: SplashConstants.logoMinWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SplashLogoWidget(),
          const SizedBox(height: SplashConstants.spaceBelowLogo),
          _buildAppTitle(),
          const SizedBox(height: SplashConstants.spaceBelowSubtitle),
          _buildAppSubtitle(),
          const SizedBox(height: SplashConstants.spaceAboveLoader),
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  /// Uygulama başlığını oluşturur
  Widget _buildAppTitle() {
    return const Text(
      'TatarAI',
      textAlign: TextAlign.center,
      style: AppTextTheme.headline1,
    );
  }

  /// Uygulama alt başlığını oluşturur
  Widget _buildAppSubtitle() {
    return Text(
      'splash_subtitle'.locale(context),
      textAlign: TextAlign.center,
      style: AppTextTheme.body,
    );
  }

  /// Loading indicator'ı oluşturur
  Widget _buildLoadingIndicator() {
    return const CupertinoActivityIndicator();
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Güvenli Future çalıştırma (mounted kontrolü ile)
  Future<T?> runFutureSafe<T>(
    Future<T> future, {
    String? errorMessage,
  }) async {
    if (!mounted) return null;
    try {
      final result = await future;
      return mounted ? result : null;
    } catch (e, stackTrace) {
      if (mounted) {
        AppLogger.e(errorMessage ?? 'Future execution error', e, stackTrace);
      }
      return null;
    }
  }

  /// Güvenli method çalıştırma (mounted kontrolü ile)
  void runIfMounted(VoidCallback callback) {
    if (mounted) {
      try {
        callback();
      } catch (e, stackTrace) {
        AppLogger.e('Callback execution error', e, stackTrace);
      }
    }
  }
}
