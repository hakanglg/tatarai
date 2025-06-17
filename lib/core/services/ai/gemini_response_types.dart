/// Gemini API yanıt durumları
enum GeminiResponseStatus {
  /// Başarıyla tamamlandı
  success,

  /// Kısmi başarı (bazı alanlar eksik ama kullanılabilir)
  partialSuccess,

  /// API anahtarı bulunamadı veya geçersiz
  apiKeyError,

  /// API isteği başarısız (rate limit, quota, vs.)
  apiRequestError,

  /// JSON parsing hatası
  jsonParsingError,

  /// Modelden boş yanıt geldi
  emptyResponse,

  /// Ağ bağlantısı hatası
  networkError,

  /// Genel hata
  generalError;

  /// Hata durumu mu kontrol eder
  bool get isError => this != success && this != partialSuccess;

  /// Başarılı durumu mu kontrol eder
  bool get isSuccess => this == success || this == partialSuccess;
}

/// Gemini yanıt güven seviyeleri
enum GeminiConfidenceLevel {
  /// Çok düşük güven (%0-20)
  veryLow(0.0, 0.2, 'Çok Düşük'),

  /// Düşük güven (%20-40)
  low(0.2, 0.4, 'Düşük'),

  /// Orta güven (%40-60)
  medium(0.4, 0.6, 'Orta'),

  /// Yüksek güven (%60-80)
  high(0.6, 0.8, 'Yüksek'),

  /// Çok yüksek güven (%80-100)
  veryHigh(0.8, 1.0, 'Çok Yüksek');

  const GeminiConfidenceLevel(this.minValue, this.maxValue, this.displayName);

  /// Minimum değer
  final double minValue;

  /// Maximum değer
  final double maxValue;

  /// Görüntüleme adı
  final String displayName;

  /// Güven seviyesini değerden belirler
  static GeminiConfidenceLevel fromValue(double value) {
    if (value >= 0.8) return veryHigh;
    if (value >= 0.6) return high;
    if (value >= 0.4) return medium;
    if (value >= 0.2) return low;
    return veryLow;
  }

  /// Güvenilir olup olmadığını kontrol eder (>= 60%)
  bool get isReliable => this == high || this == veryHigh;
}

/// Gemini yanıt tiplerini kategorize eder
enum GeminiResponseCategory {
  /// Görsel analizi yanıtı
  imageAnalysis('Image Analysis'),

  /// Bitki bakım tavsiyeleri yanıtı
  plantCare('Plant Care'),

  /// Hastalık tedavi önerileri yanıtı
  diseaseRecommendations('Disease Recommendations'),

  /// Genel içerik üretimi yanıtı
  generalContent('General Content'),

  /// Hızlı tanımlama yanıtı
  quickIdentification('Quick Identification');

  const GeminiResponseCategory(this.displayName);

  /// Görüntüleme adı
  final String displayName;
}

/// Gemini yanıt kalite metrikleri
class GeminiResponseQuality {
  /// Response quality constructor
  const GeminiResponseQuality({
    required this.completeness,
    required this.accuracy,
    required this.relevance,
    required this.clarity,
  });

  /// Tamlık oranı (0.0-1.0) - beklenen alanların dolu olma oranı
  final double completeness;

  /// Doğruluk oranı (0.0-1.0) - bilgilerin tutarlılık oranı
  final double accuracy;

  /// İlgililik oranı (0.0-1.0) - yanıtın soruyla ne kadar ilgili olduğu
  final double relevance;

  /// Netlik oranı (0.0-1.0) - yanıtın ne kadar anlaşılır olduğu
  final double clarity;

  /// Genel kalite skoru (ortalama)
  double get overallScore =>
      (completeness + accuracy + relevance + clarity) / 4.0;

  /// Kalite seviyesini döndürür
  GeminiConfidenceLevel get qualityLevel =>
      GeminiConfidenceLevel.fromValue(overallScore);

  /// Yüksek kaliteli mi kontrol eder
  bool get isHighQuality => overallScore >= 0.7;

  /// Factory constructor - varsayılan değerler ile
  factory GeminiResponseQuality.defaultQuality() {
    return const GeminiResponseQuality(
      completeness: 0.8,
      accuracy: 0.8,
      relevance: 0.8,
      clarity: 0.8,
    );
  }

  /// Factory constructor - düşük kalite için
  factory GeminiResponseQuality.lowQuality() {
    return const GeminiResponseQuality(
      completeness: 0.3,
      accuracy: 0.3,
      relevance: 0.3,
      clarity: 0.3,
    );
  }

  /// Copy with method
  GeminiResponseQuality copyWith({
    double? completeness,
    double? accuracy,
    double? relevance,
    double? clarity,
  }) {
    return GeminiResponseQuality(
      completeness: completeness ?? this.completeness,
      accuracy: accuracy ?? this.accuracy,
      relevance: relevance ?? this.relevance,
      clarity: clarity ?? this.clarity,
    );
  }

