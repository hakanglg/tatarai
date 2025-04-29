import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/features/home/cubits/home_state.dart';

/// Ana sayfa Cubit'i
///
class HomeCubit extends BaseCubit<HomeState> {
  /// User repository
  final UserRepository _userRepository;

  /// Plant analysis repository
  final PlantAnalysisRepository _plantAnalysisRepository;

  /// Constructor
  HomeCubit({
    required UserRepository userRepository,
    required PlantAnalysisRepository plantAnalysisRepository,
  })  : _userRepository = userRepository,
        _plantAnalysisRepository = plantAnalysisRepository,
        super(HomeState.initial());

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

      // Son analizleri al
      final recentAnalyses = await _plantAnalysisRepository.getPastAnalyses();

      emit(state.copyWith(
        user: user,
        recentAnalyses: recentAnalyses,
        isLoading: false,
      ));
    } catch (e) {
      emitErrorState(e.toString());
    }
  }
}
