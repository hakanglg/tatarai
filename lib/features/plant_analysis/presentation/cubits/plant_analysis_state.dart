import 'package:equatable/equatable.dart';

import '../../domain/entities/plant_analysis_entity.dart';

/// Plant Analysis State (Presentation katmanı)
///
/// UI için state management.
/// Entity'ler kullanarak temiz state yönetimi sağlar.
abstract class PlantAnalysisState extends Equatable {
  const PlantAnalysisState();

  @override
  List<Object?> get props => [];

  /// Initial state factory
  factory PlantAnalysisState.initial() => const PlantAnalysisInitial();

  /// Loading state factory
  factory PlantAnalysisState.loading({String? message}) =>
      PlantAnalysisLoading(message: message);

  /// Success state factory
  factory PlantAnalysisState.success({
    PlantAnalysisEntity? currentAnalysis,
    List<PlantAnalysisEntity>? pastAnalyses,
    String? message,
  }) =>
      PlantAnalysisSuccess(
        currentAnalysis: currentAnalysis,
        pastAnalyses: pastAnalyses ?? [],
        message: message,
      );

  /// Error state factory
  factory PlantAnalysisState.error(
    String message, {
    ErrorType? errorType,
    bool needsPremium = false,
    PlantAnalysisEntity? lastSuccessfulAnalysis,
  }) =>
      PlantAnalysisError(
        message: message,
        errorType: errorType ?? ErrorType.general,
        needsPremium: needsPremium,
        lastSuccessfulAnalysis: lastSuccessfulAnalysis,
      );

  /// Analyzing state factory (specific loading state)
  factory PlantAnalysisState.analyzing({
    String? progressMessage,
    double? progress,
  }) =>
      PlantAnalysisAnalyzing(
        progressMessage: progressMessage,
        progress: progress,
      );

  // ============================================================================
  // UTILITY GETTERS
  // ============================================================================

  /// State loading durumunda mı?
  bool get isLoading =>
      this is PlantAnalysisLoading || this is PlantAnalysisAnalyzing;

  /// State error durumunda mı?
  bool get isError => this is PlantAnalysisError;

  /// State success durumunda mı?
  bool get isSuccess => this is PlantAnalysisSuccess;

  /// State initial durumunda mı?
  bool get isInitial => this is PlantAnalysisInitial;

  /// Mevcut analiz var mı?
  bool get hasCurrentAnalysis {
    return this is PlantAnalysisSuccess &&
        (this as PlantAnalysisSuccess).currentAnalysis != null;
  }

  /// Geçmiş analizler var mı?
  bool get hasPastAnalyses {
    return this is PlantAnalysisSuccess &&
        (this as PlantAnalysisSuccess).pastAnalyses.isNotEmpty;
  }

  /// Premium gerekli mi?
  bool get needsPremium {
    return this is PlantAnalysisError &&
        (this as PlantAnalysisError).needsPremium;
  }

  /// Error message'ı al
  String? get errorMessage {
    return this is PlantAnalysisError
        ? (this as PlantAnalysisError).message
        : null;
  }

  /// Current analysis result (if any)
  PlantAnalysisEntity? get currentAnalysis => null;

  /// Past analyses list
  List<PlantAnalysisEntity> get pastAnalyses => [];
}

// ==============================================================================
// CONCRETE STATE CLASSES
// ==============================================================================

/// Başlangıç durumu
class PlantAnalysisInitial extends PlantAnalysisState {
  const PlantAnalysisInitial();

  @override
  String toString() => 'PlantAnalysisInitial()';
}

/// Genel yükleme durumu
class PlantAnalysisLoading extends PlantAnalysisState {
  /// Loading mesajı
  final String? message;

  const PlantAnalysisLoading({this.message});

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'PlantAnalysisLoading(message: $message)';
}

/// Analiz sürecinde yükleme durumu (özel progress ile)
class PlantAnalysisAnalyzing extends PlantAnalysisState {
  /// Progress mesajı
  final String? progressMessage;

  /// Progress yüzdesi (0.0-1.0)
  final double? progress;

