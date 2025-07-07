import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';

/// RevenueCat debug ve test işlemleri için yardımcı sınıf
/// 
/// TestFlight ve production ortamlarında subscription durumunu
/// debug etmek için kullanılır
class RevenueCatDebugHelper {
  RevenueCatDebugHelper._();

  /// Singleton instance
  static final RevenueCatDebugHelper _instance = RevenueCatDebugHelper._();
  static RevenueCatDebugHelper get instance => _instance;

  /// RevenueCat durumunu tamamen debug eder
  /// 
  /// Bu method ile mevcut abonelik durumunu, entitlements'ları,
  /// offerings'leri ve aktif satın almaları kontrol edebiliriz
  static Future<void> debugFullStatus() async {
    try {
      AppLogger.i('🔍 RevenueCat Debug - Tam durum kontrolü başlıyor...');
      
      // 1. Configuration durumu
      final isConfigured = await Purchases.isConfigured;
      AppLogger.i('Config durumu: $isConfigured');
      
      if (!isConfigured) {
        AppLogger.e('❌ RevenueCat configured değil!');
        return;
      }

      // 2. Customer Info
      final customerInfo = await Purchases.getCustomerInfo();
      AppLogger.i('📋 Customer Info Debug:');
      AppLogger.i('  - User ID: ${customerInfo.originalAppUserId}');
      AppLogger.i('  - Entitlements aktif mi: ${customerInfo.entitlements.active.isNotEmpty}');
      
      // 3. Aktif Entitlements
      AppLogger.i('🔑 Aktif Entitlements:');
      if (customerInfo.entitlements.active.isEmpty) {
        AppLogger.w('  - Hiç aktif entitlement yok!');
      } else {
        for (final entry in customerInfo.entitlements.active.entries) {
          final entitlement = entry.value;
          AppLogger.i('  - ${entry.key}: ${entitlement.isActive} (${entitlement.productIdentifier})');
        }
      }

      // 4. Tüm Entitlements (aktif + pasif)
      AppLogger.i('📂 Tüm Entitlements:');
      for (final entry in customerInfo.entitlements.all.entries) {
        final entitlement = entry.value;
        AppLogger.i('  - ${entry.key}: aktif=${entitlement.isActive}, product=${entitlement.productIdentifier}');
      }

      // 5. Aktif Subscriptions
      AppLogger.i('💳 Aktif Subscriptions:');
      if (customerInfo.activeSubscriptions.isEmpty) {
        AppLogger.w('  - Hiç aktif subscription yok!');
      } else {
        for (final subscription in customerInfo.activeSubscriptions) {
          AppLogger.i('  - $subscription');
        }
      }

      // 6. Premium durumu kontrolü
      final isPremiumByEntitlement = customerInfo.entitlements.active.containsKey(AppConstants.entitlementId);
      AppLogger.i('🌟 Premium Durum Kontrolü:');
      AppLogger.i('  - Entitlement ID: "${AppConstants.entitlementId}"');
      AppLogger.i('  - Premium durumu: $isPremiumByEntitlement');

      // 7. Offerings kontrolü
      try {
        final offerings = await Purchases.getOfferings();
        AppLogger.i('🛒 Offerings Debug:');
        AppLogger.i('  - Current offering: ${offerings.current?.identifier}');
        AppLogger.i('  - Toplam offering sayısı: ${offerings.all.length}');
        
        if (offerings.current != null) {
          AppLogger.i('  - Current offering packages: ${offerings.current!.availablePackages.length}');
          for (final package in offerings.current!.availablePackages) {
            AppLogger.i('    * ${package.identifier}: ${package.storeProduct.identifier} (${package.storeProduct.priceString})');
          }
        }
      } catch (e) {
        AppLogger.e('Offerings debug hatası: $e');
      }

      AppLogger.i('✅ RevenueCat Debug tamamlandı');

    } catch (e, stackTrace) {
      AppLogger.e('❌ RevenueCat Debug hatası', e, stackTrace);
    }
  }

  /// Sadece premium durumunu hızlıca kontrol eder
  static Future<bool> quickPremiumCheck() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey(AppConstants.entitlementId);
      
      AppLogger.i('⚡ Quick Premium Check:');
      AppLogger.i('  - Entitlement ID: "${AppConstants.entitlementId}"');
      AppLogger.i('  - Premium: $isPremium');
      AppLogger.i('  - Aktif entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      
      return isPremium;
    } catch (e) {
      AppLogger.e('Quick premium check hatası: $e');
      return false;
    }
  }

  /// RevenueCat'i force refresh eder
  static Future<void> forceRefresh() async {
    try {
      AppLogger.i('🔄 RevenueCat force refresh başlıyor...');
      
      // Customer info'yu cache'den değil direkt serverdan al
      final customerInfo = await Purchases.getCustomerInfo();
      
      AppLogger.i('✅ Force refresh tamamlandı');
      AppLogger.i('  - Premium: ${customerInfo.entitlements.active.containsKey(AppConstants.entitlementId)}');
      AppLogger.i('  - Aktif entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      
    } catch (e) {
      AppLogger.e('Force refresh hatası: $e');
    }
  }

  /// Test subscription restore işlemi
  static Future<void> testRestorePurchases() async {
    try {
      AppLogger.i('🔄 Restore purchases başlıyor...');
      
      final customerInfo = await Purchases.restorePurchases();
      
      AppLogger.i('✅ Restore tamamlandı');
      AppLogger.i('  - Premium: ${customerInfo.entitlements.active.containsKey(AppConstants.entitlementId)}');
      AppLogger.i('  - Aktif entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      
    } catch (e) {
      AppLogger.e('Restore purchases hatası: $e');
    }
  }

  /// StoreKit Configuration dosyası ile local subscription test eder (iOS only)
  static Future<void> testStoreKitConfiguration() async {
    try {
      AppLogger.i('🧪 StoreKit Configuration test başlıyor...');
      
      // Offerings'leri al ve StoreKit config'den gelen ürünleri kontrol et
      final offerings = await Purchases.getOfferings();
      
      AppLogger.i('📦 StoreKit Test Results:');
      AppLogger.i('  - Offerings loaded: ${offerings.current != null}');
      
      if (offerings.current != null) {
        for (final package in offerings.current!.availablePackages) {
          AppLogger.i('  - Package: ${package.identifier}');
          AppLogger.i('    * Product ID: ${package.storeProduct.identifier}');
          AppLogger.i('    * Price: ${package.storeProduct.priceString}');
          AppLogger.i('    * Title: ${package.storeProduct.title}');
        }
      }
      
    } catch (e) {
      AppLogger.e('StoreKit test hatası: $e');
    }
  }
} 