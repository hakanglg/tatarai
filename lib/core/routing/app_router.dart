import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/routing/route_paths.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/views/login_screen.dart';
import 'package:tatarai/features/auth/views/register_screen.dart';
import 'package:tatarai/features/home/views/home_screen.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/onboarding/views/onboarding_screen.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';
import 'package:tatarai/features/plant_analysis/views/analyses_result/analysis_result_screen.dart';
import 'package:tatarai/features/plant_analysis/views/analysis/analysis_screen.dart';
import 'package:tatarai/features/profile/views/profile_screen.dart';
import 'package:tatarai/features/splash/views/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama router sınıfı
class AppRouter {
  final AuthCubit authCubit;
  bool _isRedirecting = false;

  /// Constructor
  AppRouter({required this.authCubit});

  /// Go Router örneği oluşturur
  GoRouter get router => GoRouter(
        initialLocation: RoutePaths.splash,
        debugLogDiagnostics: true,
        routes: _routes,
        redirect: _handleRedirect,
        refreshListenable: GoRouterRefreshStream(authCubit.stream),
      );

  /// Router yönlendirme kuralları
  List<RouteBase> get _routes => [
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboarding,
          name: RouteNames.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.register,
          name: RouteNames.register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: RoutePaths.analysis,
          name: RouteNames.analysis,
          builder: (context, state) => const AnalysisScreen(),
        ),
        GoRoute(
          path: '${RoutePaths.analysisResult}/:id',
          name: RouteNames.analysisResult,
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AnalysisResultScreen(analysisId: id);
          },
        ),
        GoRoute(
          path: RoutePaths.profile,
          name: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.premium,
          name: RouteNames.premium,
          builder: (context, state) => const PremiumScreen(),
        ),
      ];

  /// Yönlendirme kuralları
  Future<String?> _handleRedirect(
      BuildContext context, GoRouterState state) async {
    // Sonsuz döngüyü önlemek için yönlendirme durumunu kontrol et
    if (_isRedirecting) {
      return null;
    }

    final authState = authCubit.state;
    final isLoggedIn = authState.isAuthenticated;
    final isSplash = state.matchedLocation == RoutePaths.splash;
    final isOnboarding = state.matchedLocation == RoutePaths.onboarding;
    final isLoggingIn = state.matchedLocation == RoutePaths.login ||
        state.matchedLocation == RoutePaths.register;

    // Uygulama başlangıcında durumu logla
    AppLogger.i(
      'Router - Path: ${state.matchedLocation}, Auth: ${authState.status}, Giriş: $isLoggedIn',
    );

    // Splash ekranında hiçbir yönlendirme yapma, splash ekranı kendi kendine yönlendirecek
    if (isSplash) {
      return null;
    }

    // Onboarding ekranında ve onboarding ekranına yönlendirdiysek, doğrudan yönlendirme yapma
    if (isOnboarding) {
      return null;
    }

    try {
      _isRedirecting = true;

      // Onboarding tamamlandı mı kontrol et (splash dışındaki durumlar için)
      if (!isSplash && !isOnboarding) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;

        // Onboarding tamamlanmamışsa ve onboarding ekranında değilsek, onboarding'e yönlendir
        if (!onboardingCompleted) {
          return RoutePaths.onboarding;
        }
      }

      // Oturum açıksa ve giriş/kayıt ekranına gitmeye çalışıyorsa, ana sayfaya yönlendir
      if (isLoggedIn && (isLoggingIn)) {
        // Home ekranına gitmeden önce NavigationManager'ı başlat
        if (NavigationManager.instance == null) {
          AppLogger.i(
            'Ana sayfaya yönlendirmeden önce NavigationManager başlatılıyor',
          );
          NavigationManager.initialize(initialIndex: 0);
        }
        return RoutePaths.home;
      }

      // Oturum açık değilse ve korumalı bir sayfaya gitmeye çalışıyorsa, giriş sayfasına yönlendir
      if (!isLoggedIn && !isLoggingIn && !isSplash && !isOnboarding) {
        return RoutePaths.login;
      }

      // Home ekranına yönlendirme varsa, NavigationManager'ı başlat
      if (state.matchedLocation == RoutePaths.home &&
          NavigationManager.instance == null) {
        AppLogger.i(
          'Home ekranına yönlendirme öncesi NavigationManager başlatılıyor',
        );
        NavigationManager.initialize(initialIndex: 0);
      }

      return null;
    } finally {
      _isRedirecting = false;
    }
  }
}

/// BLoC Stream'lerini dinleyen bir GoRouter refresh stream
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
