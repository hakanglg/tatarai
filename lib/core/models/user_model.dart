import 'package:equatable/equatable.dart';

/// Kullanıcı veri modeli
///
/// Anonim kullanıcılar için basitleştirilmiş kullanıcı veri yapısı.
/// Firebase Authentication ile uyumlu minimal kullanıcı bilgileri içerir.
class UserModel extends Equatable {
  /// Kullanıcının benzersiz kimliği (Firebase UID)
  final String id;

  /// Kullanıcının görünen adı
  final String name;

  /// Kullanıcının sahip olduğu analiz kredisi sayısı
  final int analysisCredits;

  /// Kullanıcının premium üye olup olmadığı
  final bool isPremium;

  /// Hesap oluşturulma tarihi
  final DateTime createdAt;

  /// Son güncelleme tarihi
  final DateTime updatedAt;

  /// Constructor
  const UserModel({
    required this.id,
    required this.name,
    this.analysisCredits = 5,
    this.isPremium = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Anonim kullanıcı oluşturucu factory
  factory UserModel.anonymous({
    required String id,
    String? name,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      name: name ?? 'Misafir Kullanıcı',
      analysisCredits: 5,
      isPremium: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// JSON'dan UserModel oluşturur (Firestore deserializasyon)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Misafir Kullanıcı',
      analysisCredits: json['analysisCredits'] as int? ?? 5,
      isPremium: json['isPremium'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// UserModel'i JSON'a dönüştürür (Firestore serializasyon)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'analysisCredits': analysisCredits,
      'isPremium': isPremium,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// DateTime parsing helper
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// UserModel kopyalama metodu (immutability için)
  UserModel copyWith({
    String? id,
    String? name,
    int? analysisCredits,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      analysisCredits: analysisCredits ?? this.analysisCredits,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Equatable props - karşılaştırma için kullanılır
  @override
  List<Object?> get props => [
        id,
        name,
        analysisCredits,
        isPremium,
        createdAt,
        updatedAt,
      ];

  /// Debug için string representation
  @override
  String toString() {
    return 'UserModel{id: $id, name: $name, '
        'isPremium: $isPremium, analysisCredits: $analysisCredits}';
  }

  /// Kullanıcının görünen adını döner
  String get displayName {
    if (name.isNotEmpty && name != 'Kullanıcı') {
      return name;
    }
    return 'Misafir Kullanıcı';
  }

  /// Kullanıcının analiz hakkı var mı kontrolü
  bool get canAnalyze => isPremium || analysisCredits > 0;
}
