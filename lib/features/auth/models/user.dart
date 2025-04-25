import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Kullanıcı modeli
/// @deprecated Bu sınıf artık kullanılmamaktadır. UserModel sınıfını kullanın.
@Deprecated('Bu sınıf artık kullanılmamaktadır. UserModel sınıfını kullanın.')
class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool isPremium;
  final DateTime? premiumExpireDate;
  final int analysisCredits;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.isPremium = false,
    this.premiumExpireDate,
    this.analysisCredits = 1, // Varsayılan olarak 1 analiz kredisi
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore'dan gelen veri ile User oluşturur
  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      isPremium: map['isPremium'] ?? false,
      premiumExpireDate:
          map['premiumExpireDate'] != null
              ? (map['premiumExpireDate'] as Timestamp).toDate()
              : null,
      analysisCredits:
          map['analysisCredits'] ?? 1, // Varsayılan olarak 1 analiz kredisi
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          map['updatedAt'] != null
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// User'ı Firestore'a kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isPremium': isPremium,
      'premiumExpireDate':
          premiumExpireDate != null
              ? Timestamp.fromDate(premiumExpireDate!)
              : null,
      'analysisCredits': analysisCredits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Mevcut User üzerinde belirli değişiklikler yaparak yeni bir User döndürür
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isPremium,
    DateTime? premiumExpireDate,
    int? analysisCredits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isPremium: isPremium ?? this.isPremium,
      premiumExpireDate: premiumExpireDate ?? this.premiumExpireDate,
      analysisCredits: analysisCredits ?? this.analysisCredits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoURL,
    isPremium,
    premiumExpireDate,
    analysisCredits,
    createdAt,
    updatedAt,
  ];
}
