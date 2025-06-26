import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';
import 'package:tatarai/core/extensions/string_extension.dart';

/// Merkezi Paywall yönetim sınıfı
///
/// Tüm paywall açma işlemlerini tek yerden yönetir.
/// Tutarlı error handling ve logging sağlar.
///
/// Özellikler:
/// - Merkezi paywall yönetimi
/// - Tutarlı error handling
/// - Detaylı logging
/// - Callback desteği
/// - Context validation
/// - Premium upgrade tracking
class PaywallManager {
  PaywallManager._();

  /// Singleton instance
  static final PaywallManager _instance = PaywallManager._();
  static PaywallManager get instance => _instance;

  /// Paywall'ı açar
  ///
  /// [context] - Widget context (gerekli)
  /// [displayCloseButton] - Kapatma butonu gösterilsin mi
  /// [onPremiumPurchased] - Premium satın alındığında çağrılacak callback
  /// [onError] - Hata durumunda çağrılacak callback
  /// [onCancelled] - İptal durumunda çağrılacak callback
  ///
  /// Returns: PaywallResult veya null
  static Future<PaywallResult?> showPaywall(
    BuildContext context, {
    bool displayCloseButton = true,
    VoidCallback? onPremiumPurchased,
    Function(String error)? onError,
    VoidCallback? onCancelled,
  }) async {
    try {
      AppLogger.i('🎯 PaywallManager: Paywall açılıyor...');

      // Context validation
      if (!context.mounted) {
        const error = 'Context artık mounted değil';
        AppLogger.w('PaywallManager: $error');
        onError?.call(error);
        return null;
      }

      // PaymentCubit validation
      PaymentCubit? paymentCubit;
      try {
        paymentCubit = context.read<PaymentCubit>();
        AppLogger.i('PaywallManager: PaymentCubit context\'ten alındı');
      } catch (e) {
        final error = 'PaymentCubit context\'ten alınamadı: $e';
        AppLogger.e('PaywallManager: $error');
        _showErrorSnackBar(
            context, 'Ödeme sistemi kullanılamıyor. Mock mode deneyin.');
        onError?.call(error);
        return null;
      }

      // Offerings fetch
      final offerings = await paymentCubit.fetchOfferings();
      AppLogger.i(
          'PaywallManager: Offerings durumu: ${offerings?.current?.identifier}');

      PaywallResult? result;

      if (offerings?.current != null) {
        AppLogger.i(
            'PaywallManager: Paywall gösteriliyor - Offering: ${offerings!.current!.identifier}');

        try {
          result = await RevenueCatUI.presentPaywall(
            offering: offerings.current!,
            displayCloseButton: displayCloseButton,
          );

          AppLogger.i('PaywallManager: Paywall sonucu: $result');

          // Result handling
          if (result != null) {
            AppLogger.i('PaywallManager: Premium satın alma başarılı');

            // Premium satın alma sonrası kullanıcı bilgilerini yenile
            try {
              await paymentCubit.refreshCustomerInfo();
              AppLogger.i('PaywallManager: Kullanıcı bilgileri güncellendi');
            } catch (e) {
              AppLogger.e(
                  'PaywallManager: Kullanıcı bilgilerini güncelleme hatası: $e');
            }

            onPremiumPurchased?.call();
          } else {
            AppLogger.i('PaywallManager: Kullanıcı paywall\'ı iptal etti');
            onCancelled?.call();
          }
        } catch (paywallError) {
          final error = 'Paywall gösterilirken hata: $paywallError';
          AppLogger.e('PaywallManager: $error');
          _showErrorSnackBar(
              context, 'Paywall açılamadı. Lütfen daha sonra tekrar deneyin.');
          onError?.call(error);
          return null;
        }
      } else {
        const error =
            'Offerings bulunamadı. Premium özellikler şu anda kullanılamıyor.';
        AppLogger.w('PaywallManager: $error');
        _showErrorSnackBar(
            context, 'Premium özellikler şu anda kullanılamıyor.');
        onError?.call(error);
        return null;
      }

      return result;
    } catch (e, stackTrace) {
      final error = 'Paywall açılırken genel hata: $e';
      AppLogger.e('PaywallManager: $error', e, stackTrace);
      _showErrorSnackBar(context,
          'Beklenmeyen hata oluştu. Lütfen daha sonra tekrar deneyin.');
      onError?.call(error);
      return null;
    }
  }

  /// Basit paywall açma (geriye uyumluluk için)
  ///
  /// [context] - Widget context
  /// [onComplete] - Paywall tamamlandığında çağrılacak callback
  ///
  /// Returns: PaywallResult veya null
  static Future<PaywallResult?> showSimplePaywall(
    BuildContext context, {
    Function(PaywallResult?)? onComplete,
  }) async {
    return await showPaywall(
      context,
      onPremiumPurchased: () {
        AppLogger.i('PaywallManager: Simple paywall - Premium satın alındı');
        onComplete?.call(PaywallResult.purchased);
      },
      onCancelled: () {
        AppLogger.i('PaywallManager: Simple paywall - İptal edildi');
        onComplete?.call(null);
      },
      onError: (error) {
        AppLogger.e('PaywallManager: Simple paywall - Hata: $error');
        onComplete?.call(null);
      },
    );
  }

  /// Premium gereklilik kontrolü
  ///
  /// PaymentCubit'ten premium durumunu kontrol eder
  ///
  /// [context] - Widget context
  /// Returns: Kullanıcı premium mi?
  static bool isPremiumUser(BuildContext context) {
    try {
      final paymentCubit = context.read<PaymentCubit>();
      final isPremium = paymentCubit.state.isPremium;
      AppLogger.d('PaywallManager: Premium durum kontrolü: $isPremium');
      return isPremium;
    } catch (e) {
      AppLogger.e('PaywallManager: Premium durum kontrolü hatası: $e');
      return false;
    }
  }

  /// Premium gerekli mi kontrolü ve otomatik paywall açma
  ///
  /// Eğer kullanıcı premium değilse paywall açar
  ///
  /// [context] - Widget context
  /// [onPremiumConfirmed] - Premium durumu onaylandığında çağrılacak callback
  /// [onPremiumRequired] - Premium gerekli durumunda çağrılacak callback
  ///
  /// Returns: Premium durumu
  static Future<bool> checkPremiumAndShowPaywall(
    BuildContext context, {
    VoidCallback? onPremiumConfirmed,
    VoidCallback? onPremiumRequired,
  }) async {
    final isPremium = isPremiumUser(context);

    if (isPremium) {
      AppLogger.i('PaywallManager: Kullanıcı zaten premium');
      onPremiumConfirmed?.call();
      return true;
    } else {
      AppLogger.i('PaywallManager: Premium gerekli, paywall açılıyor');
      onPremiumRequired?.call();

      final result = await showPaywall(
        context,
        onPremiumPurchased: () {
          AppLogger.i(
              'PaywallManager: Premium satın alındı, callback çağrılıyor');
          onPremiumConfirmed?.call();
        },
      );

      return result != null;
    }
  }

  /// Error snackbar göster (private helper)
  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.e('PaywallManager: SnackBar gösterilirken hata: $e');
    }
  }

  /// Success snackbar göster (premium satın alma sonrası)
  static void showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      AppLogger.i('PaywallManager: Success message gösterildi: $message');
    } catch (e) {
      AppLogger.e('PaywallManager: Success SnackBar gösterilirken hata: $e');
    }
  }
}