  @override
  String toString() {
    return 'GeminiResponseQuality(overall: ${(overallScore * 100).toStringAsFixed(1)}%, '
        'completeness: ${(completeness * 100).toStringAsFixed(1)}%, '
        'accuracy: ${(accuracy * 100).toStringAsFixed(1)}%, '
        'relevance: ${(relevance * 100).toStringAsFixed(1)}%, '
        'clarity: ${(clarity * 100).toStringAsFixed(1)}%)';
  }
}

/// Gemini API yanıt wrapper sınıfı
///
/// Tüm Gemini yanıtlarını standardize eder ve metadata ekler
class GeminiResponse<T> {
  /// Response constructor
  GeminiResponse({
    required this.status,
    required this.category,
    this.data,
    this.rawResponse,
    this.quality,
    this.errorMessage,
    this.metadata = const {},
    DateTime? timestamp,
    Duration? processingTime,
  })  : timestamp = timestamp ?? DateTime.now(),
        processingTime = processingTime ?? Duration.zero;

  /// Yanıt durumu
  final GeminiResponseStatus status;

  /// Yanıt kategorisi
  final GeminiResponseCategory category;

  /// Parse edilmiş data (T tipinde)
  final T? data;

  /// Ham API yanıtı
  final String? rawResponse;

  /// Yanıt kalite metrikleri
  final GeminiResponseQuality? quality;

  /// Hata mesajı (varsa)
  final String? errorMessage;

  /// Ek metadata bilgileri
  final Map<String, dynamic> metadata;

  /// Yanıt timestamp'i
  final DateTime timestamp;

  /// İşlem süresi
  final Duration processingTime;

  /// Başarılı mı kontrol eder
  bool get isSuccess => status.isSuccess && data != null;

  /// Hata durumu mu kontrol eder
  bool get isError => status.isError;

  /// Yüksek kaliteli mi kontrol eder
  bool get isHighQuality => quality?.isHighQuality ?? false;

  /// Güvenilir mi kontrol eder
  bool get isReliable => quality?.qualityLevel.isReliable ?? false;

  /// Factory constructor - başarılı yanıt için
  factory GeminiResponse.success({
    required GeminiResponseCategory category,
    required T data,
    String? rawResponse,
    GeminiResponseQuality? quality,
    Map<String, dynamic> metadata = const {},
    Duration? processingTime,
  }) {
    return GeminiResponse<T>(
      status: GeminiResponseStatus.success,
      category: category,
      data: data,
      rawResponse: rawResponse,
      quality: quality ?? GeminiResponseQuality.defaultQuality(),
      metadata: metadata,
      timestamp: DateTime.now(),
      processingTime: processingTime,
    );
  }

  /// Factory constructor - kısmi başarı için
  factory GeminiResponse.partialSuccess({
    required GeminiResponseCategory category,
    required T data,
    String? rawResponse,
    GeminiResponseQuality? quality,
    String? warningMessage,
    Map<String, dynamic> metadata = const {},
    Duration? processingTime,
  }) {
    return GeminiResponse<T>(
      status: GeminiResponseStatus.partialSuccess,
      category: category,
      data: data,
      rawResponse: rawResponse,
      quality: quality ?? GeminiResponseQuality.lowQuality(),
      errorMessage: warningMessage,
      metadata: metadata,
      timestamp: DateTime.now(),
      processingTime: processingTime,
    );
  }

  /// Factory constructor - hata yanıtı için
  factory GeminiResponse.error({
    required GeminiResponseCategory category,
    required GeminiResponseStatus status,
    required String errorMessage,
    String? rawResponse,
    T? fallbackData,
    Map<String, dynamic> metadata = const {},
    Duration? processingTime,
  }) {
    assert(status.isError, 'Error status must be an error status');

    return GeminiResponse<T>(
      status: status,
      category: category,
      data: fallbackData,
      rawResponse: rawResponse,
      errorMessage: errorMessage,
      metadata: metadata,
      timestamp: DateTime.now(),
      processingTime: processingTime,
    );
  }

  /// Copy with method
  GeminiResponse<T> copyWith({
    GeminiResponseStatus? status,
    GeminiResponseCategory? category,
    T? data,
    String? rawResponse,
    GeminiResponseQuality? quality,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    Duration? processingTime,
  }) {
    return GeminiResponse<T>(
      status: status ?? this.status,
      category: category ?? this.category,
      data: data ?? this.data,
      rawResponse: rawResponse ?? this.rawResponse,
      quality: quality ?? this.quality,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      processingTime: processingTime ?? this.processingTime,
    );
  }

  @override
  String toString() {
    return 'GeminiResponse<$T>('
        'status: ${status.name}, '
        'category: ${category.name}, '
        'hasData: ${data != null}, '
        'quality: ${quality?.overallScore.toStringAsFixed(2)}, '
        'processingTime: ${processingTime.inMilliseconds}ms'
        ')';
  }
}
