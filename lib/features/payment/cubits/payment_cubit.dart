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
      emit(
          state.copyWith(isLoading: true, hasError: false, errorMessage: null));
      AppLogger.i('PaymentCubit: Paketler getiriliyor...');

      // RevenueCat API çağrısı
      Offerings? offerings;
      CustomerInfo? customerInfo;

      try {
        // API anahtarı kontrolü
        String apiKey = Platform.isIOS
            ? AppConstants.revenueiOSApiKey
            : AppConstants
                .revenueiOSApiKey; // Şimdilik iOS anahtarını kullanıyoruz

        if (apiKey.isEmpty) {
          AppLogger.w(
              'RevenueCat API anahtarı bulunamadı. Premium özellikler devre dışı.');
          emit(state.copyWith(
            isLoading: false,
            hasError: false,
            offerings: null,
            errorMessage: 'Premium özellikler şu anda kullanılamıyor',
          ));
          return null;
        }

        // RevenueCat'in başlatılıp başlatılmadığını kontrol et
        bool isConfigured = false;
        try {
          isConfigured = await Purchases.isConfigured;
          AppLogger.i(
              'PaymentCubit: RevenueCat isConfigured durumu: $isConfigured');
        } catch (e) {
          AppLogger.w('PaymentCubit: isConfigured kontrolü başarısız: $e');
          isConfigured = false;
        }

        if (!isConfigured) {
          AppLogger.i(
              'PaymentCubit: RevenueCat henüz yapılandırılmamış! Tekrar yapılandırılıyor...');

          // RevenueCat'i tekrar yapılandırmaya çalış
          await _reconfigureRevenueCat();

          // Kısa bir bekleme sonrası tekrar kontrol et
          await Future.delayed(const Duration(milliseconds: 500));

          try {
            isConfigured = await Purchases.isConfigured;
            AppLogger.i(
                'PaymentCubit: Reconfiguration sonrası isConfigured: $isConfigured');
          } catch (e) {
            AppLogger.e(
                'PaymentCubit: Reconfiguration sonrası kontrol hatası: $e');
            isConfigured = false;
          }

          if (!isConfigured) {
            AppLogger.e('PaymentCubit: RevenueCat yapılandırılamadı');
            emit(state.copyWith(
              isLoading: false,
              hasError: true,
              errorMessage:
                  'RevenueCat yapılandırılamadı. Lütfen daha sonra tekrar deneyin.',
            ));
            return null;
          }
        }

        // Paketleri getir
        AppLogger.i('PaymentCubit: getOfferings() çağrılıyor...');

        try {
          // RevenueCat configuration debug
          AppLogger.i('PaymentCubit: RevenueCat Debug Info:');
          AppLogger.i('PaymentCubit: - isConfigured: $isConfigured');
          AppLogger.i('PaymentCubit: - API Key length: ${apiKey.length}');
          AppLogger.i('PaymentCubit: - Platform: ${Platform.operatingSystem}');

          // Customer info'yu önce kontrol et
          try {
            final debugCustomerInfo = await Purchases.getCustomerInfo();
            AppLogger.i(
                'PaymentCubit: Customer Info mevcut: ${debugCustomerInfo.originalAppUserId}');
          } catch (customerError) {
            AppLogger.w('PaymentCubit: Customer Info hatası: $customerError');
          }

          offerings = await Purchases.getOfferings();

          AppLogger.i('PaymentCubit: Offerings response:');
          AppLogger.i(
              'PaymentCubit: - All offerings count: ${offerings.all.length}');
          AppLogger.i(
              'PaymentCubit: - All offerings keys: ${offerings.all.keys.toList()}');
          AppLogger.i(
              'PaymentCubit: - Current offering: ${offerings.current?.identifier}');

          // Eğer current null ise tüm offerings'leri listele
          if (offerings.current == null) {
            AppLogger.w('PaymentCubit: Current offering NULL! Tüm offerings:');
            for (final entry in offerings.all.entries) {
              AppLogger.i(
                  'PaymentCubit: - Offering "${entry.key}": ${entry.value.availablePackages.length} packages');
              for (final package in entry.value.availablePackages) {
                AppLogger.i(
                    'PaymentCubit:   - Package: ${package.identifier} (${package.storeProduct.identifier})');
              }
            }

            // Eğer offerings varsa ama current yoksa, ilk offering'i current olarak kullan
            if (offerings.all.isNotEmpty) {
              final firstOffering = offerings.all.values.first;
              AppLogger.i(
                  'PaymentCubit: İlk offering kullanılıyor: ${firstOffering.identifier}');

              emit(state.copyWith(
                offerings: offerings,
                isLoading: false,
                hasError: false,
                errorMessage: null,
              ));
              return offerings;
            }
          }
        } catch (offeringsError) {
          AppLogger.e('PaymentCubit: getOfferings() hatası: $offeringsError');
          AppLogger.e(
              'PaymentCubit: Error type: ${offeringsError.runtimeType}');

          // PlatformException detayları
          if (offeringsError is PlatformException) {
            AppLogger.e(
                'PaymentCubit: PlatformException code: ${offeringsError.code}');
            AppLogger.e(
                'PaymentCubit: PlatformException message: ${offeringsError.message}');
            AppLogger.e(
                'PaymentCubit: PlatformException details: ${offeringsError.details}');
          }

          rethrow;
        }

        if (offerings?.current == null) {
          AppLogger.w('PaymentCubit: Aktif paket bulunamadı');

          // RevenueCat dashboard kontrol önerisi
          String detailedMessage = 'Aktif paket bulunamadı.\n\n'
              'RevenueCat Dashboard Kontrol Listesi:\n'
              '• Offerings yapılandırıldı mı?\n'
              '• Products tanımlandı mı?\n'
              '• App Store Connect\'te ürünler onaylı mı?\n'
              '• API key doğru mu?\n\n'
              'Debug: Total offerings: ${offerings?.all.length ?? 0}';

          emit(state.copyWith(
            isLoading: false,
            hasError: true,
            errorMessage: detailedMessage,
          ));
          return null;
        } else {
          AppLogger.i(
              'PaymentCubit: Geçerli paket ID: ${offerings!.current!.identifier}');
          AppLogger.i(
              'PaymentCubit: Paket içeriği: ${offerings.current!.availablePackages.length} adet paket var');

          for (final package in offerings.current!.availablePackages) {
            AppLogger.i('PaymentCubit: Paket: ${package.identifier}, '
                'Product ID: ${package.storeProduct.identifier}, '
                'Title: ${package.storeProduct.title}, '
                'Price: ${package.storeProduct.priceString}');
          }
        }
      } catch (e) {
        AppLogger.e('PaymentCubit: Paketleri getirme hatası: $e');

        // iOS 18.4 simulator sorunu kontrolü
        String errorMessage = 'Paketler getirilemedi: ${e.toString()}';
        bool isSimulatorIssue = false;

        if (e.toString().contains('iOS 18.4 simulator') ||
            e.toString().contains('StoreKit Configuration file') ||
            e.toString().contains('App Store Connect') ||
            e.toString().contains('None of the products registered')) {
          isSimulatorIssue = true;
          errorMessage = '⚠️ iOS 18.4 Simulator Sorunu!\n\n'
              'Bu sorun iOS 18.4 simulator\'da yaygındır.\n'
              'Çözümler:\n'
              '• Gerçek iOS cihazında test edin\n'
              '• Farklı iOS versiyonu (18.3 veya altı) kullanın\n'
              '• Xcode\'da StoreKit Configuration dosyasını kontrol edin\n\n'
              'Development için mock mode aktif edildi.';

          AppLogger.w('PaymentCubit: iOS 18.4 simulator sorunu tespit edildi');
          AppLogger.i('PaymentCubit: Çözüm önerileri:');
          AppLogger.i('PaymentCubit: 1. Gerçek iOS cihazında test edin');
          AppLogger.i('PaymentCubit: 2. iOS 18.3 veya altı simulator kullanın');
          AppLogger.i(
              'PaymentCubit: 3. StoreKit Configuration dosyasını kontrol edin');
          AppLogger.i(
              'PaymentCubit: 4. Mock mode aktif - development devam edebilir');
        }

        emit(state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: errorMessage,
          // iOS 18.4 simulator sorunu için mock premium state
          isPremium: isSimulatorIssue && kDebugMode ? false : false,
        ));
        return null;
      }

      // Kullanıcı bilgilerini al
      try {
        customerInfo = await Purchases.getCustomerInfo();
        AppLogger.i('PaymentCubit: Kullanıcı bilgileri alındı');
      } catch (e) {
        AppLogger.e('PaymentCubit: Kullanıcı bilgilerini getirme hatası: $e');
        // Kullanıcı bilgileri alınamazsa bile offerings'i döndür
        AppLogger.w(
            'PaymentCubit: Kullanıcı bilgileri alınamadı ama offerings mevcut');
      }

      final isPremium =
          customerInfo != null ? _checkIfUserIsPremium(customerInfo) : false;

      emit(state.copyWith(
        offerings: offerings,
        customerInfo: customerInfo,
        isPremium: isPremium,
        isLoading: false,
        hasError: false,
        errorMessage: null,
      ));

      AppLogger.i(
          'PaymentCubit: Paketler başarıyla alındı: ${offerings.current?.identifier}');
      return offerings;
    } catch (e) {
      AppLogger.e('PaymentCubit: Paketleri alma genel hatası: $e');

      emit(state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Bilinmeyen bir hata oluştu: ${e.toString()}',
      ));

      // Otomatik yeniden deneme (sadece ilk çağrıda)
      if (retry) {
        AppLogger.i('PaymentCubit: Paketleri yeniden getirme denemesi...');
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
          AppLogger.w(
              'iOS RevenueCat API anahtarı bulunamadı! .env dosyasını kontrol edin.');
          // Geçici test API anahtarı (sandbox için)
          apiKey = 'appl_test_key_placeholder';
        }
      } else if (Platform.isAndroid) {
        apiKey = AppConstants
            .revenueiOSApiKey; // Şimdilik iOS anahtarını kullanıyoruz
        if (apiKey.isEmpty) {
          AppLogger.w(
              'Android RevenueCat API anahtarı bulunamadı! .env dosyasını kontrol edin.');
          // Geçici test API anahtarı (sandbox için)
          apiKey = 'goog_test_key_placeholder';
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
    // AppConstants'dan entitlement ID'sini al
    // Bu, RevenueCat konsolunda yapılandırılmalıdır
    final isEntitlementActive = customerInfo.entitlements.active
        .containsKey(AppConstants.entitlementId);
    AppLogger.d(
        'PaymentCubit: _checkIfUserIsPremium - "${AppConstants.entitlementId}" entitlement durumu: $isEntitlementActive');
    return isEntitlementActive;
  }

  /// Kullanıcının kalan analiz hakkını güncelle
  Future<void> updateRemainingAnalyses(int count) async {
    emit(state.copyWith(remainingFreeAnalyses: count));
  }

  /// Kullanıcı bilgilerini yenile (premium satın alma sonrası)
  Future<void> refreshCustomerInfo() async {
    try {
      AppLogger.i('PaymentCubit: Kullanıcı bilgileri yenileniyor...');

      emit(state.copyWith(isLoading: true));

      // RevenueCat'ten güncel kullanıcı bilgilerini al
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = _checkIfUserIsPremium(customerInfo);

      emit(state.copyWith(
        customerInfo: customerInfo,
        isPremium: isPremium,
        isLoading: false,
        hasError: false,
        errorMessage: null,
      ));

      AppLogger.i(
          'PaymentCubit: Kullanıcı bilgileri güncellendi. Premium: $isPremium');
    } catch (e) {
      AppLogger.e('PaymentCubit: Kullanıcı bilgileri yenileme hatası: $e');
      emit(state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Kullanıcı bilgileri güncellenemedi',
      ));
    }
  }
}
