import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/routing/route_names.dart';
import 'package:tatarai/core/services/paywall_manager.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';

/// Basit ve temiz onboarding ekranı
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'onboarding_title_1',
      description: 'onboarding_desc_1',
      icon: CupertinoIcons.heart_fill,
      color: const Color(0xFF4CAF50),
    ),
    OnboardingItem(
      title: 'onboarding_title_2',
      description: 'onboarding_desc_2',
      icon: CupertinoIcons.camera_fill,
      color: const Color(0xFF2196F3),
    ),
    OnboardingItem(
      title: 'onboarding_title_3',
      description: 'onboarding_desc_3',
      icon: CupertinoIcons.gift_fill,
      color: const Color(0xFFFF9800),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToPremium();
    }
  }

  Future<void> _goToPremium() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    bool onboardingCompleted = false;

    try {
      // Paywall'ı aç ve her durumda onboarding'i tamamla
      PaywallManager.showPaywall(
        context,
        displayCloseButton: true,
        onPremiumPurchased: () {
          if (!onboardingCompleted) {
            onboardingCompleted = true;
            if (mounted) {
              PaywallManager.showSuccessMessage(
                context,
                'premium_purchase_success'.locale(context),
              );
            }
            _completeOnboarding();
          }
        },
        onCancelled: () {
          if (!onboardingCompleted) {
            onboardingCompleted = true;
            _completeOnboarding();
          }
        },
        onError: (error) {
          if (!onboardingCompleted) {
            onboardingCompleted = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('paywall_error'.locale(context))),
              );
            }
            _completeOnboarding();
          }
        },
      );

      // Kısa bir süre bekle ve eğer hiçbir callback tetiklenmemişse onboarding'i tamamla
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!onboardingCompleted) {
        AppLogger.w('Paywall closed without any callback - completing onboarding as free user');
        onboardingCompleted = true;
        _completeOnboarding();
      }
      
    } catch (e) {
      AppLogger.e('Premium onboarding error: $e');
      if (!onboardingCompleted) {
        onboardingCompleted = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('paywall_error'.locale(context))),
          );
        }
        _completeOnboarding();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;

      final authCubit = context.read<AuthCubit>();
      await authCubit.signInAnonymously();

      if (!mounted) return;

      if (authCubit.state is AuthAuthenticated) {
        context.goNamed(RouteNames.home);
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
      AppLogger.e('Onboarding completion error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.locale(context))),
        );
        context.goNamed(RouteNames.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Container(
              padding: EdgeInsets.all(context.dimensions.paddingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(
                        horizontal: context.dimensions.spaceXXS),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == index
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildPage(item);
                },
              ),
            ),

            // Bottom button
            Padding(
              padding: EdgeInsets.all(context.dimensions.paddingL),
              child: AppButton(
                text: _currentPage == _items.length - 1
                    ? 'get_started'.locale(context)
                    : 'continue_text'.locale(context),
                onPressed: _isLoading ? null : _nextPage,
                isLoading: _isLoading,
                isFullWidth: true,
                type: AppButtonType.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item) {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              item.icon,
              size: 60,
              color: item.color,
            ),
          ),

          SizedBox(height: context.dimensions.spaceXL),

          // Title
          Text(
            item.title.locale(context),
            textAlign: TextAlign.center,
            style: AppTextTheme.headline2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: context.dimensions.spaceL),

          // Description
          Text(
            item.description.locale(context),
            textAlign: TextAlign.center,
            style: AppTextTheme.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding item model
class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
