import 'dart:io';

import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:flutter/foundation.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/user_model.dart';

/// Plant Analysis Cubit - Bitki analizi iş mantığını yönetir
class PlantAnalysisCubit extends BaseCubit<PlantAnalysisState> {
  final PlantAnalysisRepository _repository;
  final AuthCubit _authCubit;

  PlantAnalysisCubit({
    required PlantAnalysisRepository repository,
    required AuthCubit authCubit,
  })  : _repository = repository,
        _authCubit = authCubit,
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
      emitLoadingState();
      AppLogger.i('Bitki analizi başlatıldı');

      // ÖNEMLİ: En başta kullanıcı kredisini kontrol et
      bool canProceed = await checkUserCredits();
      if (!canProceed) {
        // Kullanıcı premium değilse ve kredisi yoksa analiz yapmayı durdur
        AppLogger.w('Analiz iptal edildi - kullanıcının yeterli kredisi yok');
        return;
      }

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

    // Hata mesajına göre özelleştirilmiş mesajlar
    if (error.toString().contains('premium') ||
        error.toString().contains('Premium')) {
      errorMessage = 'Premium üyelik gerekiyor. Lütfen üyeliğinizi yükseltin.';

      emit(PlantAnalysisState.error(errorMessage, needsPremium: true));
    } else if (error.toString().contains('API anahtarı')) {
      errorMessage =
          'Servis geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else if (error.toString().contains('Görüntü')) {
      errorMessage = 'Görüntü işlenemedi. Lütfen başka bir fotoğraf deneyin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else if (error.toString().contains('API')) {
      errorMessage = 'Servis yanıt vermiyor. Lütfen daha sonra tekrar deneyin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else if (error.toString().contains('ağ') ||
        error.toString().contains('internet') ||
        error.toString().contains('Network')) {
      errorMessage =
          'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else if (error.toString().contains('analiz') ||
        error.toString().contains('Analiz')) {
      errorMessage =
          'Fotoğraf analiz edilemedi. Lütfen daha net ve yakından çekilmiş bir fotoğraf deneyin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else if (error.toString().contains('Firebase') ||
        error.toString().contains('firestore')) {
      errorMessage = 'Veri kaydedilemedi. Lütfen daha sonra tekrar deneyin.';

      emit(PlantAnalysisState.error(errorMessage));
    } else {
      // Genel hata mesajı
      errorMessage = 'İşlem sırasında bir hata oluştu. Lütfen tekrar deneyin.';

      // Hata mesajını debug modunda daha detaylı göster
      if (kDebugMode) {
        errorMessage +=
            '\nHata: ${error.toString().substring(0, error.toString().length > 50 ? 50 : error.toString().length)}...';
      }

      emit(PlantAnalysisState.error(errorMessage));
    }
  }
}
