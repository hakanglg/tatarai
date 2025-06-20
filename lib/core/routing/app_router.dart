import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import '../utils/update_config.dart';
import 'route_names.dart';
import 'route_paths.dart';
import '../../features/auth/cubits/auth_cubit.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/navbar/navigation_manager.dart';
import '../../features/onboarding/views/onboarding_screen.dart';
import '../../features/plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';
import '../../features/plant_analysis/presentation/views/analysis/analysis_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/settings/views/language_selection_screen.dart';
import '../../features/splash/views/splash_screen.dart';
import '../../features/update/views/force_update_screen.dart';

/// Uygulama içi yönlendirmeleri yönetir
class AppRouter {
  /// AuthCubit örneği
  final AuthCubit authCubit;

  /// Yönlendirme işlemi devam ediyor mu
  bool _isRedirecting = false;

  /// Constructor
  AppRouter({required this.authCubit});

  /// Go Router örneği oluşturur
  GoRouter get router => GoRouter(
        initialLocation: RoutePaths.splash,
        debugLogDiagnostics: true,
        redirect: _handleRedirect,
        refreshListenable: _GoRouterRefreshStream(authCubit.stream),
        routes: [
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
          // Login ve register sayfaları kaldırıldı - tüm kullanıcılar anonim giriş yapacak
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.analysis,
            name: RouteNames.analysis,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final imageFile = extra?['imageFile'] as File?;
              return AnalysisScreen(imageFile: imageFile);
            },
          ),
          GoRoute(
            path: RoutePaths.analysisResult,
            name: RouteNames.analysisResult,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final analysisId = extra?['analysisId'] as String?;
              if (analysisId == null) {
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Analiz sonucu bulunamadı',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              return AnalysisResultScreen(analysisId: analysisId);
            },
          ),
          GoRoute(
            path: RoutePaths.languageSelection,
            name: RouteNames.languageSelection,
            builder: (context, state) => const LanguageSelectionScreen(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            name: RouteNames.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          // Premium sayfası şu an mevcut değil
          // GoRoute(
          //   path: RoutePaths.premium,
          //   name: RouteNames.premium,
          //   builder: (context, state) => const PremiumScreen(),
          // ),
          GoRoute(
            path: RoutePaths.forceUpdate,
            name: RouteNames.forceUpdate,
            builder: (context, state) {
              final config = state.extra as UpdateConfig?;
              return ForceUpdateScreen(
                  config: config ?? UpdateConfig.defaultConfig());
            },
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sayfa bulunamadı',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Ana Sayfaya Dön'),
                ),
              ],
            ),
          ),
        ),
      );

  /// Router yönlendirme kuralları
  Future<String?> _handleRedirect(
      BuildContext context, GoRouterState state) async {
    AppLogger.i(
        '🧭 Router redirect başladı - location: ${state.matchedLocation}');

    if (_isRedirecting) {
      AppLogger.i('🧭 Zaten yönlendirme devam ediyor, atlanıyor');
      return null;
    }

    final authState = authCubit.state;
    final isLoggedIn = authState.isAuthenticated;
    final isSplash = state.matchedLocation == RoutePaths.splash;
    final isOnboarding = state.matchedLocation == RoutePaths.onboarding;
    final isForceUpdate = state.matchedLocation == RoutePaths.forceUpdate;

    AppLogger.i(
      '🧭 Router - Path: ${state.matchedLocation}, Auth: ${authState.status}, Giriş: $isLoggedIn',
    );

    // Force update ve splash için özel durumlar
    if (isForceUpdate) {
      AppLogger.i('🧭 ForceUpdate ekranı - yönlendirme yok');
      return null;
    }

    // Splash ekranı için basit kontrol
    if (isSplash) {
      AppLogger.i('🧭 Splash ekranında - yönlendirme yok');
      return null;
    }

    try {
      _isRedirecting = true;
      AppLogger.i('🧭 Yönlendirme işlemi başlatıldı (_isRedirecting = true)');

      // NavigationManager'ı her durumda başlat
      if (NavigationManager.instance == null) {
        AppLogger.i('🧭 NavigationManager başlatılıyor');
        NavigationManager.initialize(initialIndex: 0);
      }

      // Onboarding kontrolü
      if (!isOnboarding) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;

        if (!onboardingCompleted) {
          AppLogger.i(
              '🧭 Onboarding tamamlanmamış - onboarding ekranına yönlendiriliyor');
          return RoutePaths.onboarding;
        }
      }

      // Login/register sayfalarını ana sayfaya yönlendir
      if (state.matchedLocation == RoutePaths.login ||
          state.matchedLocation == RoutePaths.register) {
        AppLogger.i(
            '🧭 Login/register sayfasından ana sayfaya yönlendiriliyor');
        return RoutePaths.home;
      }

      AppLogger.i('🧭 Router değerlendirme tamamlandı - yönlendirme yok');
      return null;
    } catch (e, stack) {
      AppLogger.e('🧭 Router yönlendirme hatası', e, stack);
      return RoutePaths.home;
    } finally {
      _isRedirecting = false;
      AppLogger.i('🧭 Yönlendirme işlemi tamamlandı (_isRedirecting = false)');
    }
  }
}

/// GoRouter için RefreshListenable sınıfı
/// Stream'i dinler ve değişiklik olduğunda router'ı yeniden yapılandırır
class _GoRouterRefreshStream extends ChangeNotifier {
  /// Stream
  final Stream<dynamic> _stream;

  /// Stream subscription
  late final StreamSubscription<dynamic> _subscription;

  /// Constructor
  _GoRouterRefreshStream(this._stream) {
    notifyListeners();
    _subscription = _stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
