import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/utils/validation_util.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Plant Analysis Cubit - Bitki analizi iş mantığını yönetir
class PlantAnalysisCubit extends BaseCubit<PlantAnalysisState> {
  final PlantAnalysisRepository _repository;
  final AuthCubit _authCubit;
  final UserRepository _userRepository;
  final FirebaseAuth _firebaseAuth;

  PlantAnalysisCubit({
    required PlantAnalysisRepository repository,
    required AuthCubit authCubit,
    required UserRepository userRepository,
    required FirebaseAuth firebaseAuth,
  })  : _repository = repository,
        _authCubit = authCubit,
        _userRepository = userRepository,
        _firebaseAuth = firebaseAuth,
        super(PlantAnalysisState.initial());

  @override
  void emitErrorState(String errorMessage) {
    emit(PlantAnalysisState.error(errorMessage));
  }

  @override
  void emitLoadingState() {
    emit(PlantAnalysisState.loading());
  }

  /// Kullanıcının kredi durumunu kontrol eder
  ///
  /// Kredisi yoksa ve premium değilse, premium satın almaya yönlendirir
  /// @return bool - Analiz yapılabilir mi?
  Future<bool> checkUserCredits() async {
    logInfo('Kullanıcı kredi kontrolü yapılıyor');

    // Kullanıcı model nesnesini mevcut AuthCubit'ten al
    final UserModel? currentUser = _authCubit.state.user;

    // ValidationUtil üzerinden kullanıcı kredilerini kontrol et
    final ValidationResult result =
        await ValidationUtil.checkUserCredits(currentUser);

    if (!result.isValid) {
      AppLogger.w('Kullanıcı kredi kontrolü başarısız', result.message);
      emit(PlantAnalysisState.error(
          result.message ?? 'Analiz yapma izni alınamadı.',
          needsPremium: result.needsPremium));
      return false;
    }

    logSuccess('Kullanıcı kredi kontrolü başarılı');
    return true;
  }

  /// Analiz yapmadan önce gereken tüm kontrolleri yapar
  ///
  /// Bu metot, analiz işlemi başlatılmadan önce gereken tüm kontrolleri yapar:
  /// 1. Kullanıcı oturum açmış mı?
  /// 2. Kullanıcının analiz için yeterli kredisi var mı veya premium üye mi?
  /// 3. Gerekli dosya/bilgiler mevcut mu?
  /// 4. Bağlantı durumu uygun mu?
  ///
  /// @return bool - Analiz işlemi başlatılabilir mi?
  Future<bool> validateBeforeAnalysis(File? imageFile) async {
    logInfo('Analiz öncesi tüm kontroller yapılıyor');

    // 1. Dosya kontrolü
    final ValidationResult imageValidation =
        await ValidationUtil.validateImageFile(imageFile);
    if (!imageValidation.isValid) {
      AppLogger.w(
          'Görüntü dosyası doğrulaması başarısız', imageValidation.message);
      emit(PlantAnalysisState.error(
          imageValidation.message ?? 'Görüntü dosyası hatası',
          errorType: ErrorType.image));
      return false;
    }

    // 2. Kullanıcı oturum açmış mı ve premium/kredi durumu kontrolü
    final userValidation = await validateUserForAnalysis();
    if (!userValidation) {
      // Mesaj validateUserForAnalysis metodu içinde emit edildi
      return false;
    }

    // 3. Bağlantı durumu kontrol et
    final ValidationResult connectivityValidation =
        await ValidationUtil.checkConnectivity();
    if (!connectivityValidation.isValid) {
      AppLogger.w(
          'Bağlantı kontrolü başarısız', connectivityValidation.message);
      emit(PlantAnalysisState.error(
          connectivityValidation.message ?? 'Ağ bağlantısı hatası',
          errorType: ErrorType.network));
      return false;
    }

    logSuccess('Tüm ön kontroller başarılı, analiz başlatılabilir');
    return true;
  }

