import 'dart:async';

import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/features/home/cubits/home_state.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Ana sayfa Cubit'i
///
class HomeCubit extends BaseCubit<HomeState> {
  /// User repository
  final UserRepository _userRepository;

  /// Plant analysis repository
  final PlantAnalysisRepository _plantAnalysisRepository;

  /// Stream aboneliği
  StreamSubscription<List<PlantAnalysisResult>>? _analysesSubscription;

  /// Constructor
  HomeCubit({
    required UserRepository userRepository,
    required PlantAnalysisRepository plantAnalysisRepository,
  })  : _userRepository = userRepository,
        _plantAnalysisRepository = plantAnalysisRepository,
        super(HomeState.initial()) {
    // Stream'i başlat
    _startAnalysesStream();
  }

  @override
  void emitErrorState(String errorMessage) {
    emit(state.copyWith(
      errorMessage: errorMessage,
      isLoading: false,
    ));
  }

  @override
  void emitLoadingState() {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
    ));
  }

  /// Ana sayfayı yenile
  Future<void> refresh() async {
    try {
      emitLoadingState();

      // Kullanıcı verilerini al
      final user = await _userRepository.getCurrentUser();

      emit(state.copyWith(
        user: user,
        isLoading: false,
      ));
    } catch (e) {
      emitErrorState(e.toString());
    }
  }

  /// Analizleri gerçek zamanlı olarak dinle
  void _startAnalysesStream() {
    try {
      // Önceki subscription varsa kapat
      _analysesSubscription?.cancel();

      // Yeni subscription oluştur
      _analysesSubscription =
          _plantAnalysisRepository.streamUserAnalyses().listen((analyses) {
        emit(state.copyWith(
          recentAnalyses: analyses,
          isLoading: false,
        ));
      }, onError: (error) {
        AppLogger.e('Analizleri dinleme hatası', error.toString());
        emitErrorState('Analizleri güncellerken bir hata oluştu: $error');
      });
    } catch (e) {
      AppLogger.e('Stream başlatma hatası', e.toString());
      emitErrorState('Stream başlatılamadı: $e');
    }
  }

  @override
  Future<void> close() {
    // Stream aboneliğini kapat
    _analysesSubscription?.cancel();
    return super.close();
  }
}
