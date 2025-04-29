import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:tatarai/core/base/base_service.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/auth/models/user_role.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase authentication servisi
/// Firebase Auth ile ilgili temel işlemleri gerçekleştirir
class AuthService extends BaseService {
  final Logger _logger = Logger();
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  /// Maksimum yeniden deneme sayısı
  static const int _maxRetries = 3;

  /// Yeniden denemeler arasındaki bekleme süresi (milisaniye)
  static const int _retryDelay = 2000;

  /// Varsayılan constructor
  AuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseManager? firebaseManager,
  })  : _firebaseAuth =
            firebaseAuth ?? (firebaseManager?.auth ?? FirebaseManager().auth),
        _firestore = firestore ??
            (firebaseManager?.firestore ??
                FirebaseFirestore.instanceFor(
                  app: Firebase.app(),
                  databaseId: 'tatarai',
                ));

  /// Yeniden deneme mekanizması ile işlem yapma
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        _logger.w(
          'İşlem başarısız oldu (Deneme $retryCount/$_maxRetries): $e',
        );

        if (retryCount < _maxRetries) {
          _logger.i('$_retryDelay ms sonra yeniden denenecek...');
          await Future.delayed(Duration(milliseconds: _retryDelay));
        } else {
          _logger.e('Maksimum deneme sayısına ulaşıldı: $e');
          rethrow;
        }
      }
    }
    throw Exception('Beklenmeyen bir hata oluştu');
  }

  /// Mevcut giriş yapmış kullanıcıyı stream olarak döndürür
  Stream<UserModel?> get userStream {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return null;
      }

      try {
        return await _withRetry(() => getUserFromFirestore(user.uid));
      } catch (e) {
        _logger.e('Firestore\'dan kullanıcı bilgileri alınamadı: $e');
        // Temel kullanıcı bilgileriyle devam et
        return UserModel.fromFirebaseUser(user);
      }
    });
  }

  /// Mevcut giriş yapmış kullanıcıyı döndürür
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  /// E-posta ve şifre ile kayıt olma işlemini yapar
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _withRetry(() async {
      try {
        _logger.i('E-posta ile kayıt başlatılıyor: $email');

        final userCredential =
            await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user!;

        // Kullanıcı profili güncelleme
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }

        // Firestore kullanıcı dökümanı oluştur
        final userModel = UserModel(
          id: user.uid,
          email: email,
          displayName: displayName,
          isEmailVerified: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          role: UserRole.free,
          analysisCredits: 3, // Yeni kullanıcılar için başlangıç kredisi
          favoriteAnalysisIds: const [],
        );

        await saveUserToFirestore(userModel);

        _logger.i('Kullanıcı kaydı başarılı: ${user.uid}');
        return userModel;
      } on firebase_auth.FirebaseAuthException catch (e) {
        _logger.w('Kayıt olma hatası: ${e.code}');
        throw _handleAuthException(e);
      } catch (e) {
        _logger.e('Beklenmeyen kayıt hatası: $e');
        throw Exception(
            'Kayıt işlemi sırasında beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
      }
    });
  }

  /// E-posta ve şifre ile giriş yapma işlemini yapar
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _withRetry(() async {
      try {
        _logger.i('E-posta ile giriş başlatılıyor: $email');

        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user!;
        final userModel = await getUserFromFirestore(user.uid);

        // Giriş zamanını güncelle
        final updatedModel = userModel.copyWith(
          lastLoginAt: DateTime.now(),
        );

        await saveUserToFirestore(updatedModel);

        _logger.i('Giriş başarılı: ${user.uid}');
        return updatedModel;
      } on firebase_auth.FirebaseAuthException catch (e) {
        _logger.w('Giriş hatası: ${e.code}');
        throw _handleAuthException(e);
      } catch (e) {
        _logger.e('Beklenmeyen giriş hatası: $e');
        throw Exception(
            'Giriş işlemi sırasında beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
      }
    });
  }

  /// Kullanıcı çıkışı
  Future<void> signOut() async {
    return _withRetry(() async {
      try {
        _logger.i('Kullanıcı çıkışı başlatılıyor');
        await _firebaseAuth.signOut();
        _logger.i('Kullanıcı çıkışı başarılı');
      } catch (e) {
        _logger.e('Çıkış hatası: $e');
        throw Exception(
            'Çıkış yapılırken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
      }
    });
  }

  /// E-posta doğrulama gönderme
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('Oturum açık değil.');
      }

      await user.sendEmailVerification();
      _logger.i('E-posta doğrulama bağlantısı gönderildi: ${user.email}');
    } catch (e) {
      _logger.e('E-posta doğrulama hatası: $e');
      throw Exception(
          'E-posta doğrulama bağlantısı gönderilirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// E-posta doğrulama durumunu kontrol eder
  Future<bool> checkEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      await user?.reload(); // Kullanıcı bilgilerini yenile

      if (user != null && user.emailVerified) {
        _logger.i('E-posta doğrulandı: ${user.email}');

        // Firestore'daki kullanıcı bilgilerini güncelle
        final userModel = await getUserFromFirestore(user.uid);
        final updatedModel = userModel.copyWith(isEmailVerified: true);
        await saveUserToFirestore(updatedModel);

        return true;
      } else {
        _logger.i('E-posta henüz doğrulanmadı');
        return false;
      }
    } catch (e) {
      _logger.e('E-posta doğrulama hatası: $e');
      return false;
    }
  }

  /// Şifre sıfırlama e-postası gönderme
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Şifre sıfırlama e-postası gönderiliyor: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      _logger.i('Şifre sıfırlama e-postası gönderildi: $email');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.w('Şifre sıfırlama hatası: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Beklenmeyen şifre sıfırlama hatası: $e');
      throw Exception(
          'Şifre sıfırlama e-postası gönderilirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Hesap silme
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('Oturum açık değil.');
      }

      // Önce Firestore'dan kullanıcı verilerini sil
      await _firestore.collection('users').doc(user.uid).delete();

      // Sonra Authentication hesabını sil
      await user.delete();
      _logger.i('Hesap silindi: ${user.uid}');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.w('Hesap silme hatası: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Hesap silme hatası: $e');
      throw Exception(
          'Hesap silme sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Kullanıcı hesabını güncelleme
  Future<UserModel> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('Oturum açık değil.');
      }

      _logger.i('Kullanıcı profili güncelleniyor: ${user.uid}');

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      // Mevcut kullanıcı bilgilerini al ve güncelle
      final userModel = await getUserFromFirestore(user.uid);
      final updatedUserModel = userModel.copyWith(
        displayName: displayName ?? userModel.displayName,
        photoURL: photoURL ?? userModel.photoURL,
      );

      await saveUserToFirestore(updatedUserModel);

      _logger.i('Kullanıcı profili güncellendi: ${user.uid}');
      return updatedUserModel;
    } catch (e) {
      _logger.e('Profil güncelleme hatası: $e');
      throw Exception(
          'Kullanıcı profili güncellenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Analiz kredisi güncelleme
  Future<UserModel> updateAnalysisCredits(String userId, int credits) async {
    try {
      _logger.i('Kullanıcı kredisi güncelleniyor: $userId, credits: $credits');

      // Mevcut kullanıcı bilgilerini al ve güncelle
      final userModel = await getUserFromFirestore(userId);
      final updatedUserModel = userModel.copyWith(
        analysisCredits: credits,
      );

      await saveUserToFirestore(updatedUserModel);

      _logger
          .i('Kullanıcı kredisi güncellendi: $userId, yeni krediler: $credits');
      return updatedUserModel;
    } catch (e) {
      _logger.e('Kredi güncelleme hatası: $e');
      throw Exception(
          'Kullanıcı kredileri güncellenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Firestore'dan kullanıcı bilgilerini alma
  Future<UserModel> getUserFromFirestore(String userId) async {
    return _withRetry(() async {
      try {
        // Önce önbellekten okumayı dene
        final docSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .get(const GetOptions(source: Source.cache));

        // Eğer önbellekte varsa ve geçerliyse kullan
        if (docSnapshot.exists && docSnapshot.data() != null) {
          _logger.i('Kullanıcı bilgileri önbellekten alındı: $userId');
          return UserModel.fromFirestore(docSnapshot);
        }

        // Önbellekte yoksa veya geçersizse sunucudan al
        _logger.i('Kullanıcı bilgileri sunucudan alınıyor: $userId');

        // Firestore ayarlarını kontrol et ve güncelle
        if (_firestore.settings.host != 'firestore.googleapis.com') {
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            sslEnabled: true,
            host: 'firestore.googleapis.com',
          );
        }

        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .get(const GetOptions(source: Source.server));

        if (!doc.exists || doc.data() == null) {
          _logger.w('Kullanıcı dökümanı bulunamadı: $userId');

          // Firebase Auth'tan temel kullanıcı bilgilerini al
          final authUser = _firebaseAuth.currentUser;
          if (authUser?.uid == userId) {
            return UserModel.fromFirebaseUser(authUser!);
          }

          throw Exception('Kullanıcı bilgileri bulunamadı.');
        }

        // Başarılı okuma durumunda önbelleğe kaydet
        await _firestore
            .collection('users')
            .doc(userId)
            .set(doc.data()!, SetOptions(merge: true));

        return UserModel.fromFirestore(doc);
      } catch (e) {
        _logger.e('Firestore kullanıcı bilgisi alma hatası: $e');

        // Hata durumunda Firebase Auth'tan temel bilgileri almayı dene
        final authUser = _firebaseAuth.currentUser;
        if (authUser?.uid == userId) {
          _logger.i(
              'Firebase Auth\'dan temel kullanıcı bilgileri alınıyor: $userId');
          return UserModel.fromFirebaseUser(authUser!);
        }

        rethrow;
      }
    });
  }

  /// Firestore'a kullanıcı bilgilerini kaydetme
  Future<void> saveUserToFirestore(UserModel user) async {
    return _withRetry(() async {
      try {
        await _firestore.collection('users').doc(user.id).set(
              user.toFirestore(),
              SetOptions(merge: true),
            );
      } catch (e) {
        _logger.e('Firestore kullanıcı kaydetme hatası: $e');
        throw Exception('Kullanıcı bilgileri kaydedilirken bir hata oluştu.');
      }
    });
  }

  /// Firebase Auth hatalarını düzgün mesajlara dönüştürme
  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi formatı.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu e-posta adresine sahip bir kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'weak-password':
        return 'Şifre çok zayıf. Lütfen daha güçlü bir şifre seçin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda izin verilmiyor.';
      case 'too-many-requests':
        return 'Çok fazla istekte bulundunuz. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. Lütfen internet bağlantınızı kontrol edin.';
      default:
        return 'Bir hata oluştu: ${e.message ?? e.code}';
    }
  }
}