  /// Analiz yapmadan önce kullanıcının durumunu doğrular
  ///
  /// Bu metot, bir validasyon gerçekleştirir ve kullanıcının premium üye olup olmadığını
  /// veya yeterli analiz kredisi olup olmadığını kontrol eder.
  /// Eğer kullanıcı premium değilse ve analiz kredisi yoksa, uygun bir hata mesajı ile false döndürür.
  ///
  /// @return - Kullanıcı analiz yapabilir mi?
  Future<bool> validateUserForAnalysis() async {
    logInfo('Kullanıcı analiz validasyonu yapılıyor');

    try {
      // Önce AuthCubit'ten mevcut kullanıcıyı al
      final UserModel? currentUser = _authCubit.state.user;

      if (currentUser == null) {
        AppLogger.e('Analiz öncesi doğrulama: Kullanıcı oturum açmamış');
        emit(PlantAnalysisState.error('Lütfen önce giriş yapın.'));
        return false;
      }

      logInfo('AuthCubit üzerinden alınan kullanıcı bilgileri:',
          'ID: ${currentUser.id}, Premium: ${currentUser.isPremium}, Krediler: ${currentUser.analysisCredits}');

      // Önce bağlantı kontrolü yap
      final ValidationResult connectivityValidation =
          await ValidationUtil.checkConnectivity();
      if (!connectivityValidation.isValid) {
        emit(PlantAnalysisState.error(
            connectivityValidation.message ?? 'Ağ bağlantısı hatası',
            errorType: ErrorType.network));
        return false;
      }

      try {
        // UserRepository üzerinden en güncel kullanıcı bilgilerini al
        final freshUser =
            await _userRepository.fetchFreshUserData(currentUser.id);

        if (freshUser != null) {
          // ValidationUtil ile kullanıcı kontrolü yap
          final ValidationResult freshUserValidation =
              await ValidationUtil.checkUserCredits(freshUser);

          if (freshUserValidation.isValid) {
            logSuccess(
                'Güncel kullanıcı kontrolü başarılı', 'Analiz yapılabilir');
            return true;
          } else {
            emit(PlantAnalysisState.error(
                freshUserValidation.message ??
                    'Analiz için yeterli krediniz bulunmuyor.',
                needsPremium: freshUserValidation.needsPremium));
            return false;
          }
        }

        // Güncel kullanıcı bilgileri alınamadıysa, önbellekteki bilgilerle devam et
        logWarning(
            'Güncel kullanıcı bilgileri alınamadı, önbellekteki bilgilerle devam ediliyor');
      } catch (e) {
        // Hata durumunda loglama yap ama önbellekteki bilgilerle devam et
        logWarning(
            'Güncel kullanıcı bilgileri alınırken hata oluştu', e.toString());
      }

      // Önbellekteki kullanıcı bilgileriyle doğrulama
      final ValidationResult cachedUserValidation =
          await ValidationUtil.checkUserCredits(currentUser);

      if (cachedUserValidation.isValid) {
        logSuccess(
            'Önbellekteki kullanıcı kontrolü başarılı', 'Analiz yapılabilir');
        return true;
      } else {
        emit(PlantAnalysisState.error(
            cachedUserValidation.message ??
                'Analiz için yeterli krediniz bulunmuyor.',
            needsPremium: cachedUserValidation.needsPremium));
        return false;
      }
    } catch (error) {
      AppLogger.e('Kullanıcı validasyonu sırasında beklenmeyen hata', error);
      emit(PlantAnalysisState.error(
          'Kullanıcı bilgileriniz kontrol edilirken bir hata oluştu.'));
      return false;
    }
  }

  /// Bitki görüntüsünü yapay zeka ile analiz eder
  ///
  /// [imageFile] Analiz edilecek bitki görüntüsü
  /// [location] Konum bilgisi (opsiyonel)
  /// [province] İl bilgisi (opsiyonel)
  /// [district] İlçe bilgisi (opsiyonel)
  /// [neighborhood] Mahalle bilgisi (opsiyonel)
  /// [fieldName] Tarla adı (opsiyonel)
  Future<void> analyzeImage(
    File imageFile, {
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      // Önce tüm validasyon kontrollerini yap
      bool canProceed = await validateBeforeAnalysis(imageFile);
      if (!canProceed) {
        // Validasyon başarısız olduğunda, ilgili hata mesajı validateBeforeAnalysis'te emit edildi
        AppLogger.w('Analiz iptal edildi - validasyon başarısız oldu');
        return;
      }

      // Analiz başlatıldı, loading state'i yayınla
      emitLoadingState();
      AppLogger.i('Bitki analizi başlatıldı');

      if (location != null) {
        AppLogger.i('Konum: $location');
      }

      if (fieldName != null) {
        AppLogger.i('Tarla: $fieldName');
      }

      // Resmi Firebase Storage'a yükle ve URL'ini al
      final String imageUrl = await _repository.uploadImage(imageFile);
      if (imageUrl.isEmpty) {
        emit(PlantAnalysisState.error('Görüntü yüklenemedi.',
            errorType: ErrorType.image));
        return;
      }

      // Resmi analiz et - Yüklenen resmin URL'ini, konum ve tarla adını repository'ye gönder
      final result = await _repository.analyzeImage(
        imageUrl: imageUrl,
        location: location ??
            'Konum Belirtilmedi', // location null ise varsayılan değer ata
        fieldName: fieldName,
      );

      // Analiz başarılı olduysa state'i güncelle
      final allAnalyses = await _repository.getPastAnalyses();
      emit(
        PlantAnalysisState.success(allAnalyses, selectedAnalysisResult: result),
      );

      logSuccess(
        'Bitki analizi',
        'Bitki analizi tamamlandı - ID: ${result.id}',
      );
    } catch (error) {
      handleError('Bitki analizi', error);
    }
  }

