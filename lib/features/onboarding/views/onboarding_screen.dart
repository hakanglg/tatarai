import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';

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
      mainColor: const Color(0xFF2E7D32),
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
      mainColor: const Color(0xFF33691E),
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
      mainColor: const Color(0xFF1B5E20),
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
      title: 'TatarAI Premium',
      description:
          'Tam potansiyelinize ulaşın! Premium üyelikle TatarAI\'nin tüm gelişmiş özelliklerine sınırsız erişim kazanın.',
      icon: CupertinoIcons.star_fill,
      isPremium: true,
      backgroundOpacity: 0.35,
      mainColor: const Color(0xFF1B5E20),
      illustrationPath: 'assets/images/onboarding_4.png',
      premiumFeatures: [
        'Sınırsız bitki taraması ve analizi',
        'Öncelikli destek ve hızlı yanıtlar',
        'Gelişmiş hastalık teşhis raporları',
        'Kişiselleştirilmiş yetiştirme tavsiyeleri',
      ],
      pricingInfo: 'Aylık sadece \$2.99 veya yıllık \$49.99 ödeyin',
      specialOffer: 'Hemen başlayın ve %30 özel indirimden yararlanın',
      bgElements: const [
        DecorationItem(
          icon: Icons.star,
          positionFactor: 0.1,
          size: 32,
          opacity: 0.2,
          rotationFactor: 0.2,
        ),
        DecorationItem(
          icon: Icons.auto_awesome,
          positionFactor: 0.5,
          size: 28,
          opacity: 0.25,
          rotationFactor: -0.2,
        ),
        DecorationItem(
          icon: Icons.workspace_premium,
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
      AppLogger.i('Premium sayfasına yönlendiriliyor...');
      // Onboarding'i tamamlandı olarak işaretle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;

      // Premium sayfasına yönlendir
      context.goNamed(RouteNames.premium);
    } catch (e) {
      AppLogger.e('Premium sayfasına yönlendirme hatası', e);

      if (!mounted) return;

      // Hata durumunda login sayfasına yönlendir
      _redirectToLogin();
    }
  }

  Future<void> _redirectToLogin() async {
    try {
      AppLogger.i('Login sayfasına yönlendiriliyor...');
      if (!mounted) return;

      // Doğrudan giriş sayfasına git
      context.goNamed(RouteNames.login);
    } catch (e) {
      AppLogger.e('Login sayfasına yönlendirme hatası', e);
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
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingItems.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      bottom: 40.0,
                    ),
                    child: ElevatedButton(
                      onPressed: _isCompleting ? null : _onNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.mainColor,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: item.mainColor.withOpacity(0.4),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: _isCompleting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : Text(
                                  _currentPage < _onboardingItems.length - 1
                                      ? 'Devam Et'
                                      : 'Premium\'a Geç',
                                  style: AppTextTheme.button,
                                ),
                        ),
                      ),
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
                    size: decorItem.size,
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
    // Premium sayfası için özel görünüm
    if (item.isPremium) {
      return _buildPremiumPage(item, screenSize);
    }

    // Eğer premium sayfasıysa, biraz daha küçük görsel boyutu kullan
    final imageSize = screenSize.width * 0.75;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 16),

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
                      color: const Color(0xFF1B5E20),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

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
                    style: const TextStyle(
                      fontFamily: 'sfpro',
                      fontSize: 16,
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

  // Premium sayfası için özel tasarım
  Widget _buildPremiumPage(OnboardingItem item, Size screenSize) {
    final imageSize = screenSize.width * 0.48;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Premium rozeti
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade400,
                    Colors.indigo.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.sparkles,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PREMIUM',
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
                        color: const Color(0xFF1B5E20),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 24),

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
                    margin: const EdgeInsets.only(bottom: 28),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: item.illustrationPath != null &&
                            item.illustrationPath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
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

            // Premium özellikler listesi
            if (item.premiumFeatures.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            color: item.mainColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Premium Avantajları',
                          style: AppTextTheme.headline5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ...item.premiumFeatures.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C853),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: AppTextTheme.body.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            // Fiyat kartı
            if (item.pricingInfo.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E88E5),
                      const Color(0xFF1565C0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.tag_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ÖZEL FİYATLANDIRMA',
                          style: AppTextTheme.captionL.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.pricingInfo,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.headline3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (item.specialOffer.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.gift_fill,
                              color: const Color(0xFF1565C0),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.specialOffer,
                                textAlign: TextAlign.center,
                                style: AppTextTheme.captionL.copyWith(
                                  color: const Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Güven oluşturucu etiket
            Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.lock_shield_fill,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Güvenli ödeme • İstediğiniz zaman iptal',
                    style: AppTextTheme.captionL.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            blurRadius: 20,
            spreadRadius: 5,
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
            size: 80,
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
  final bool isPremium;
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
    this.isPremium = false,
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
