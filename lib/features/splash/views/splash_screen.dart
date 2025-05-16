import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/base/base_state_widget.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/routing/route_paths.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/services/remote_config_service.dart';
import 'package:tatarai/core/utils/semantic_version.dart';
import 'package:tatarai/core/utils/version_util.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/update/views/force_update_screen.dart';
import 'package:tatarai/features/update/views/update_dialog.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends BaseState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _timeoutTimer;
  bool _navigationStarted = false;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _startInitialization();
    _setupTimeoutTimer();
  }

  void _setupTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(milliseconds: 2000), () {
      AppLogger.w('Splash ekranı timeout - uygulamaya zorla devam ediliyor');
      runIfMounted(_checkVersionAndNavigate, 'Timeout yönlendirme hatası');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timeoutTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkVersionAndNavigate() async {
    if (_navigationStarted) return;

    setStateIfMounted(() {
      _navigationStarted = true;
    });

    final forceNavigateTimer = Timer(const Duration(seconds: 5), () {
      AppLogger.w('Versiyon kontrol zaman aşımı – devam ediliyor.');
      if (mounted) _navigateToNextScreen();
    });

    try {
      AppLogger.i('Versiyon kontrolü yapılıyor...');

      // Remote Config başlatma işlemi main.dart'ta yapıldığı için
      // burada sadece config değerlerini alıyoruz
      final packageInfo = await PackageInfo.fromPlatform();
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final locale = Localizations.localeOf(context).languageCode;

      final config = RemoteConfigService().getUpdateConfig(
        isAndroid: isAndroid,
        locale: locale,
      );

      // Debug mode kontrolü - geliştirme sırasında test için
      if (kDebugMode) {
        final testMode = false; // Test etmek için true yapın

        if (testMode) {
          final testCase = 2; // 1: force update, 2: optional update

          AppLogger.i('DEBUG: Test modu etkin - Test case: $testCase');
          forceNavigateTimer.cancel();

          if (testCase == 1) {
            if (!mounted) return;
            context.pushReplacement(RoutePaths.forceUpdate, extra: config);
            return;
          } else if (testCase == 2) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => UpdateDialog(config: config),
                  ).then((_) {
                    _navigateToNextScreen();
                  });
                }
              });
              return;
            }
          }
        }
      }

      final currentVersion = SemanticVersion.fromString(packageInfo.version);
      final minVersion = SemanticVersion.fromString(config.minVersion);
      final latestVersion = SemanticVersion.fromString(config.latestVersion);

      forceNavigateTimer.cancel();

      // Tüm versiyon bilgilerini ve karşılaştırma sonuçlarını detaylı logla
      final isForceRequired = VersionUtil.isForceUpdateRequired(
          current: currentVersion, minRequired: minVersion);

      final isOptionalAvailable = VersionUtil.isOptionalUpdateAvailable(
          current: currentVersion, latest: latestVersion);

      AppLogger.i(
          'Versiyon karşılaştırması: mevcut=$currentVersion, minimum=$minVersion, en son=$latestVersion, ' +
              'zorunlu güncelleme gerekli: $isForceRequired, opsiyonel güncelleme mevcut: $isOptionalAvailable');

      if (isForceRequired) {
        AppLogger.w('Zorunlu güncelleme gerekli');
        if (!mounted) return;

        // Navigator yerine GoRouter kullan
        context.pushReplacement(RoutePaths.forceUpdate, extra: config);
        return;
      }

      if (isOptionalAvailable) {
        AppLogger.i('Opsiyonel güncelleme mevcut, dialog gösteriliyor...');
        if (mounted) {
          // Ana ekrana geçmeden önce dialog göstermek için navigasyonu geciktir
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => UpdateDialog(config: config),
              ).then((_) {
                // Dialog kapatıldıktan sonra ana ekrana git
                _navigateToNextScreen();
              });
            }
          });
          return; // Dialog gösterildikten sonra burada dur, _navigateToNextScreen zaten dialog kapatılınca çağrılacak
        }
      }

      _navigateToNextScreen();
    } catch (e, stack) {
      forceNavigateTimer.cancel();
      AppLogger.e('Versiyon kontrolü başarısız', e, stack);
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      if (!mounted) return;

      if (!onboardingCompleted) {
        AppLogger.i(
            'Onboarding tamamlanmamış, onboarding ekranına yönlendiriliyor');
        context.goNamed(RouteNames.onboarding);
      } else {
        final authState = context.read<AuthCubit>().state;
        if (authState.isAuthenticated) {
          AppLogger.i('Kullanıcı giriş yapmış, ana sayfaya yönlendiriliyor');
          NavigationManager.initialize(initialIndex: 0);
          context.goNamed(RouteNames.home);
        } else {
          AppLogger.i(
              'Kullanıcı giriş yapmamış, giriş sayfasına yönlendiriliyor');
          context.goNamed(RouteNames.login);
        }
      }
    } catch (e) {
      AppLogger.e('Yönlendirme hatası', e);
      if (mounted) {
        context.goNamed(RouteNames.login);
      }
    }
  }

  void _startInitialization() {
    runFutureSafe<void>(
      Future<void>(() async {
        _authSubscription = context.read<AuthCubit>().stream.listen(
          (authState) {
            runIfMounted(() {
              if (_navigationStarted) return;
              if (authState.status != AuthStatus.initial) {
                AppLogger.i('Auth durumu güncellendi: ${authState.status}');
                _timeoutTimer?.cancel();
                _checkVersionAndNavigate();
              }
            });
          },
          onError: (error, stack) {
            AppLogger.e('Auth dinleme hatası', error, stack);
            runIfMounted(_checkVersionAndNavigate);
          },
        );

        final currentState = context.read<AuthCubit>().state;
        AppLogger.i('Mevcut auth durumu: ${currentState.status}');
        if (currentState.status != AuthStatus.initial) {
          AppLogger.i('Auth hazır: ${currentState.status}');
          _timeoutTimer?.cancel();
          _checkVersionAndNavigate();
        }
      }),
      onError: (error, stack) {
        AppLogger.e('Splash initialization error', error, stack);
        _checkVersionAndNavigate();
      },
      errorMessage: 'Splash initialization error',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: screenSize.width * 0.8,
                      minWidth: 10.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.leaf_arrow_circlepath,
                                color: AppColors.primary,
                                size: 70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('TatarAI',
                            textAlign: TextAlign.center,
                            style: AppTextTheme.headline1),
                        const SizedBox(height: 8),
                        const Text('Yapay Zeka ile Tarım Asistanı',
                            textAlign: TextAlign.center,
                            style: AppTextTheme.body),
                        const SizedBox(height: 48),
                        const CupertinoActivityIndicator(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