  const PlantAnalysisAnalyzing({
    this.progressMessage,
    this.progress,
  });

  @override
  List<Object?> get props => [progressMessage, progress];

  @override
  String toString() =>
      'PlantAnalysisAnalyzing(progressMessage: $progressMessage, progress: $progress)';

  /// Progress yüzdesini int olarak döner
  int get progressPercentage =>
      progress != null ? (progress! * 100).round() : 0;

  /// Progress var mı?
  bool get hasProgress => progress != null;
}

/// Başarılı durum
class PlantAnalysisSuccess extends PlantAnalysisState {
  /// Mevcut analiz sonucu
  @override
  final PlantAnalysisEntity? currentAnalysis;

  /// Geçmiş analizler
  @override
  final List<PlantAnalysisEntity> pastAnalyses;

  /// Başarı mesajı
  final String? message;

  const PlantAnalysisSuccess({
    this.currentAnalysis,
    this.pastAnalyses = const [],
    this.message,
  });

  @override
  List<Object?> get props => [currentAnalysis, pastAnalyses, message];

  @override
  String toString() =>
      'PlantAnalysisSuccess(currentAnalysis: ${currentAnalysis?.id}, pastAnalysesCount: ${pastAnalyses.length})';

  /// Success state kopyalama
  PlantAnalysisSuccess copyWith({
    PlantAnalysisEntity? currentAnalysis,
    List<PlantAnalysisEntity>? pastAnalyses,
    String? message,
  }) {
    return PlantAnalysisSuccess(
      currentAnalysis: currentAnalysis ?? this.currentAnalysis,
      pastAnalyses: pastAnalyses ?? this.pastAnalyses,
      message: message ?? this.message,
    );
  }

  /// Past analyses'e yeni analiz ekle
  PlantAnalysisSuccess addToPastAnalyses(PlantAnalysisEntity newAnalysis) {
    final updatedPastAnalyses = [newAnalysis, ...pastAnalyses];
    return copyWith(pastAnalyses: updatedPastAnalyses);
  }

  /// Past analyses'den analiz çıkar
  PlantAnalysisSuccess removeFromPastAnalyses(String analysisId) {
    final updatedPastAnalyses =
        pastAnalyses.where((analysis) => analysis.id != analysisId).toList();
    return copyWith(pastAnalyses: updatedPastAnalyses);
  }

  /// Past analyses'i güncelle
  PlantAnalysisSuccess updatePastAnalysis(PlantAnalysisEntity updatedAnalysis) {
    final updatedPastAnalyses = pastAnalyses
        .map((analysis) =>
            analysis.id == updatedAnalysis.id ? updatedAnalysis : analysis)
        .toList();
    return copyWith(pastAnalyses: updatedPastAnalyses);
  }

  /// Toplam analiz sayısı
  int get totalAnalysesCount =>
      pastAnalyses.length + (currentAnalysis != null ? 1 : 0);

  /// Sağlıklı analiz sayısı
  int get healthyAnalysesCount {
    int count = currentAnalysis?.isHealthy == true ? 1 : 0;
    count += pastAnalyses.where((analysis) => analysis.isHealthy).length;
    return count;
  }

  /// Hastalıklı analiz sayısı
  int get unhealthyAnalysesCount => totalAnalysesCount - healthyAnalysesCount;

  /// En son analiz
  PlantAnalysisEntity? get latestAnalysis {
    if (currentAnalysis != null) return currentAnalysis;
    if (pastAnalyses.isNotEmpty) {
      final sortedAnalyses = [...pastAnalyses];
      sortedAnalyses.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });
      return sortedAnalyses.first;
    }
    return null;
  }
}

/// Hata durumu
class PlantAnalysisError extends PlantAnalysisState {
  /// Hata mesajı
  final String message;

  /// Hata tipi
  final ErrorType errorType;

  /// Premium gerekli mi?
  @override
  final bool needsPremium;

  /// Son başarılı analiz (eğer varsa)
  final PlantAnalysisEntity? lastSuccessfulAnalysis;

  /// Teknik hata detayları (debug için)
  final String? technicalDetails;

