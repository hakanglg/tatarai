import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tatarai/core/base/base_state_widget.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/utils/loading_view.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';

/// Uygulama başlangıç ekranı
class SplashScreen extends StatefulWidget {
  /// Default constructor
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

    // Logo animasyonu için controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Ölçeklendirme animasyonu
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Animasyon başlatma
    _animationController.forward();

    // Kullanıcı durumunu kontrol eder ve yönlendirir
    _startInitialization();

    // Timeout timer - her durumda 500ms içinde otomatik olarak geç
    _setupTimeoutTimer();
  }

  void _setupTimeoutTimer() {
    // Önceki timer'ı iptal et
    _timeoutTimer?.cancel();

    // Yeni timer oluştur - 500ms'ye düşürüldü
    _timeoutTimer = Timer(const Duration(milliseconds: 500), () {
      AppLogger.w('Splash ekranı timeout - uygulamaya zorla devam ediliyor');
      // Zorla yönlendirme - geçişi garanti etmek için
      runIfMounted(_navigateForceToLogin, 'Timeout yönlendirme hatası');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timeoutTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Zorla login sayfasına yönlendirir - son çare olarak
  void _navigateForceToLogin() {
    if (_navigationStarted) return;

    setStateIfMounted(() {
      _navigationStarted = true;
    });

    try {
      context.goNamed('login');
    } catch (e) {
      AppLogger.e('Zorla yönlendirme hatası', e);
      try {
        // Native navigator kullan
        Navigator.of(context).pushReplacementNamed('/login');
      } catch (e2) {
        AppLogger.e('Native navigator hatası', e2);
      }
    }
  }

  // Sonraki ekrana yönlendir
  void _navigateToNextScreen() {
    if (_navigationStarted) return;

    setStateIfMounted(() {
      _navigationStarted = true;
    });

    runFutureSafe<void>(
      Future<void>(() async {
        final authState = context.read<AuthCubit>().state;

        if (authState.status == AuthStatus.initial ||
            authState.status == AuthStatus.error) {
          AppLogger.w(
            'Auth durumu hazır değil (${authState.status}), giriş sayfasına yönlendiriliyor',
          );
          context.goNamed('login');
          return;
        }

        if (authState.isAuthenticated) {
          AppLogger.i('Kullanıcı oturum açmış, ana sayfaya yönlendiriliyor');
          // Home ekranına yönlendirmeden önce NavigationManager'ı başlat
          NavigationManager.initialize(initialIndex: 0);

          // NavigationManager'ın başlatıldığından emin ol
          final navManager = NavigationManager.instance;
          if (navManager == null) {
            AppLogger.e('NavigationManager başlatılamadı, yeniden deneniyor');
            // Yeniden deneme
            NavigationManager.initialize(initialIndex: 0);
            if (NavigationManager.instance == null) {
              AppLogger.e('NavigationManager ikinci denemede de başlatılamadı');
            }
          }

          context.goNamed('home');
        } else {
          AppLogger.i(
            'Kullanıcı oturum açmamış, giriş sayfasına yönlendiriliyor',
          );
          context.goNamed('login');
        }
      }),
      onError: (error, stack) {
        AppLogger.e('Yönlendirme sırasında hata', error, stack);
        _navigateForceToLogin();
      },
      errorMessage: 'Yönlendirme sırasında hata',
    );
  }

  /// Uygulamayı başlatır ve kimlik doğrulama durumunu kontrol eder
  void _startInitialization() {
    runFutureSafe<void>(
      Future<void>(() async {
        // AuthCubit'e erişim için dinleyici ekle
        _authSubscription = context.read<AuthCubit>().stream.listen(
          (authState) {
            runIfMounted(() {
              if (_navigationStarted) return;

              if (authState.status != AuthStatus.initial) {
                AppLogger.i('Auth durumu güncellendi: ${authState.status}');
                _timeoutTimer?.cancel(); // Mevcut timer'ı iptal et
                _navigateToNextScreen();
              }
            });
          },
          onError: (error, stack) {
            AppLogger.e('Auth durumu dinleme hatası', error, stack);
            // Hata durumunda zorla yönlendir
            runIfMounted(_navigateForceToLogin);
          },
        );

        // Mevcut durumu hemen kontrol et
        final currentState = context.read<AuthCubit>().state;
        AppLogger.i('Mevcut auth durumu: ${currentState.status}');

        if (currentState.status != AuthStatus.initial) {
          AppLogger.i('Auth durumu hazır: ${currentState.status}');
          _timeoutTimer?.cancel();
          _navigateToNextScreen();
        }
      }),
      onError: (error, stack) {
        AppLogger.e('Splash initialization error', error, stack);
        // Splash ekranında hata - zorla giriş sayfasına yönlendir
        _navigateForceToLogin();
      },
      errorMessage: 'Splash initialization error',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
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
                      minWidth:
                          10.0, // Minimum genişlik ekleyerek sonsuz genişlik hatasını önle
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo
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
                        // Uygulama adı
                        const Text(
                          'TatarAI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Yapay Zeka ile Tarım Asistanı',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'sfpro',
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Sadece yükleniyor göstergesi
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
