import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';

/// BuildContext için extension metodları
extension BuildContextExtensions on BuildContext {
  /// Paywall'ı açar
  ///
  /// [displayCloseButton] - Kapatma butonu gösterilsin mi
  /// [onComplete] - Paywall kapandığında çağrılacak fonksiyon
  Future<PaywallResult?> showPaywall({
    bool displayCloseButton = true,
    Function(PaywallResult?)? onComplete,
  }) async {
    try {
      AppLogger.i('Paywall açılıyor...');

      // Context'ten PaymentCubit'i al
      final paymentCubit = read<PaymentCubit>();
      final offerings = await paymentCubit.fetchOfferings();

      PaywallResult? result;

      if (offerings?.current != null) {
        AppLogger.i(
            'Paywall için offerings kullanılıyor: ${offerings!.current!.identifier}');
        result = await RevenueCatUI.presentPaywall(
          offering: offerings.current!,
          displayCloseButton: displayCloseButton,
        );
      } else {
        AppLogger.w('Offerings bulunamadı, varsayılan paywall gösteriliyor');
        result = await RevenueCatUI.presentPaywall(
          displayCloseButton: displayCloseButton,
        );
      }

      AppLogger.i('Paywall kapatıldı. Result: $result');

      // Callback'i çağır
      if (onComplete != null) {
        onComplete(result);
      }

      return result;
    } catch (e) {
      AppLogger.e('Paywall açılırken hata: $e');

      // Callback'i çağır (hata durumunda null ile)
      if (onComplete != null) {
        onComplete(null);
      }

      return null;
    }
  }
}
