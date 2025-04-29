import 'package:tatarai/core/base/base_state.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';

/// Bitki analizi durum sınıfı
class PlantAnalysisState extends BaseState {
  /// Tüm analizler
  final List<PlantAnalysisResult> analysisList;

  /// Seçili analiz
  final PlantAnalysisResult? selectedAnalysisResult;

  /// Mevcut analiz durumu
  final AnalysisStatus status;

  /// Constructor
  const PlantAnalysisState({
    this.analysisList = const [],
    this.selectedAnalysisResult,
    this.status = AnalysisStatus.initial,
    super.isLoading = false,
    super.errorMessage,
  });

  /// Başlangıç durumu
  factory PlantAnalysisState.initial() {
    return const PlantAnalysisState(
      status: AnalysisStatus.initial,
      isLoading: false,
    );
  }

  /// Yükleniyor durumu
  factory PlantAnalysisState.loading() {
    return const PlantAnalysisState(
      status: AnalysisStatus.loading,
      isLoading: true,
    );
  }

  /// Hata durumu
  factory PlantAnalysisState.error(String message) {
    return PlantAnalysisState(
      status: AnalysisStatus.error,
      errorMessage: message,
      isLoading: false,
    );
  }

  /// Analiz başarılı durumu
  factory PlantAnalysisState.success(
    List<PlantAnalysisResult> analysisList, {
    PlantAnalysisResult? selectedAnalysisResult,
  }) {
    return PlantAnalysisState(
      status: AnalysisStatus.success,
      analysisList: analysisList,
      selectedAnalysisResult: selectedAnalysisResult,
      isLoading: false,
    );
  }

  /// Mevcut durumu kopyalayarak yeni durum oluşturur
  @override
  PlantAnalysisState copyWith({
    List<PlantAnalysisResult>? analysisList,
    PlantAnalysisResult? selectedAnalysisResult,
    AnalysisStatus? status,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PlantAnalysisState(
      analysisList: analysisList ?? this.analysisList,
      selectedAnalysisResult:
          selectedAnalysisResult ?? this.selectedAnalysisResult,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        analysisList,
        selectedAnalysisResult,
        status,
      ];
}

/// Analiz durumları
enum AnalysisStatus {
  /// Başlangıç
  initial,

  /// Yükleniyor
  loading,

  /// Başarılı
  success,

  /// Hata
  error,
}
