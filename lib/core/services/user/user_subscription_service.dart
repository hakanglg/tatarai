import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/constants/app_constants.dart';

class UserSubscriptionService {
  Future<bool> isUserPremium() async {
    try {
      final purchaserInfo = await Purchases.getCustomerInfo();
      final entitlements = purchaserInfo.entitlements.active;
      return entitlements.containsKey(AppConstants
          .entitlementId); // RevenueCat panelinde entitlement adı neyse o
    } catch (e) {
      return false; // Hata olursa premium değil varsay
    }
  }
}
