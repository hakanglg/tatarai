import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'dart:io';

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
              'PaymentCubit: RevenueCat henüz yapılandırılmamış! Tekrar yapılandırılmaya çalışılacak.');

          // RevenueCat'i tekrar yapılandırmaya çalış
          await _reconfigureRevenueCat();

          // Tekrar kontrol et
          isConfigured = await Purchases.isConfigured;
          if (!isConfigured) {
            emit(state.copyWith(
              isLoading: false,
              hasError: true,
              errorMessage: 'RevenueCat yapılandırılamadı',
            ));
            return null;
          }
        }

        // Paketleri getir
        AppLogger.i('PaymentCubit: getOfferings() çağrılıyor...');
        try {
          offerings = await Purchases.getOfferings();
          AppLogger.i('>> Offerings All: ${offerings.all}');
          AppLogger.i('>> Current Offering: ${offerings.current}');

          AppLogger.i('TEST Offerings: ${offerings.all}');
          AppLogger.i(
              'TEST Current offering: ${offerings.current?.identifier}');
        } catch (offeringsError) {
          AppLogger.e('PaymentCubit: getOfferings() hatası: $offeringsError');

          if (retry) {
            // Kısa bir bekleme sonrası RevenueCat'i yeniden yapılandır ve tekrar dene
            await Future.delayed(const Duration(milliseconds: 500));
            await _reconfigureRevenueCat();
            return fetchOfferings(retry: false);
          } else {
            rethrow;
          }
        }

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

      final isPremium = _checkIfUserIsPremium(customerInfo);

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
        errorMessage: 'Bilinmeyen bir hata oluştu: ${e.toString()}',
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

  /// RevenueCat'i yeniden yapılandırır
  Future<void> _reconfigureRevenueCat() async {
    try {
      AppLogger.i('RevenueCat yeniden yapılandırılıyor...');

      // API anahtarını al
      String apiKey = '';
      if (Platform.isIOS) {
        apiKey = AppConstants.revenueiOSApiKey;
        if (apiKey.isEmpty) {
          throw Exception('iOS RevenueCat API anahtarı bulunamadı!');
        }
      } else if (Platform.isAndroid) {
        apiKey = AppConstants
            .revenueiOSApiKey; // Şimdilik iOS anahtarını kullanıyoruz
        if (apiKey.isEmpty) {
          throw Exception('Android RevenueCat API anahtarı bulunamadı!');
        }
      } else {
        throw Exception('Desteklenmeyen platform!');
      }

      // RevenueCat'i yapılandır
      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);

      // StoreKit Configuration dosyası ile ilgili log kaydı
      if (Platform.isIOS) {
        AppLogger.i(
            'RevenueCat: StoreKit yapılandırma dosyası kullanılıyor (TatarAI.storekit)');
      }

      await Purchases.configure(configuration);
      AppLogger.i('RevenueCat yeniden yapılandırma başarılı');

      // Debug logları etkinleştir
      await Purchases.setLogLevel(LogLevel.debug);

      // Sandbox modda yardımcı seçenekleri ayarla
      if (Platform.isIOS) {
        try {
          await Purchases.setSimulatesAskToBuyInSandbox(true);
          AppLogger.i('RevenueCat: iOS için sandbox ayarları yapılandırıldı');

          // RevenueCat özel ayarları
          await Purchases.setAttributes({
            'platform': 'iOS',
            'app_version': AppConstants.appVersion,
            'using_storekit_config': 'true',
          });

          AppLogger.i('RevenueCat: Özel özellikler ayarlandı');
        } catch (e) {
          AppLogger.w('RevenueCat: iOS için ek seçenekler ayarlanamadı: $e');
        }
      }
    } catch (e) {
      AppLogger.e('RevenueCat yeniden yapılandırma hatası: $e');
      rethrow;
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
