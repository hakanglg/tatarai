import 'package:equatable/equatable.dart';

/// Bitki hastalığı modeli
class Disease extends Equatable {
  /// Hastalık adı
  final String name;

  /// Hastalık tespiti güvence oranı (0-1 arası)
  final double probability;

  /// Hastalık açıklaması
  final String description;

  /// Tedavi yöntemleri
  final List<String> treatments;

  /// Hastalığın şiddeti (hafif, orta, şiddetli)
  final DiseaseSeverity severity;

  /// Constructor
  const Disease({
    required this.name,
    required this.probability,
    required this.description,
    this.treatments = const [],
    this.severity = DiseaseSeverity.moderate,
  });

  /// JSON'dan Disease oluşturur
  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      name: json['name'] as String? ?? 'Bilinmeyen Hastalık',
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      treatments: List<String>.from(json['treatments'] as List? ?? []),
      severity: DiseaseSeverity.fromString(json['severity'] as String?),
    );
  }

  /// Disease'ı JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'probability': probability,
      'description': description,
      'treatments': treatments,
      'severity': severity.value,
    };
  }

  /// Disease kopyalama
  Disease copyWith({
    String? name,
    double? probability,
    String? description,
    List<String>? treatments,
    DiseaseSeverity? severity,
  }) {
    return Disease(
      name: name ?? this.name,
      probability: probability ?? this.probability,
      description: description ?? this.description,
      treatments: treatments ?? this.treatments,
      severity: severity ?? this.severity,
    );
  }

  @override
  List<Object?> get props =>
      [name, probability, description, treatments, severity];

  @override
  String toString() => 'Disease(name: $name, probability: $probability)';

  /// Hastalığın ciddiyetini yüzde olarak döner
  int get probabilityPercentage => (probability * 100).round();

  /// Hastalığın renkli görünümü için renk kodu
  String get severityColor {
    switch (severity) {
      case DiseaseSeverity.mild:
        return '#FFC107'; // Sarı
      case DiseaseSeverity.moderate:
        return '#FF9800'; // Turuncu
      case DiseaseSeverity.severe:
        return '#F44336'; // Kırmızı
    }
  }
}

/// Hastalık şiddeti enum'u
enum DiseaseSeverity {
  mild('mild'),
  moderate('moderate'),
  severe('severe');

  const DiseaseSeverity(this.value);
  final String value;

  /// String'den DiseaseSeverity oluşturur
  static DiseaseSeverity fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'mild':
      case 'hafif':
        return DiseaseSeverity.mild;
      case 'moderate':
      case 'orta':
        return DiseaseSeverity.moderate;
      case 'severe':
      case 'şiddetli':
        return DiseaseSeverity.severe;
      default:
        return DiseaseSeverity.moderate;
    }
  }

  /// Türkçe adını döner
  String get displayName {
    switch (this) {
      case DiseaseSeverity.mild:
        return 'Hafif';
      case DiseaseSeverity.moderate:
        return 'Orta';
      case DiseaseSeverity.severe:
        return 'Şiddetli';
    }
  }
}

/// Bitki taksonomik bilgileri modeli
class PlantTaxonomy extends Equatable {
  /// Bilimsel adı
  final String scientificName;

  /// Familya
  final String family;

  /// Genus (cins)
  final String genus;

  /// Species (tür)
  final String species;

  /// Yaygın adları
  final List<String> commonNames;

  /// Constructor
  const PlantTaxonomy({
    required this.scientificName,
    required this.family,
    required this.genus,
    required this.species,
    this.commonNames = const [],
  });

  /// JSON'dan PlantTaxonomy oluşturur
  factory PlantTaxonomy.fromJson(Map<String, dynamic> json) {
    return PlantTaxonomy(
      scientificName: json['scientific_name'] as String? ?? '',
      family: json['family'] as String? ?? '',
      genus: json['genus'] as String? ?? '',
      species: json['species'] as String? ?? '',
      commonNames: List<String>.from(json['common_names'] as List? ?? []),
    );
  }

  /// PlantTaxonomy'yi JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'scientific_name': scientificName,
      'family': family,
      'genus': genus,
      'species': species,
      'common_names': commonNames,
    };
  }

  /// PlantTaxonomy kopyalama
  PlantTaxonomy copyWith({
    String? scientificName,
    String? family,
    String? genus,
    String? species,
    List<String>? commonNames,
  }) {
    return PlantTaxonomy(
      scientificName: scientificName ?? this.scientificName,
      family: family ?? this.family,
      genus: genus ?? this.genus,
      species: species ?? this.species,
      commonNames: commonNames ?? this.commonNames,
    );
  }

  @override
  List<Object?> get props =>
      [scientificName, family, genus, species, commonNames];

  @override
  String toString() =>
      'PlantTaxonomy(scientificName: $scientificName, family: $family)';

  /// Tam taksonomik adı
  String get fullTaxonomicName {
    if (scientificName.isNotEmpty) return scientificName;
    if (genus.isNotEmpty && species.isNotEmpty) return '$genus $species';
    return genus.isNotEmpty ? genus : '';
  }

  /// Birincil yaygın ad
  String get primaryCommonName {
    return commonNames.isNotEmpty ? commonNames.first : '';
  }
}