  const PlantAnalysisError({
    required this.message,
    this.errorType = ErrorType.general,
    this.needsPremium = false,
    this.lastSuccessfulAnalysis,
    this.technicalDetails,
  });

  @override
  List<Object?> get props => [
        message,
        errorType,
        needsPremium,
        lastSuccessfulAnalysis,
        technicalDetails
      ];

  @override
  String toString() =>
      'PlantAnalysisError(message: $message, errorType: $errorType, needsPremium: $needsPremium)';

  /// Error state kopyalama
  PlantAnalysisError copyWith({
    String? message,
    ErrorType? errorType,
    bool? needsPremium,
    PlantAnalysisEntity? lastSuccessfulAnalysis,
    String? technicalDetails,
  }) {
    return PlantAnalysisError(
      message: message ?? this.message,
      errorType: errorType ?? this.errorType,
      needsPremium: needsPremium ?? this.needsPremium,
      lastSuccessfulAnalysis:
          lastSuccessfulAnalysis ?? this.lastSuccessfulAnalysis,
      technicalDetails: technicalDetails ?? this.technicalDetails,
    );
  }

  /// Hata ciddi mi? (kullanıcı bir şey yapamaz)
  bool get isCriticalError {
    return errorType == ErrorType.networkError ||
        errorType == ErrorType.serverError;
  }

  /// Hata kullanıcı kaynaklı mı?
  bool get isUserError {
    return errorType == ErrorType.fileError ||
        errorType == ErrorType.validation;
  }

  /// Premium'a yönlendirme gerekli mi?
  bool get shouldShowPremium {
    return needsPremium || errorType == ErrorType.subscription;
  }
}

// ==============================================================================
// ENUMS
// ==============================================================================

/// Hata türleri
enum ErrorType {
  /// Genel hata
  general,

  /// Ağ bağlantısı hatası
  networkError,

  /// Server hatası
  serverError,

  /// Görüntü/dosya hatası
  fileError,

  /// Validasyon hatası
  validation,

  /// Abonelik/premium hatası
  subscription,

  /// AI servis/analiz hatası
  analysisFailure,

  /// Storage hatası
  storageError,

  /// Timeout hatası
  timeout,

  /// Yetkilendirme hatası
  unauthorized,

  /// Bulunamadı hatası
  notFound,

  /// Bilinmeyen hata
  unknown,

  /// API hata (Gemini AI)
  apiError,

  /// Kredi/limit hatası
  creditError,

  /// Premium abonelik gerekli
  premiumRequired;

  /// Türkçe adını döner
  String get displayName {
    switch (this) {
      case ErrorType.general:
        return 'Genel Hata';
      case ErrorType.networkError:
        return 'Bağlantı Hatası';
      case ErrorType.serverError:
        return 'Sunucu Hatası';
      case ErrorType.fileError:
        return 'Dosya Hatası';
      case ErrorType.validation:
        return 'Doğrulama Hatası';
      case ErrorType.subscription:
        return 'Abonelik Hatası';
      case ErrorType.analysisFailure:
        return 'Analiz Hatası';
      case ErrorType.storageError:
        return 'Depolama Hatası';
      case ErrorType.timeout:
        return 'Zaman Aşımı';
      case ErrorType.unauthorized:
        return 'Yetkilendirme Hatası';
      case ErrorType.notFound:
        return 'Bulunamadı';
      case ErrorType.unknown:
        return 'Bilinmeyen Hata';
      case ErrorType.apiError:
        return 'API Hatası';
      case ErrorType.creditError:
        return 'Kredi Hatası';
      case ErrorType.premiumRequired:
        return 'Premium Gerekli';
    }
  }

