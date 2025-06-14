import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';

/// Onboarding ekranı - kullanıcıya uygulamayı tanıtır
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;
  late AnimationController _backgroundAnimationController;
  late Animation<Color?> _backgroundAnimation;
  late AnimationController _floatingItemsController;
  late Animation<double> _floatingAnimation;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Bitki Sağlığı Analizi',
      description:
          'Yapay zeka ile bitkilerinizin sağlığını analiz edin ve sorunları erken aşamada tespit edin.',
      icon: CupertinoIcons.leaf_arrow_circlepath,
      backgroundOpacity: 0.2,
      mainColor: AppColors.primary,
      illustrationPath: 'assets/images/onboarding_1.png',
      bgElements: const [
        DecorationItem(
          icon: Icons.grass,
          positionFactor: 0.2,
          size: 24,
          opacity: 0.15,
          rotationFactor: 0.3,
        ),
        DecorationItem(
          icon: Icons.local_florist,
          positionFactor: 0.6,
          size: 32,
          opacity: 0.2,
          rotationFactor: -0.2,
        ),
        DecorationItem(
          icon: Icons.eco,
          positionFactor: 0.8,
          size: 30,
          opacity: 0.15,
          rotationFactor: 0.1,
        ),
      ],
    ),
    OnboardingItem(
      title: 'Tarım Tavsiyeleri',
      description:
          'Bitki türüne ve yetişme koşullarına göre özelleştirilmiş tarım tavsiyeleri alın.',
      icon: CupertinoIcons.light_max,
      backgroundOpacity: 0.25,
      mainColor: AppColors.primary,
      illustrationPath: 'assets/images/onboarding_2.png',
      bgElements: const [
        DecorationItem(
          icon: Icons.wb_sunny,
          positionFactor: 0.15,
          size: 32,
          opacity: 0.15,
          rotationFactor: 0.4,
        ),
        DecorationItem(
          icon: Icons.water_drop,
          positionFactor: 0.7,
          size: 26,
          opacity: 0.2,
          rotationFactor: -0.2,
        ),
        DecorationItem(
          icon: Icons.thermostat,
          positionFactor: 0.9,
          size: 28,
          opacity: 0.15,
          rotationFactor: 0.1,
        ),
      ],
    ),
    OnboardingItem(
      title: 'Hastalık Teşhisi',
      description:
          'Bitkilerinizdeki hastalıkları yapay zeka ile teşhis edin ve çözüm önerileri alın.',
      icon: CupertinoIcons.doc_text_search,
      backgroundOpacity: 0.3,
      mainColor: AppColors.primary,
      illustrationPath: 'assets/images/onboarding_3.png',
      bgElements: const [
        DecorationItem(
          icon: Icons.search,
          positionFactor: 0.2,
          size: 28,
          opacity: 0.15,
          rotationFactor: 0.2,
        ),
        DecorationItem(
          icon: Icons.healing,
          positionFactor: 0.6,
          size: 30,
          opacity: 0.2,
          rotationFactor: -0.3,
        ),
        DecorationItem(
          icon: Icons.biotech,
          positionFactor: 0.85,
          size: 32,
          opacity: 0.15,
          rotationFactor: 0.1,
        ),
      ],
    ),
    OnboardingItem(
      title: 'TatarAI\'ye Hoş Geldiniz!',
      description:
          'Bitki sağlığı analizi için yapay zeka destekli uygulamanız hazır. Hemen başlayın ve bitkilerinizin sağlığını profesyonel düzeyde analiz edin.',
      icon: CupertinoIcons.check_mark_circled_solid,
      backgroundOpacity: 0.35,
      mainColor: AppColors.primary,
      illustrationPath: 'assets/images/onboarding_4.png',
      pricingInfo: '',
      specialOffer: 'Ücretsiz 5 analiz hakkı ile başlayın',
      bgElements: const [
        DecorationItem(
          icon: Icons.check_circle,
          positionFactor: 0.1,
          size: 32,
          opacity: 0.2,
          rotationFactor: 0.2,
        ),
        DecorationItem(
          icon: Icons.agriculture,
          positionFactor: 0.5,
          size: 28,
          opacity: 0.25,
          rotationFactor: -0.2,
        ),
        DecorationItem(
          icon: Icons.smartphone,
          positionFactor: 0.85,
          size: 34,
          opacity: 0.2,
          rotationFactor: 0.1,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _backgroundAnimation = ColorTween(
      begin: AppColors.primary.withOpacity(0.15),
      end: AppColors.primary.withOpacity(0.35),
    ).animate(_backgroundAnimationController);

    // Floating items animation
    _floatingItemsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatingAnimation = CurvedAnimation(
      parent: _floatingItemsController,
      curve: Curves.easeInOut,
    );

    _pageController.addListener(_onPageChange);
  }

  void _onPageChange() {
    if (_pageController.page == null) return;

    final page = _pageController.page!.round();
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });

      _backgroundAnimationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChange);
    _pageController.dispose();
    _backgroundAnimationController.dispose();
    _floatingItemsController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < _onboardingItems.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Sprung.overDamped,
      );
    } else {
      _goToPremium();
    }
  }

  Future<void> _goToPremium() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      AppLogger.i('🚀 Onboarding tamamlanıyor, anonim giriş başlatılıyor...');

      // Onboarding'i tamamlandı olarak işaretle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      AppLogger.i('✅ Onboarding completed flag set edildi');

      if (!mounted) return;

      // AuthCubit'i al ve durumunu kontrol et
      final authCubit = context.read<AuthCubit>();
      AppLogger.i(
          '🔍 AuthCubit alındı, mevcut state: ${authCubit.state.runtimeType}');

      // Anonim giriş yap
      AppLogger.i('🔐 Anonim giriş başlatılıyor...');
      await authCubit.signInAnonymously();

      // Giriş sonrası state'i kontrol et
      AppLogger.i(
          '🔍 Anonim giriş sonrası state: ${authCubit.state.runtimeType}');

      if (authCubit.state is AuthAuthenticated) {
        final user = (authCubit.state as AuthAuthenticated).user;
        AppLogger.i('✅ Anonim giriş başarılı - User ID: ${user.id}');
        AppLogger.i('📊 User bilgileri: ${user.toString()}');
      } else if (authCubit.state is AuthError) {
        final authError = authCubit.state as AuthError;
        final error = authError.errorMessage;
        AppLogger.e('❌ Anonim giriş hatası: $error');

        // Kullanıcı dostu hata mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Giriş yapılırken sorun oluştu: $error'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        throw Exception('Anonim giriş başarısız: $error');
      } else {
        AppLogger.w(
            '⚠️ Beklenmeyen auth state: ${authCubit.state.runtimeType}');
      }

      if (!mounted) return;

      AppLogger.i('🏠 Ana sayfaya yönlendiriliyor...');
      // Ana sayfaya yönlendir
      context.goNamed(RouteNames.home);
      AppLogger.i('✅ Ana sayfa yönlendirmesi tamamlandı');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Onboarding tamamlama hatası', e, stackTrace);

      if (!mounted) return;

      // Hata durumunda yine ana sayfaya yönlendir ama kullanıcıyı bilgilendir
      _showErrorAndRedirect(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  /// Hata gösterip ana sayfaya yönlendir
  void _showErrorAndRedirect(String error) {
    AppLogger.w('⚠️ Hata ile ana sayfaya yönlendiriliyor: $error');

    // Kullanıcıya kısa bir hata mesajı göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Giriş sırasında bir sorun oluştu, tekrar deneyin'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      // Kısa bir delay sonra ana sayfaya git
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          context.goNamed(RouteNames.home);
        }
      });
    }
  }

  /// Ana sayfaya yönlendirme (fallback)
  Future<void> _redirectToHome() async {
    try {
      AppLogger.i('Ana sayfaya yönlendiriliyor...');
      if (!mounted) return;

      // Ana sayfaya git
      context.goNamed(RouteNames.home);
    } catch (e) {
      AppLogger.e('Ana sayfa yönlendirme hatası', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final item = _onboardingItems[_currentPage];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  item.mainColor.withOpacity(0.15),
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dekoratif arkaplan öğeleri
              ..._buildBackgroundElements(item, screenSize),

              // Ana içerik
              Column(
                children: [
                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _onboardingItems.length,
                      itemBuilder: (context, index) {
                        final item = _onboardingItems[index];
                        return _buildPage(item, screenSize);
                      },
                    ),
                  ),

                  // Page indicator
                  Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: context.dimensions.paddingL),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingItems.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _currentPage == index ? 24 : 8,
                          height: context.dimensions.spaceXS,
                          margin: EdgeInsets.symmetric(
                              horizontal: context.dimensions.spaceXXS),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusM),
                            color: _currentPage == index
                                ? item.mainColor
                                : AppColors.divider,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Next button
                  Padding(
                    padding: EdgeInsets.only(
                      left: context.dimensions.paddingL,
                      right: context.dimensions.paddingL,
                      bottom: context.dimensions.paddingXL,
                    ),
                    child: AppButton(
                      text: _currentPage < _onboardingItems.length - 1
                          ? 'Devam Et'
                          : 'Uygulamaya Başla',
                      onPressed: _isCompleting
                          ? null
                          : (_currentPage < _onboardingItems.length - 1
                              ? _onNextPage
                              : _goToPremium),
                      isLoading: _isCompleting,
                      isFullWidth: true,
                      type: AppButtonType.primary,
                      height: 54.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundElements(OnboardingItem item, Size screenSize) {
    return item.bgElements.map((decorItem) {
      final xPos = screenSize.width * decorItem.positionFactor;
      final yPos = screenSize.height * (0.2 + Random().nextDouble() * 0.5);

      return Positioned(
        left: xPos,
        top: yPos,
        child: AnimatedBuilder(
          animation: _floatingAnimation,
          builder: (context, child) {
            final offset = 10.0 * _floatingAnimation.value;
            final rotation =
                decorItem.rotationFactor * pi * _floatingAnimation.value;

            return Transform.translate(
              offset: Offset(
                sin(rotation) * offset,
                cos(rotation) * offset,
              ),
              child: Transform.rotate(
                angle: rotation,
                child: Opacity(
                  opacity: decorItem.opacity,
                  child: Icon(
                    decorItem.icon,
                    size: decorItem.getSize(context),
                    color: item.mainColor,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildPage(OnboardingItem item, Size screenSize) {
    // Eğer son sayfaysa (hoş geldiniz sayfası), özel görünüm kullan
    if (_currentPage == _onboardingItems.length - 1) {
      return _buildWelcomePage(item, screenSize);
    }

    // Diğer sayfalar için normal görünüm
    final imageSize = screenSize.width * 0.75;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dimensions.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  margin: EdgeInsets.only(bottom: context.dimensions.spaceL),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(context.dimensions.radiusL),
                  ),
                  alignment: Alignment.center,
                  child: item.illustrationPath != null &&
                          item.illustrationPath!.isNotEmpty
                      ? Image.asset(
                          item.illustrationPath!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildIconFallback(item);
                          },
                        )
                      : _buildIconFallback(item),
                ),
              );
            },
          ),
          SizedBox(height: context.dimensions.spaceM),

          // Title with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.headline2.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: context.dimensions.spaceM),

          // Description with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Hoş geldiniz sayfası için özel tasarım
  Widget _buildWelcomePage(OnboardingItem item, Size screenSize) {
    final imageSize = screenSize.width * 0.48;

    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingS),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hoş geldiniz rozeti
          Container(
            margin: EdgeInsets.only(top: 0, bottom: context.dimensions.spaceM),
            padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.paddingM,
                vertical: context.dimensions.spaceXXS + 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  Colors.green.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(context.dimensions.radiusL),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.checkmark_alt_circle_fill,
                  color: Colors.white,
                  size: context.dimensions.iconSizeXS,
                ),
                SizedBox(width: context.dimensions.spaceXXS),
                Text(
                  'HOŞ GELDİNİZ',
                  style: AppTextTheme.captionL.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Başlık
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.headline2.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: context.dimensions.spaceM),

          // Açıklama
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: context.dimensions.paddingL),

          // Görsel
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Sprung.overDamped,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  margin: EdgeInsets.only(bottom: context.dimensions.spaceL),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(context.dimensions.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: context.dimensions.radiusL,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: item.illustrationPath != null &&
                          item.illustrationPath!.isNotEmpty
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(context.dimensions.radiusL),
                          child: Image.asset(
                            item.illustrationPath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildIconFallback(item);
                            },
                          ),
                        )
                      : _buildIconFallback(item),
                ),
              );
            },
          ),

          const Spacer(),

          // Özel teklif kartı (fiyat yerine)
          if (item.specialOffer.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.only(bottom: context.dimensions.spaceM),
              padding: EdgeInsets.symmetric(
                  vertical: context.dimensions.paddingS,
                  horizontal: context.dimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(context.dimensions.radiusL),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.gift_fill,
                        color: AppColors.primary,
                        size: context.dimensions.iconSizeXS,
                      ),
                      SizedBox(width: context.dimensions.spaceXXS),
                      Text(
                        'BAŞLANGIC HEDİYESİ',
                        style: AppTextTheme.captionL.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.dimensions.spaceXXS),
                  Text(
                    item.specialOffer,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.headline4.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Güven oluşturucu etiket
          Container(
            margin: EdgeInsets.only(bottom: context.dimensions.spaceXS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.shield_fill,
                  color: Colors.grey[600],
                  size: context.dimensions.iconSizeXS,
                ),
                SizedBox(width: context.dimensions.spaceXS),
                Text(
                  'Güvenli • Hızlı • Kolay Kullanım',
                  style: AppTextTheme.captionL.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconFallback(OnboardingItem item) {
    return Container(
      decoration: BoxDecoration(
        color: item.mainColor.withOpacity(item.backgroundOpacity + 0.05),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: item.mainColor.withOpacity(0.2),
            blurRadius: context.dimensions.radiusL * 2,
            spreadRadius: context.dimensions.radiusXS,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arkaplan dekoratif şekil
          Positioned.fill(
            child: CustomPaint(
              painter: CirclePatternPainter(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Fallback ikon
          Icon(
            item.icon,
            color: Colors.white,
            size: context.dimensions.iconSizeXL,
          ),

          // 3D Efekt
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.3, 1.0],
                center: Alignment.topLeft,
                radius: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding öğesi model sınıfı
class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final double backgroundOpacity;
  final Color mainColor;
  final String? illustrationPath;
  final List<DecorationItem> bgElements;
  final List<String> premiumFeatures;
  final String pricingInfo;
  final String specialOffer;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    this.backgroundOpacity = 0.2,
    this.mainColor = AppColors.primary,
    this.illustrationPath,
    this.bgElements = const [],
    this.premiumFeatures = const [],
    this.pricingInfo = '',
    this.specialOffer = '',
  });
}

/// Dekoratif öğe modeli
class DecorationItem {
  final IconData icon;
  final double
      positionFactor; // 0.0 - 1.0 arasında ekran genişliğine oranla pozisyon
  final double size;
  final double opacity;
  final double rotationFactor; // -1.0 - 1.0 arasında bir değer

  const DecorationItem({
    required this.icon,
    required this.positionFactor,
    required this.size,
    required this.opacity,
    required this.rotationFactor,
  });

  double getSize(BuildContext context) => size;
}

/// Daire desenli özel painter
class CirclePatternPainter extends CustomPainter {
  final Color color;

  CirclePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // İç içe daireler çiz
    for (double i = 0.2; i <= 1.0; i += 0.2) {
      canvas.drawCircle(center, maxRadius * i, paint);
    }

    // Çapraz çizgiler
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height);
    path.moveTo(size.width, 0);
    path.lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
