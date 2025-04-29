import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:tatarai/features/auth/models/user_role.dart';

/// Kullanıcı modeli - Firebase kimlik doğrulama verilerini ve Firestore kullanıcı verilerini birleştirir
class UserModel extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final UserRole role; // Enum kullanılıyor
  final int analysisCredits; // Kalan analiz kredisi
  final List<String> favoriteAnalysisIds; // Favori analizlerin ID'leri

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.isEmailVerified,
    required this.createdAt,
    required this.lastLoginAt,
    required this.role,
    required this.analysisCredits,
    required this.favoriteAnalysisIds,
  });

  /// Firebase kullanıcısından UserModel oluşturur
  /// Firebase Auth verileriyle temel bir UserModel döndürür
  factory UserModel.fromFirebaseUser(firebase_auth.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime ?? DateTime.now(),
      role: UserRole.free, // Varsayılan rol
      analysisCredits: 3, // Yeni kullanıcılar için ücretsiz krediler
      favoriteAnalysisIds: const [],
    );
  }

  /// Firestore dökümanından UserModel oluşturur
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt:
          (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      role: UserRole.fromString(data['role']), // String'ten enum'a dönüştürme
      analysisCredits: data['analysisCredits'] ?? 0,
      favoriteAnalysisIds: List<String>.from(data['favoriteAnalysisIds'] ?? []),
    );
  }

  /// UserModel'i Firestore'a kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'role': role.toString(), // Enum'dan string'e dönüştürme
      'analysisCredits': analysisCredits,
      'favoriteAnalysisIds': favoriteAnalysisIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// UserModel'i günceller
  UserModel copyWith({
    String? email,
    String? displayName,
    String? photoURL,
    bool? isEmailVerified,
    DateTime? lastLoginAt,
    UserRole? role,
    int? analysisCredits,
    List<String>? favoriteAnalysisIds,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      role: role ?? this.role,
      analysisCredits: analysisCredits ?? this.analysisCredits,
      favoriteAnalysisIds: favoriteAnalysisIds ?? this.favoriteAnalysisIds,
    );
  }

  /// Kredi ekleme
  UserModel addCredits(int amount) {
    return copyWith(analysisCredits: analysisCredits + amount);
  }

  /// Kredi kullanma
  UserModel useCredit() {
    return copyWith(analysisCredits: analysisCredits - 1);
  }

  /// Premium hesaba yükseltme
  UserModel upgradeToPremium() {
    return copyWith(
      role: UserRole.premium,
      analysisCredits: analysisCredits + 10,
    );
  }

  /// Kullanıcının premium olup olmadığını kontrol eder
  bool get isPremium => role.isPremium;

  /// Kullanıcının admin olup olmadığını kontrol eder
  bool get isAdmin => role.isAdmin;

  /// Kullanıcının yeterli kredisi olup olmadığını kontrol eder
  bool get hasAnalysisCredits => analysisCredits > 0;

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoURL,
        isEmailVerified,
        createdAt,
        lastLoginAt,
        role,
        analysisCredits,
        favoriteAnalysisIds,
      ];
}
