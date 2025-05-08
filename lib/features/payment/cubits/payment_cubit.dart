import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';

part 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit() : super(const PaymentState());

  // RevenueCat yapılandırması (sadece gerekliyse)
  // Not: Uygulama başlatılırken main.dart içinde zaten RevenueCat yapılandırılıyor
  Future<void> initPurchases() async {
    try {
      // Sadece gerekli olduğunda kullanın, normal şartlarda main.dart'ta yapılandırılıyor
      AppLogger.i('PaymentCubit: RevenueCat durumu kontrol ediliyor');

      // Mevcut kullanıcı bilgilerini al
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = _checkIfUserIsPremium(customerInfo);

      // State'i güncelle
      emit(state.copyWith(
        customerInfo: customerInfo,
        isPremium: isPremium,
      ));
    } catch (e) {
      AppLogger.e('PaymentCubit: RevenueCat kontrol hatası: $e');
    }
  }

  // Abonelik paketlerini getir
  Future<void> fetchOfferings() async {
    try {
      emit(state.copyWith(isLoading: true, hasError: false));

      AppLogger.i('PaymentCubit: Paketler getiriliyor...');

      // Daha sağlam hata yakalama ile paketleri getir
      Offerings? offerings;
      CustomerInfo? customerInfo;

      try {
        // Paketleri getir
        offerings = await Purchases.getOfferings();
        AppLogger.i('PaymentCubit: Paketler alındı: ${offerings.all.keys}');

        if (offerings.current == null) {
          AppLogger.w('PaymentCubit: Geçerli paket (current) bulunamadı');
        } else {
          AppLogger.i(
              'PaymentCubit: Geçerli paket ID: ${offerings.current!.identifier}');
          AppLogger.i(
              'PaymentCubit: Paket içeriği: ${offerings.current!.availablePackages.length} adet paket var');

          // Paketleri logla
          for (final package in offerings.current!.availablePackages) {
            AppLogger.i(
                'PaymentCubit: Paket: ${package.identifier}, ${package.storeProduct.title}, ${package.storeProduct.priceString}');
          }
        }
      } catch (e) {
        AppLogger.e('PaymentCubit: Paketleri getirme hatası: $e');
        rethrow;
      }

      try {
        // Kullanıcı bilgilerini getir
        customerInfo = await Purchases.getCustomerInfo();
        AppLogger.i('PaymentCubit: Kullanıcı bilgileri alındı');
      } catch (e) {
        AppLogger.e('PaymentCubit: Kullanıcı bilgilerini getirme hatası: $e');
        rethrow;
      }

      // Kullanıcının premium olup olmadığını kontrol et
      final isPremium = _checkIfUserIsPremium(customerInfo);

      emit(state.copyWith(
        offerings: offerings,
        customerInfo: customerInfo,
        isPremium: isPremium,
        isLoading: false,
      ));

      AppLogger.i(
          'Paketler başarıyla alındı: ${offerings.current?.identifier}');
    } catch (e) {
      AppLogger.e('Paketleri alma hatası: $e');
      // Hataya rağmen UI güncellenebilsin
      emit(state.copyWith(
        isLoading: false,
        hasError: true,
      ));

      // Tekrar denemeyi öner
      Future.delayed(const Duration(seconds: 2), () {
        AppLogger.i('Paketleri yeniden getirme denemesi...');
        fetchOfferings();
      });
    }
  }

  // Paket satın alma
  Future<void> purchasePackage(Package package) async {
    try {
      emit(state.copyWith(isProcessingPurchase: true, hasError: false));

      // Satın alma işlemini gerçekleştir
      final customerInfo = await Purchases.purchasePackage(package);

      // Kullanıcının premium olup olmadığını kontrol et
      final isPremium = _checkIfUserIsPremium(customerInfo);

      emit(state.copyWith(
        customerInfo: customerInfo,
        isPremium: isPremium,
        isProcessingPurchase: false,
      ));

      AppLogger.i('Satın alma başarılı: ${package.identifier}');
    } catch (e) {
      // Kullanıcının iptal ettiği hatayı kontrol et
      if (e is PlatformException &&
          e.code == PurchasesErrorCode.purchaseCancelledError.name) {
        AppLogger.i('Kullanıcı satın almayı iptal etti');
      } else {
        AppLogger.e('Satın alma hatası: $e');
      }

      emit(state.copyWith(
        isProcessingPurchase: false,
        hasError: true,
      ));
    }
  }

  // Kullanıcının premium olup olmadığını kontrol et
  bool _checkIfUserIsPremium(CustomerInfo customerInfo) {
    // Entitlements'ı kontrol et
    final entitlements = customerInfo.entitlements.active;

    // "premium" adlı bir entitlement olduğunu varsayıyoruz
    // Bu, RevenueCat konsolunda yapılandırılmalıdır
    return entitlements.containsKey('premium');
  }

  // Kullanıcının kalan analiz hakkını güncelle
  Future<void> updateRemainingAnalyses(int count) async {
    emit(state.copyWith(remainingFreeAnalyses: count));
  }
}