  /// Kullanıcının geçmiş analizlerini yükler
  Future<void> loadPastAnalyses() async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      AppLogger.i('Geçmiş analizler yükleniyor...');
      final analysisList = await _repository.getPastAnalyses();
      AppLogger.i('${analysisList.length} adet analiz yüklendi');

      emit(
        state.copyWith(
          isLoading: false,
          analysisList: analysisList,
          errorMessage: null,
        ),
      );
    } catch (e, stack) {
      AppLogger.e('Geçmiş analizler yüklenirken hata oluştu', e, stack);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              'Analizler yüklenirken bir hata oluştu: ${e.toString()}',
        ),
      );
    }
  }

  /// Belirli bir analiz sonucunu getirir
  Future<void> getAnalysisResult(String id) async {
    if (id.isEmpty) {
      emitErrorState('Geçersiz analiz ID');
      return;
    }

    try {
      emitLoadingState();

      AppLogger.i('Cubit: getAnalysisResult çağrıldı - ID: $id');

      final result = await _repository.getAnalysisResult(id);
      if (result == null) {
        emitErrorState('Analiz sonucu bulunamadı');
        return;
      }

      AppLogger.i('Cubit: getAnalysisResult başarılı - ID: ${result.id}');

      final allAnalyses = await _repository.getPastAnalyses();
      emit(
        PlantAnalysisState.success(allAnalyses, selectedAnalysisResult: result),
      );

      logSuccess('Analiz sonucu', 'Analiz sonucu yüklendi: $id');
    } catch (error) {
      AppLogger.e('Cubit: getAnalysisResult hatası - ID: $id', error);
      handleError('Analiz sonucu', error);
    }
  }

  /// Analiz sonucunu siler
  Future<void> deleteAnalysisResult(String id) async {
    try {
      await _repository.deleteAnalysis(id);

      // Güncel analiz listesini yükle
      final pastAnalyses = await _repository.getPastAnalyses();
      emit(PlantAnalysisState.success(pastAnalyses));

      logSuccess('Analiz silme', 'Analiz silindi: $id');
    } catch (error) {
      handleError('Analiz silme', error);
    }
  }

  /// Durumu sıfırlar
  void reset() {
    emit(PlantAnalysisState.initial());
  }

  @override
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.e('$runtimeType - $operation hatası: $error', error, stackTrace);

    String errorMessage;
    ErrorType errorType = parseErrorType(error.toString());

    // Hata mesajına göre özelleştirilmiş mesajlar
    if (errorType == ErrorType.premium) {
      errorMessage = 'Premium üyelik gerekiyor. Lütfen üyeliğinizi yükseltin.';
      emit(PlantAnalysisState.error(errorMessage,
          needsPremium: true, errorType: errorType));
    } else if (errorType == ErrorType.apiKey) {
      errorMessage =
          'Servis geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.image) {
      errorMessage = 'Görüntü işlenemedi. Lütfen başka bir fotoğraf deneyin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.api) {
      errorMessage = 'Servis yanıt vermiyor. Lütfen daha sonra tekrar deneyin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.network) {
      errorMessage =
          'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.analysis) {
      errorMessage =
          'Fotoğraf analiz edilemedi. Lütfen daha net ve yakından çekilmiş bir fotoğraf deneyin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.database) {
      errorMessage = 'Veri kaydedilemedi. Lütfen daha sonra tekrar deneyin.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else if (errorType == ErrorType.auth) {
      errorMessage = 'Oturum hatası. Lütfen yeniden giriş yapın.';
      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    } else {
      // Genel hata mesajı
      errorMessage = 'İşlem sırasında bir hata oluştu. Lütfen tekrar deneyin.';

      // Hata mesajını debug modunda daha detaylı göster
      if (kDebugMode) {
        errorMessage +=
            '\nHata: ${error.toString().substring(0, error.toString().length > 50 ? 50 : error.toString().length)}...';
      }

      emit(PlantAnalysisState.error(errorMessage, errorType: errorType));
    }
  }

  /// Hata türünü belirleyen yardımcı metot
  /// Bu metot, hata mesajını analiz eder ve uygun hata türünü döndürür
  ErrorType parseErrorType(String errorMessage) {
    errorMessage = errorMessage.toLowerCase();

    // Bağlantı hatası
    if (errorMessage.contains('bağlantı') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('network') ||
        errorMessage.contains('internet') ||
        errorMessage.contains('timeout')) {
      return ErrorType.network;
    }

    // Sunucu hatası
    else if (errorMessage.contains('server') ||
        errorMessage.contains('sunucu') ||
        errorMessage.contains('503') ||
        errorMessage.contains('500')) {
      return ErrorType.server;
    }

    // Yetkilendirme hatası
    else if (errorMessage.contains('auth') ||
        errorMessage.contains('yetki') ||
        errorMessage.contains('oturum') ||
        errorMessage.contains('giriş') ||
        errorMessage.contains('login')) {
      return ErrorType.auth;
    }

    // Premium hatası
    else if (errorMessage.contains('premium')) {
      return ErrorType.premium;
    }

    // API anahtar hatası
    else if (errorMessage.contains('api anahtarı') ||
        errorMessage.contains('api key')) {
      return ErrorType.apiKey;
    }

    // Görüntü hatası
    else if (errorMessage.contains('görüntü') ||
        errorMessage.contains('image')) {
      return ErrorType.image;
    }

    // API hatası
    else if (errorMessage.contains('api')) {
      return ErrorType.api;
    }

    // JSON ayrıştırma hatası
    else if (errorMessage.contains('json') ||
        errorMessage.contains('ayrıştırılamadı')) {
      return ErrorType.analysis;
    }

    // Analiz hatası
    else if (errorMessage.contains('analiz')) {
      return ErrorType.analysis;
    }

    // Veritabanı hatası
    else if (errorMessage.contains('firebase') ||
        errorMessage.contains('firestore') ||
        errorMessage.contains('database') ||
        errorMessage.contains('veri')) {
      return ErrorType.database;
    }

    // Veri bulunamadı hatası
    else if (errorMessage.contains('bulunamadı') ||
        errorMessage.contains('not found')) {
      return ErrorType.notFound;
    }

    // Bilinmeyen hata
    return ErrorType.unknown;
  }

  /// Görüntüyü analiz eder
  Future<void> analyzeImageV2({
    required File imageFile,
    required String location,
    String? fieldName,
  }) async {
    try {
      emit(state.copyWith(status: AnalysisStatus.loading, errorMessage: null));

      // 1. Kullanıcı bilgilerini al (en güncel haliyle)
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        AppLogger.e('Analiz için kullanıcı oturumu bulunamadı.');
        emit(state.copyWith(
            status: AnalysisStatus.error, errorMessage: 'Lütfen giriş yapın.'));
        return;
      }

      AppLogger.i('Güncel kullanıcı verileri çekiliyor: ${firebaseUser.uid}');
      final UserModel? currentUser =
          await _userRepository.fetchFreshUserData(firebaseUser.uid);

      if (currentUser == null) {
        AppLogger.e('Kullanıcı bilgileri alınamadı.');
        emit(state.copyWith(
            status: AnalysisStatus.error,
            errorMessage: 'Kullanıcı bilgileriniz yüklenemedi.'));
        return;
      }
      AppLogger.i(
          'Güncel kullanıcı verileri alındı: ${currentUser.email}, Premium: ${currentUser.isPremium}, Kredi: ${currentUser.analysisCredits}');

      // 2. Kredi ve Premium durumunu kontrol et
      final validationResult =
          await ValidationUtil.checkUserCredits(currentUser);

      if (!validationResult.isValid) {
        AppLogger.w(
            'Kredi/Premium kontrolü başarısız: ${validationResult.message}');
        if (validationResult.needsPremium) {
          AppLogger.i('Paywall gösterilecek.');
          // UI'a özel bir state emit ederek paywall'u açmasını sağlayabilirsiniz.
          // PlantAnalysisState içinde showPaywall ve paywallMessage alanları olmalı.
          emit(state.copyWith(
              status: AnalysisStatus
                  .error, // Veya özel bir status: AnalysisStatus.needsPaywall
              errorMessage: validationResult.message,
              showPaywall: true,
              paywallMessage: validationResult.message));
        } else {
          emit(state.copyWith(
              status: AnalysisStatus.error,
              errorMessage: validationResult.message));
        }
        return;
      }

      AppLogger.i('Kullanıcı analiz yapabilir. Analiz işlemi başlatılıyor...');

      // Görüntü URL'sini yükle
      final imageUrl = await _repository.uploadImage(imageFile);
      if (imageUrl.isEmpty) {
        emitErrorState('Görüntü yüklenemedi.');
        return;
      }

      final result = await _repository.analyzeImage(
        imageUrl: imageUrl,
        location: location,
        fieldName: fieldName,
      );

      final allAnalyses = await _repository.getPastAnalyses();
      emit(
        PlantAnalysisState.success(allAnalyses, selectedAnalysisResult: result),
      );

      logSuccess(
        'Bitki analizi',
        'Bitki analizi tamamlandı - ID: ${result.id}',
      );
    } catch (error) {
      handleError('Bitki analizi', error);
    }
  }
}
