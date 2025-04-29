import 'package:tatarai/core/base/base_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';

/// Ana sayfa durumu
class HomeState extends BaseState {
  /// Kullanıcı bilgileri
  final UserModel? user;

  /// Son analizler
  final List<PlantAnalysisResult> recentAnalyses;

  /// Başlangıç durumu
  const HomeState.initial()
      : user = null,
        recentAnalyses = const [],
        super(isLoading: false);

  /// HomeState constructor
  const HomeState({
    this.user,
    this.recentAnalyses = const [],
    super.isLoading,
    super.errorMessage,
  });

  /// Durumu kopyala
  @override
  HomeState copyWith({
    UserModel? user,
    List<PlantAnalysisResult>? recentAnalyses,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      user: user ?? this.user,
      recentAnalyses: recentAnalyses ?? this.recentAnalyses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        user,
        recentAnalyses,
        isLoading,
        errorMessage,
      ];
}
