import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';

/// Plant Analysis Cubit - Bitki analizi iş mantığını yönetir
class PlantAnalysisCubit extends BaseCubit<PlantAnalysisState> {
  final PlantAnalysisRepository _repository;
  final AuthCubit _authCubit;
  final UserRepository _userRepository;

  PlantAnalysisCubit({
    required PlantAnalysisRepository repository,
    required AuthCubit authCubit,
    required UserRepository userRepository,
  })  : _repository = repository,
        _authCubit = authCubit,
        _userRepository = userRepository,
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
    try {
      AppLogger.i('Kullanıcı kredi kontrolü yapılıyor');

      // Kullanıcı model nesnesini mevcut AuthCubit'ten al
      final UserModel? currentUser = _authCubit.state.user;

      if (currentUser == null) {
        AppLogger.e('Kullanıcı oturum açmamış');
        emit(PlantAnalysisState.error('Kullanıcı oturum açmamış'));
        return false;
      }

      // Debug için auth state ve user bilgilerini logla
      AppLogger.i(
          'AuthCubit State: status=${_authCubit.state.status}, isLoading=${_authCubit.state.isLoading}');
      AppLogger.i(
          'UserModel: id=${currentUser.id}, isPremium=${currentUser.isPremium}, analysisCredits=${currentUser.analysisCredits}, hasAnalysisCredits=${currentUser.hasAnalysisCredits}');

      // Eğer kullanıcı premium ise veya kredisi varsa analiz yapılabilir
      if (currentUser.isPremium || currentUser.hasAnalysisCredits) {
        AppLogger.i('Kullanıcı analiz yapabilir',
            'Premium: ${currentUser.isPremium}, Kalan kredi: ${currentUser.analysisCredits}');
        return true;
      }

      // Kredisi yoksa ve premium değilse hata mesajı göster
      AppLogger.w('Kullanıcının analiz kredisi yok',
          'Premium: ${currentUser.isPremium}, Kalan kredi: ${currentUser.analysisCredits}');

      emit(PlantAnalysisState.error(
          'Ücretsiz analiz hakkınızı kullandınız. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
          needsPremium: true));

      return false;
    } catch (error) {
      AppLogger.e('Kredi kontrolü sırasında hata oluştu', error);

      // Hata durumunda analiz yapmaya izin verme
      emit(PlantAnalysisState.error(
          'Kullanıcı bilgileriniz yüklenirken bir hata oluştu. Lütfen tekrar deneyin.'));
      return false;
    }
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
    AppLogger.i('Analiz öncesi tüm kontroller yapılıyor');

    // 1. Dosya kontrolü
    if (imageFile == null || !imageFile.existsSync()) {
      AppLogger.e('Analiz için geçerli bir görüntü dosyası mevcut değil');
      emit(PlantAnalysisState.error('Lütfen geçerli bir bitki fotoğrafı seçin.',
          errorType: ErrorType.image));
      return false;
    }

    // 2. Dosya boyutu kontrolü (20MB'den büyük olmamalı)
    final fileSize = await imageFile.length();
    if (fileSize > 20 * 1024 * 1024) {
      // 20MB
      AppLogger.e(
          'Dosya boyutu çok büyük: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB');
      emit(PlantAnalysisState.error(
          'Seçilen fotoğraf çok büyük. Lütfen 20MB\'den küçük bir fotoğraf seçin.',
          errorType: ErrorType.image));
      return false;
    }

    // 3. Kullanıcı oturum açmış mı ve premium/kredi durumu kontrolü
    final userValidation = await validateUserForAnalysis();
    if (!userValidation) {
      // Mesaj validateUserForAnalysis metodu içinde emit edildi
      return false;
    }

    // 4. Bağlantı durumu kontrol et
    try {
      final bool isConnected = await _repository.checkConnectivity();
      if (!isConnected) {
        AppLogger.w('Analiz başlatılırken ağ bağlantısı bulunamadı');
        emit(PlantAnalysisState.error(
            'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
            errorType: ErrorType.network));
        return false;
      }
    } catch (e) {
      AppLogger.w('Bağlantı durumu kontrol edilirken hata oluştu: $e');
      // Bağlantı kontrolünde hata olsa bile devam etmeye çalışalım
    }

