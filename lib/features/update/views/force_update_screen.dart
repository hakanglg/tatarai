// lib/features/update/screens/force_update_screen.dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/update_config.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatefulWidget {
  final UpdateConfig config;

  const ForceUpdateScreen({super.key, required this.config});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _iconSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );

    _iconSlideAnimation = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 0.7, curve: Curves.elasticOut)),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchStoreUrl() async {
    final uri = Uri.parse(widget.config.storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Uygulama mağazası açılamadı. Lütfen tekrar deneyin.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradyanı
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.white,
                  AppColors.white,
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          ),

          // Üst dekoratif elemanlar
          Positioned(
            top: -100,
            right: -80,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          Positioned(
            top: 140,
            left: -100,
            child: Opacity(
              opacity: 0.07,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Ana içerik - sabit Column
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo ve ikon animasyonu
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.5),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Transform.translate(
                                offset: Offset(_iconSlideAnimation.value, 0),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.arrow_down_circle,
                                    size: 80,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // Başlık ve metin animasyonları
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                // Başlık
                                Text(
                                  'Güncelleme Gerekli',
                                  style: AppTextTheme.headline3,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                // Mesaj
                                Text(
                                  widget.config.forceUpdateMessage,
                                  style: AppTextTheme.body,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                // Alt mesaj
                                Text(
                                  'Uygulamayı kullanmaya devam etmek için lütfen en son sürüme güncelleyin.',
                                  style: AppTextTheme.captionL,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Güncelleme butonu
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.5),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SizedBox(
                              width:
                                  isSmallScreen ? screenSize.width * 0.8 : 280,
                              height: 56,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: _launchStoreUrl,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.arrow_down,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Şimdi Güncelle',
                                      style: AppTextTheme.button,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Versiyon bilgisi
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: Animation<double>.fromValueListenable(
                            _animationController,
                            transformer: (value) =>
                                value < 0.7 ? 0 : (value - 0.7) * 3.3,
                          ),
                          child: Text(
                            'Yeni sürüm: ${widget.config.latestVersion}',
                            style: AppTextTheme.captionL,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
