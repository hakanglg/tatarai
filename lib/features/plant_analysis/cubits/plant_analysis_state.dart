import 'package:tatarai/core/base/base_state.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';

/// Hata türleri
enum ErrorType {
  /// Ağ bağlantısı hatası
  network,

  /// Sunucu hatası
  server,

  /// Kimlik doğrulama hatası
  auth,

  /// Premium hesap gerekiyor
  premium,

  /// API anahtarı hatası
  apiKey,

  /// Görüntü işleme hatası
  image,

  /// API hatası
  api,

  /// Analiz hatası
  analysis,

  /// Veritabanı hatası
  database,

  /// Veri bulunamadı
  notFound,

  /// Bilinmeyen hata
  unknown,
}

/// Bitki analizi durum sınıfı
class PlantAnalysisState extends BaseState {
  /// Tüm analizler
  final List<PlantAnalysisResult> analysisList;

  /// Seçili analiz
  final PlantAnalysisResult? selectedAnalysisResult;

  /// Mevcut analiz durumu
  final AnalysisStatus status;

  /// Premium özellik mi gerekiyor
  final bool needsPremium;

  /// Hata türü
  final ErrorType? errorType;

  /// Constructor
  const PlantAnalysisState({
    this.analysisList = const [],
    this.selectedAnalysisResult,
    this.status = AnalysisStatus.initial,
    super.isLoading = false,
    super.errorMessage,
    this.needsPremium = false,
    this.errorType,
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
  factory PlantAnalysisState.error(String message,
      {bool needsPremium = false, ErrorType errorType = ErrorType.unknown}) {
    return PlantAnalysisState(
      status: AnalysisStatus.error,
      errorMessage: message,
      isLoading: false,
      needsPremium: needsPremium,
      errorType: errorType,
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
    bool? needsPremium,
    ErrorType? errorType,
  }) {
    return PlantAnalysisState(
      analysisList: analysisList ?? this.analysisList,
      selectedAnalysisResult:
          selectedAnalysisResult ?? this.selectedAnalysisResult,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      needsPremium: needsPremium ?? this.needsPremium,
      errorType: errorType ?? this.errorType,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        analysisList,
        selectedAnalysisResult,
        status,
        needsPremium,
        errorType,
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