    AppLogger.i('Tüm ön kontroller başarılı, analiz başlatılabilir');
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
    AppLogger.i('Kullanıcı analiz validasyonu yapılıyor');

    try {
      // Önce AuthCubit'ten mevcut kullanıcıyı al
      final UserModel? currentUser = _authCubit.state.user;

      if (currentUser == null) {
        AppLogger.e('Analiz öncesi doğrulama: Kullanıcı oturum açmamış');
        emit(PlantAnalysisState.error('Lütfen önce giriş yapın.'));
        return false;
      }

      AppLogger.i('AuthCubit üzerinden alınan kullanıcı bilgileri:');
      AppLogger.i(
          'ID: ${currentUser.id}, Premium: ${currentUser.isPremium}, Krediler: ${currentUser.analysisCredits}');

      // UserRepository üzerinden en güncel kullanıcı bilgilerini al (önbellekten değil, Firestore'dan)
      try {
        final freshUser =
            await _userRepository.fetchFreshUserData(currentUser.id);
        if (freshUser != null) {
          AppLogger.i('Firestore\'dan alınan güncel kullanıcı bilgileri:');
          AppLogger.i(
              'ID: ${freshUser.id}, Premium: ${freshUser.isPremium}, Krediler: ${freshUser.analysisCredits}');

          // Premium kontrolü
          if (freshUser.isPremium) {
            AppLogger.i('Kullanıcı premium üye, analize devam edilebilir');
            return true;
          }

          // Kredi kontrolü - doğrudan analysisCredits değerine bak
          if (freshUser.analysisCredits > 0) {
            AppLogger.i(
                'Kullanıcının ${freshUser.analysisCredits} adet kredisi var, analize devam edilebilir');
            return true;
          } else {
            AppLogger.w(
                'Kullanıcının kredisi yok (${freshUser.analysisCredits})');

            emit(PlantAnalysisState.error(
                'Analiz yapmak için yeterli krediniz bulunmuyor. Premium üyelik satın alarak veya kredi yükleyerek analizlere devam edebilirsiniz.',
                needsPremium: true));

            return false;
          }
        }
      } catch (e) {
        AppLogger.e('Taze kullanıcı verisi getirilirken hata: $e');
        // Taze veri alınamazsa, AuthCubit'teki verileri kullan
      }

      // Buraya geldiyse, taze veriler alınamadı demektir, AuthCubit'teki verileri kullan

      // Premium üye kontrolü
      if (currentUser.isPremium) {
        AppLogger.i(
            'Analiz öncesi doğrulama: Kullanıcı premium üye, analize devam edilebilir');
        return true;
      }

      // Kredi kontrolü - doğrudan integer değerini kontrol edelim
      if (currentUser.analysisCredits > 0) {
        AppLogger.i(
            'Analiz öncesi doğrulama: Kullanıcının ${currentUser.analysisCredits} adet kredisi var, analize devam edilebilir');
        return true;
      } else {
        AppLogger.w(
            'Analiz öncesi doğrulama: Kullanıcının kredisi yok (${currentUser.analysisCredits})');

        emit(PlantAnalysisState.error(
            'Analiz yapmak için yeterli krediniz bulunmuyor. Premium üyelik satın alarak veya kredi yükleyerek analizlere devam edebilirsiniz.',
            needsPremium: true));

        return false;
      }
    } catch (e) {
      AppLogger.e('Analiz öncesi doğrulama hatası', e);
      emit(PlantAnalysisState.error(
          'Kullanıcı bilgileriniz kontrol edilirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.'));
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

      if (province != null) {
        AppLogger.i('İl: $province');
      }

      if (district != null) {
        AppLogger.i('İlçe: $district');
      }

      if (neighborhood != null) {
        AppLogger.i('Mahalle: $neighborhood');
      }

      if (fieldName != null) {
        AppLogger.i('Tarla: $fieldName');
      }

      // Resmi analiz et - Resmi, konum ve tarla adını repository'ye gönder
      final result = await _repository.analyzeImage(
        imageFile,
        location: location,
        province: province,
        district: district,
        neighborhood: neighborhood,
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
}
