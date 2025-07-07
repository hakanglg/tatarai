import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart';

import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/services/paywall_manager.dart';
import 'package:tatarai/core/theme/dimensions.dart';

/// BuildContext için extension metodları
extension BuildContextExtensions on BuildContext {
  /// Paywall'ı açar (Legacy interface - geriye uyumluluk için)
  ///
  /// [displayCloseButton] - Kapatma butonu gösterilsin mi
  /// [onComplete] - Paywall kapandığında çağrılacak fonksiyon
  ///
  /// Bu method artık PaywallManager'ı kullanıyor
  Future<PaywallResult?> showPaywall({
    bool displayCloseButton = true,
    Function(PaywallResult?)? onComplete,
  }) async {
    AppLogger.i(
        'Context Extension: Legacy showPaywall çağrıldı, PaywallManager\'a yönlendiriliyor');

    return await PaywallManager.showSimplePaywall(
      this,
      onComplete: onComplete,
    );
  }
}
