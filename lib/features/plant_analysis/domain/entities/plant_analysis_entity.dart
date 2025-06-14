import 'package:equatable/equatable.dart';

import '../../data/models/disease_model.dart';

/// Bitki analizi entity (Domain katmanı)
///
/// Core business logic için kullanılan temiz entity.
/// Sadece temel analiz bilgilerini içerir.
class PlantAnalysisEntity extends Equatable {
  /// Analiz benzersiz tanımlayıcısı
  final String id;

  /// Bitki adı
  final String plantName;

  /// Tanımlama olasılığı (0-1 arası)
  final double probability;

  /// Bitkinin sağlıklı olup olmadığı
  final bool isHealthy;

  /// Tespit edilen hastalıklar
  final List<Disease> diseases;

  /// Bitki açıklaması
  final String description;

  /// Bakım ve tedavi önerileri
  final List<String> suggestions;

  /// Kullanıcının yüklediği görüntü URL'i
  final String imageUrl;

  /// Benzer bitki görüntüleri
  final List<String> similarImages;

  /// Konum bilgisi
  final String? location;

  /// Tarla adı veya konumu
  final String? fieldName;

  /// Zaman damgası
  final DateTime? timestamp;

  /// Constructor
  const PlantAnalysisEntity({
    required this.id,
    required this.plantName,
    required this.probability,
    required this.isHealthy,
    required this.diseases,
    required this.description,
    required this.suggestions,
    required this.imageUrl,
    this.similarImages = const [],
    this.location,
    this.fieldName,
    this.timestamp,
  });

  /// Entity kopyalama metodu
  PlantAnalysisEntity copyWith({
    String? id,
    String? plantName,
    double? probability,
    bool? isHealthy,
    List<Disease>? diseases,
    String? description,
    List<String>? suggestions,
    String? imageUrl,
    List<String>? similarImages,
    String? location,
    String? fieldName,
    DateTime? timestamp,
  }) {
    return PlantAnalysisEntity(
      id: id ?? this.id,
      plantName: plantName ?? this.plantName,
      probability: probability ?? this.probability,
      isHealthy: isHealthy ?? this.isHealthy,
      diseases: diseases ?? this.diseases,
      description: description ?? this.description,
      suggestions: suggestions ?? this.suggestions,
      imageUrl: imageUrl ?? this.imageUrl,
      similarImages: similarImages ?? this.similarImages,
      location: location ?? this.location,
      fieldName: fieldName ?? this.fieldName,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        id,
        plantName,
        probability,
        isHealthy,
        diseases,
        description,
        suggestions,
        imageUrl,
        similarImages,
        location,
        fieldName,
        timestamp,
      ];

  @override
  String toString() {
    return 'PlantAnalysisEntity(id: $id, plantName: $plantName, isHealthy: $isHealthy)';
  }

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /// Tanımlama güvenilirlik yüzdesi
  int get probabilityPercentage => (probability * 100).round();

  /// Hastalık sayısı
  int get diseaseCount => diseases.length;

  /// En yüksek olasılıklı hastalık
  Disease? get primaryDisease {
    if (diseases.isEmpty) return null;
    diseases.sort((a, b) => b.probability.compareTo(a.probability));
    return diseases.first;
  }

  /// Analiz geçerli mi (temel validasyon)
  bool get isValid {
    return id.isNotEmpty &&
        plantName.isNotEmpty &&
        probability >= 0.0 &&
        probability <= 1.0 &&
        imageUrl.isNotEmpty;
  }

  /// Sağlık durumu metni
  String get healthStatusText {
    if (isHealthy) {
      return 'Sağlıklı';
    } else if (diseases.isNotEmpty) {
      return '${diseases.length} hastalık tespit edildi';
    } else {
      return 'Sağlık durumu belirsiz';
    }
  }

  /// Analiz zamanı formatı
  String get formattedTimestamp {
    if (timestamp == null) return 'Belirtilmemiş';

    final now = DateTime.now();
    final difference = now.difference(timestamp!);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      final day = timestamp!.day.toString().padLeft(2, '0');
      final month = timestamp!.month.toString().padLeft(2, '0');
      final year = timestamp!.year;
      return '$day/$month/$year';
    }
  }

  /// Güvenilirlik seviyesi
  ConfidenceLevel get confidenceLevel {
    if (probability >= 0.8) return ConfidenceLevel.high;
    if (probability >= 0.6) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

/// Güvenilirlik seviyesi enum'u
enum ConfidenceLevel {
  low,
  medium,
  high;

  /// Türkçe adını döner
  String get displayName {
    switch (this) {
      case ConfidenceLevel.low:
        return 'Düşük Güvenilirlik';
      case ConfidenceLevel.medium:
        return 'Orta Güvenilirlik';
      case ConfidenceLevel.high:
        return 'Yüksek Güvenilirlik';
    }
  }

  /// Renk kodu
  String get colorCode {
    switch (this) {
      case ConfidenceLevel.low:
        return '#F44336'; // Kırmızı
      case ConfidenceLevel.medium:
        return '#FF9800'; // Turuncu
      case ConfidenceLevel.high:
        return '#4CAF50'; // Yeşil
    }
  }
}
