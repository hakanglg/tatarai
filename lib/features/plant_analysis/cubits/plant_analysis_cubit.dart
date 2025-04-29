import 'dart:io';

import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';

/// Plant Analysis Cubit - Bitki analizi iş mantığını yönetir
class PlantAnalysisCubit extends BaseCubit<PlantAnalysisState> {
  final PlantAnalysisRepository _repository;

  PlantAnalysisCubit({required PlantAnalysisRepository repository})
      : _repository = repository,
        super(PlantAnalysisState.initial());

  @override
  void emitErrorState(String errorMessage) {
    emit(PlantAnalysisState.error(errorMessage));
  }

  @override
  void emitLoadingState() {
    emit(PlantAnalysisState.loading());
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
}
