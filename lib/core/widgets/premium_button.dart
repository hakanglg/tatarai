import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../extensions/context_extensions.dart';
import '../theme/color_scheme.dart';
import '../theme/text_theme.dart';
import '../utils/logger.dart';
import '../services/paywall_manager.dart';
import '../../features/payment/cubits/payment_cubit.dart';

/// Premium satın alma butonu
///
/// RevenueCat paywall açan genel kullanımlı button widget'ı.
/// Home ve Analysis ekranlarında kullanılabilir.
class PremiumButton extends StatelessWidget {
  /// Button metni
  final String text;

  /// Button boyutu
  final PremiumButtonSize size;

  /// Button stili
  final PremiumButtonStyle style;

  /// Callback fonksiyonu (opsiyonel)
  final VoidCallback? onPremiumPurchased;

  /// Loading durumu
  final bool isLoading;

  /// Constructor
  const PremiumButton({
    super.key,
    this.text = 'Premium Satın Al',
    this.size = PremiumButtonSize.medium,
    this.style = PremiumButtonStyle.filled,
    this.onPremiumPurchased,
    this.isLoading = false,
  });

  /// Home ekranı için özel factory
  factory PremiumButton.home({
    VoidCallback? onPremiumPurchased,
  }) =>
      PremiumButton(
        text: '⭐ Premium Ol',
        size: PremiumButtonSize.large,
        style: PremiumButtonStyle.gradient,
        onPremiumPurchased: onPremiumPurchased,
      );

  /// Analysis ekranı için özel factory
  factory PremiumButton.analysis({
    VoidCallback? onPremiumPurchased,
  }) =>
      PremiumButton(
        text: '🚀 Sınırsız Analiz',
        size: PremiumButtonSize.medium,
        style: PremiumButtonStyle.filled,
        onPremiumPurchased: onPremiumPurchased,
      );

  /// Compact button (küçük alanlar için)
  factory PremiumButton.compact({
    VoidCallback? onPremiumPurchased,
  }) =>
      PremiumButton(
        text: 'Premium',
        size: PremiumButtonSize.small,
        style: PremiumButtonStyle.outlined,
        onPremiumPurchased: onPremiumPurchased,
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, paymentState) {
        // Eğer kullanıcı zaten premium ise butonu gizle
        if (paymentState.isPremium) {
          return const SizedBox.shrink();
        }

        final isButtonLoading = isLoading || paymentState.isLoading;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: _buildButton(context, isButtonLoading),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, bool isButtonLoading) {
    switch (style) {
      case PremiumButtonStyle.gradient:
        return _buildGradientButton(context, isButtonLoading);
      case PremiumButtonStyle.filled:
        return _buildFilledButton(context, isButtonLoading);
      case PremiumButtonStyle.outlined:
        return _buildOutlinedButton(context, isButtonLoading);
    }
  }

  Widget _buildGradientButton(BuildContext context, bool isButtonLoading) {
    return Container(
      width: _getButtonWidth(),
      height: _getButtonHeight(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.info,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          onTap: isButtonLoading ? null : () => _onPressed(context),
          child: _buildButtonContent(context, isButtonLoading, Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilledButton(BuildContext context, bool isButtonLoading) {
    return SizedBox(
      width: _getButtonWidth(),
      height: _getButtonHeight(),
      child: ElevatedButton(
        onPressed: isButtonLoading ? null : () => _onPressed(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
        ),
        child: _buildButtonContent(context, isButtonLoading, Colors.white),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context, bool isButtonLoading) {
    return SizedBox(
      width: _getButtonWidth(),
      height: _getButtonHeight(),
      child: OutlinedButton(
        onPressed: isButtonLoading ? null : () => _onPressed(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
        ),
        child: _buildButtonContent(context, isButtonLoading, AppColors.primary),
      ),
    );
  }

  Widget _buildButtonContent(
    BuildContext context,
    bool isButtonLoading,
    Color textColor,
  ) {
    return Center(
      child: isButtonLoading
          ? SizedBox(
              width: _getLoadingSize(),
              height: _getLoadingSize(),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (size != PremiumButtonSize.small) ...[
                  Icon(
                    CupertinoIcons.star_fill,
                    size: _getIconSize(),
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: _getTextStyle(textColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    try {
      AppLogger.i('Premium button tıklandı');

      // PaywallManager kullanarak paywall aç
      final result = await PaywallManager.showPaywall(
        context,
        displayCloseButton: true,
        onPremiumPurchased: () {
          AppLogger.i('Paywall tamamlandı - Premium satın alındı');
          onPremiumPurchased?.call();
        },
        onCancelled: () {
          AppLogger.i('Paywall iptal edildi');
        },
        onError: (error) {
          AppLogger.e('Premium button paywall hatası: $error');
        },
      );

      AppLogger.i('Paywall sonucu: $result');
    } catch (e) {
      AppLogger.e('Premium button hatası: $e');
    }
  }

  // Helper methods for dimensions
  double? _getButtonWidth() {
    switch (size) {
      case PremiumButtonSize.small:
        return 100;
      case PremiumButtonSize.medium:
        return 200;
      case PremiumButtonSize.large:
        return double.infinity;
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case PremiumButtonSize.small:
        return 36;
      case PremiumButtonSize.medium:
        return 48;
      case PremiumButtonSize.large:
        return 56;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case PremiumButtonSize.small:
        return 18;
      case PremiumButtonSize.medium:
        return 24;
      case PremiumButtonSize.large:
        return 28;
    }
  }

  double _getIconSize() {
    switch (size) {
      case PremiumButtonSize.small:
        return 16;
      case PremiumButtonSize.medium:
        return 20;
      case PremiumButtonSize.large:
        return 24;
    }
  }

  double _getLoadingSize() {
    switch (size) {
      case PremiumButtonSize.small:
        return 16;
      case PremiumButtonSize.medium:
        return 20;
      case PremiumButtonSize.large:
        return 24;
    }
  }

  TextStyle _getTextStyle(Color color) {
    switch (size) {
      case PremiumButtonSize.small:
        return AppTextTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
      case PremiumButtonSize.medium:
        return AppTextTheme.body.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
      case PremiumButtonSize.large:
        return AppTextTheme.bodyLarge.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        );
    }
  }
}

/// Premium button boyutları
enum PremiumButtonSize {
  small,
  medium,
  large,
}

/// Premium button stilleri
enum PremiumButtonStyle {
  gradient,
  filled,
  outlined,
}
