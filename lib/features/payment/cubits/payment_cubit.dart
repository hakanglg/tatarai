import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';

part 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  // Mock data özelliğini kaldırdık

  PaymentCubit() : super(const PaymentState());

  /// Abonelik paketlerini getirir
  Future<Offerings?> fetchOfferings({bool retry = true}) async {
    try {
      emit(state.copyWith(isLoading: true, hasError: false));
      AppLogger.i('PaymentCubit: Paketler getiriliyor...');

      // RevenueCat API çağrısı
      Offerings? offerings;
      CustomerInfo? customerInfo;

      try {
        // RevenueCat'in başlatılıp başlatılmadığını kontrol et
        bool isConfigured = await Purchases.isConfigured;
        if (!isConfigured) {
          AppLogger.e(
              'PaymentCubit: RevenueCat henüz yapılandırılmamış! main.dart dosyasında initRevenueCat() çağrılmamış olabilir.');
          emit(state.copyWith(
            isLoading: false,
            hasError: true,
            errorMessage: 'RevenueCat yapılandırılmamış',
          ));
          return null;
        }

        // Paketleri getir
        offerings = await Purchases.getOfferings();

        if (offerings.all.isEmpty) {
          AppLogger.w('PaymentCubit: Hiç paket bulunamadı!');

          if (retry) {
            AppLogger.i('PaymentCubit: Paketleri yeniden getirme deneniyor...');
            // Kısa bir bekleme sonrası yeniden dene (RevenueCat'in bazı durumlarda ihtiyacı olabilir)
            await Future.delayed(const Duration(seconds: 1));
            return fetchOfferings(retry: false); // Yeniden deneme ile çağır
          }
        }

        AppLogger.i('PaymentCubit: Paketler alındı: ${offerings.all.keys}');

        if (offerings.current == null) {
          AppLogger.w('PaymentCubit: Geçerli paket (current) bulunamadı');
        } else {
          AppLogger.i(
              'PaymentCubit: Geçerli paket ID: ${offerings.current!.identifier}');
          AppLogger.i(
              'PaymentCubit: Paket içeriği: ${offerings.current!.availablePackages.length} adet paket var');

          for (final package in offerings.current!.availablePackages) {
            AppLogger.i('PaymentCubit: Paket: ${package.identifier}, '
                '${package.storeProduct.title}, ${package.storeProduct.priceString}');
          }
        }
      } catch (e) {
        AppLogger.e('PaymentCubit: Paketleri getirme hatası: $e');
        emit(state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: 'Paketler getirilemedi: ${e.toString()}',
        ));
        return null;
      }

      try {
        customerInfo = await Purchases.getCustomerInfo();
        AppLogger.i('PaymentCubit: Kullanıcı bilgileri alındı');
      } catch (e) {
        AppLogger.e('PaymentCubit: Kullanıcı bilgilerini getirme hatası: $e');
        emit(state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: 'Kullanıcı bilgileri getirilemedi',
        ));
        return offerings; // Offerings alınmışsa bile döndür
      }

      final isPremium = _checkIfUserIsPremium(customerInfo!);

      emit(state.copyWith(
        offerings: offerings,
        customerInfo: customerInfo,
        isPremium: isPremium,
        isLoading: false,
        errorMessage: null,
      ));

      AppLogger.i(
          'Paketler başarıyla alındı: ${offerings.current?.identifier}');
      return offerings;
    } catch (e) {
      AppLogger.e('Paketleri alma genel hatası: $e');
      emit(state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Bilinmeyen bir hata oluştu',
      ));

      // Otomatik yeniden deneme (sadece ilk çağrıda)
      if (retry) {
        AppLogger.i('Paketleri yeniden getirme denemesi...');
        await Future.delayed(const Duration(seconds: 2));
        return fetchOfferings(retry: false);
      }

      return null;
    }
  }

  /// Paket satın alma
  Future<void> purchasePackage(Package package) async {
    try {
      emit(state.copyWith(
          isProcessingPurchase: true, hasError: false, errorMessage: null));
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium = _checkIfUserIsPremium(customerInfo);
      emit(state.copyWith(
        customerInfo: customerInfo,
        isPremium: isPremium,
        isProcessingPurchase: false,
      ));
      AppLogger.i('Satın alma başarılı: ${package.identifier}');
    } catch (e) {
      if (e is PlatformException &&
          e.code == PurchasesErrorCode.purchaseCancelledError.name) {
        AppLogger.i('Kullanıcı satın almayı iptal etti');
        emit(state.copyWith(
          isProcessingPurchase: false,
          hasError: false,
        ));
      } else {
        AppLogger.e('Satın alma hatası: $e');
        emit(state.copyWith(
          isProcessingPurchase: false,
          hasError: true,
          errorMessage: 'Satın alma işlemi başarısız oldu',
        ));
      }
    }
  }

  /// Kullanıcının premium olup olmadığını kontrol et
  bool _checkIfUserIsPremium(CustomerInfo customerInfo) {
    // "premium" adlı bir entitlement olduğunu varsayıyoruz
    // Bu, RevenueCat konsolunda yapılandırılmalıdır
    final isEntitlementActive =
        customerInfo.entitlements.active.containsKey('premium');
    AppLogger.d(
        'PaymentCubit: _checkIfUserIsPremium - "premium" entitlement durumu: $isEntitlementActive');
    return isEntitlementActive;
  }

  /// Kullanıcının kalan analiz hakkını güncelle
  Future<void> updateRemainingAnalyses(int count) async {
    emit(state.copyWith(remainingFreeAnalyses: count));
  }
}