  /// Kullanıcı dostu açıklama
  String get description {
    switch (this) {
      case ErrorType.general:
        return 'Beklenmeyen bir hata oluştu';
      case ErrorType.networkError:
        return 'İnternet bağlantınızı kontrol edin';
      case ErrorType.serverError:
        return 'Sunucu şu anda müsait değil';
      case ErrorType.fileError:
        return 'Dosya işlenirken hata oluştu';
      case ErrorType.validation:
        return 'Girilen bilgiler geçersiz';
      case ErrorType.subscription:
        return 'Bu özellik premium üyelik gerektirir';
      case ErrorType.analysisFailure:
        return 'Analiz işlemi başarısız oldu';
      case ErrorType.storageError:
        return 'Depolama alanı yetersiz';
      case ErrorType.timeout:
        return 'İşlem zaman aşımına uğradı';
      case ErrorType.unauthorized:
        return 'Bu işlem için yetkiniz yok';
      case ErrorType.notFound:
        return 'İstenen öğe bulunamadı';
      case ErrorType.unknown:
        return 'Tanımlanamayan bir hata oluştu';
      case ErrorType.apiError:
        return 'AI servisi ile bağlantı kurulamadı';
      case ErrorType.creditError:
        return 'Günlük analiz limitiniz doldu';
      case ErrorType.premiumRequired:
        return 'Bu özellik premium üyelik gerektirir';
    }
  }

  /// Hata ikonu döner
  String get iconName {
    switch (this) {
      case ErrorType.general:
        return 'exclamationmark.triangle';
      case ErrorType.networkError:
        return 'wifi.slash';
      case ErrorType.serverError:
        return 'server.rack';
      case ErrorType.fileError:
        return 'photo.badge.exclamationmark';
      case ErrorType.validation:
        return 'checkmark.shield';
      case ErrorType.subscription:
        return 'crown';
      case ErrorType.analysisFailure:
        return 'brain';
      case ErrorType.storageError:
        return 'externaldrive.badge.exclamationmark';
      case ErrorType.timeout:
        return 'clock.badge.exclamationmark';
      case ErrorType.unauthorized:
        return 'lock.shield';
      case ErrorType.notFound:
        return 'magnifyingglass';
      case ErrorType.unknown:
        return 'questionmark.circle';
      case ErrorType.apiError:
        return 'brain.head.profile';
      case ErrorType.creditError:
        return 'creditcard.trianglebadge.exclamationmark';
      case ErrorType.premiumRequired:
        return 'crown.fill';
    }
  }

  /// Hata rengi (UI için)
  String get colorName {
    switch (this) {
      case ErrorType.general:
      case ErrorType.unknown:
        return 'gray';
      case ErrorType.networkError:
      case ErrorType.timeout:
        return 'orange';
      case ErrorType.serverError:
      case ErrorType.analysisFailure:
        return 'red';
      case ErrorType.fileError:
      case ErrorType.validation:
        return 'yellow';
      case ErrorType.subscription:
        return 'purple';
      case ErrorType.storageError:
        return 'blue';
      case ErrorType.unauthorized:
      case ErrorType.notFound:
        return 'gray';
      case ErrorType.apiError:
        return 'red';
      case ErrorType.creditError:
        return 'orange';
      case ErrorType.premiumRequired:
        return 'purple';
    }
  }
}

// ==============================================================================
// EKSİK STATE SINIFLAR - Care Advice ve Disease Recommendations için
// ==============================================================================

/// Bitki bakım tavsiyesi yüklendi durumu
class PlantAnalysisCareAdviceLoaded extends PlantAnalysisState {
  /// Bakım tavsiyesi modeli
  final dynamic careAdvice; // PlantCareAdviceModel tipinde olacak

  const PlantAnalysisCareAdviceLoaded({required this.careAdvice});

  @override
  List<Object?> get props => [careAdvice];

  @override
  String toString() => 'PlantAnalysisCareAdviceLoaded(careAdvice: $careAdvice)';
}

/// Hastalık tedavi önerileri yüklendi durumu
class PlantAnalysisDiseaseRecommendationsLoaded extends PlantAnalysisState {
  /// Hastalık tedavi önerileri modeli
  final dynamic
      diseaseRecommendations; // DiseaseRecommendationsModel tipinde olacak

  const PlantAnalysisDiseaseRecommendationsLoaded({
    required this.diseaseRecommendations,
  });

  @override
  List<Object?> get props => [diseaseRecommendations];

  @override
  String toString() =>
      'PlantAnalysisDiseaseRecommendationsLoaded(diseaseRecommendations: $diseaseRecommendations)';
}
