import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:tatarai/core/base/base_service.dart';

/// Firebase authentication servisi
/// Firebase Auth ile ilgili temel işlemleri gerçekleştirir
class AuthService extends BaseService {
  final firebase_auth.FirebaseAuth _firebaseAuth;

  /// Firebase Authentication örneğini alır
  AuthService({firebase_auth.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  /// Mevcut giriş yapmış kullanıcıyı stream olarak döndürür
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Mevcut giriş yapmış kullanıcıyı döndürür
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  /// E-posta ve şifre ile kayıt olma işlemini yapar
  Future<firebase_auth.User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      logSuccess('Kayıt olma', 'Kullanıcı ID: ${userCredential.user?.uid}');
      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      final errorMessage = _handleFirebaseAuthError(e);
      logWarning('Kayıt olma hatası', '$errorMessage (${e.code})');
      throw Exception(errorMessage);
    } catch (e) {
      handleError('Kayıt olma', e);
      throw Exception('Kayıt sırasında beklenmeyen bir hata oluştu.');
    }
  }

  /// E-posta ve şifre ile giriş yapma işlemini yapar
  Future<firebase_auth.User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      logSuccess('Giriş yapma', 'Kullanıcı ID: ${userCredential.user?.uid}');
      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      final errorMessage = _handleFirebaseAuthError(e);
      logWarning('Giriş yapma hatası', '$errorMessage (${e.code})');
      throw Exception(errorMessage);
    } catch (e) {
      handleError('Giriş yapma', e);
      throw Exception('Giriş sırasında beklenmeyen bir hata oluştu.');
    }
  }

  /// E-posta doğrulama linki gönderir
  Future<void> sendEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
      logSuccess('E-posta doğrulama linki gönderildi');
    } catch (e) {
      _handleFirebaseAuthError(e);
      rethrow;
    }
  }

  /// Kullanıcının e-posta doğrulama durumunu yeniler
  Future<bool> refreshEmailVerificationStatus() async {
    try {
      // Kullanıcı bilgilerini Firebase'den yeniden çek
      await _firebaseAuth.currentUser?.reload();
      final user = _firebaseAuth.currentUser;

      if (user != null && user.emailVerified) {
        logSuccess('E-posta doğrulandı: ${user.email}');
        return true;
      } else {
        logInfo('E-posta henüz doğrulanmadı');
        return false;
      }
    } catch (e) {
      _handleFirebaseAuthError(e);
      return false;
    }
  }

  /// Şifre sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      logSuccess('Şifre sıfırlama e-postası gönderme', email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      logWarning('Şifre sıfırlama hatası', '${e.code}: ${e.message}');
      final errorMessage = _handleFirebaseAuthError(e);
      throw Exception(errorMessage);
    } catch (e) {
      handleError('Şifre sıfırlama', e);
      throw Exception('Şifre sıfırlama sırasında bir hata oluştu.');
    }
  }

  /// Oturum kapatma
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      logSuccess('Çıkış yapma');
    } catch (e) {
      handleError('Çıkış yapma', e);
      throw Exception('Çıkış yapma sırasında bir hata oluştu.');
    }
  }

  /// Kullanıcı hesabını silme
  Future<void> deleteAccount() async {
    try {
      await _firebaseAuth.currentUser?.delete();
      logSuccess('Hesap silme');
    } on firebase_auth.FirebaseAuthException catch (e) {
      logWarning('Hesap silme hatası', '${e.code}: ${e.message}');
      final errorMessage = _handleFirebaseAuthError(e);
      throw Exception(errorMessage);
    } catch (e) {
      handleError('Hesap silme', e);
      throw Exception('Hesap silme sırasında bir hata oluştu.');
    }
  }

  /// Firebase'de kullanıcı profilini günceller
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış kullanıcı bulunamadı');
      }

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);

      // Profil güncellemesinden sonra kullanıcı bilgilerini yenile
      // Bu, sonraki işlemlerde güncel kullanıcı bilgilerine erişim sağlar
      await user.reload();

      logSuccess('Profil güncelleme');
    } catch (e) {
      handleError('Profil güncelleme', e);
      rethrow;
    }
  }

  /// Firebase token'ını yeniler - Firebase 5.5.2+ versiyonları için gerekli
  Future<String?> getIdToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        logWarning('Token yenileme', 'Kullanıcı oturum açmamış');
        return null;
      }

      // Force refresh token
      final idToken = await user.getIdToken(true);
      logSuccess('Token yenileme', 'Token başarıyla alındı');
      return idToken;
    } catch (e) {
      handleError('Token yenileme', e);
      return null;
    }
  }

  /// Firebase Auth hata mesajlarını işler
  String _handleFirebaseAuthError(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      final code = error.code;
      logWarning(
        'Firebase Auth hatası',
        'Bir hata oluştu: ${error.message} [ $code',
      );

      // Hata kodlarına göre anlamlı mesajlar döndür
      switch (code) {
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanımda.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'user-not-found':
          return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password':
          return 'Yanlış şifre.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter içermelidir.';
        case 'operation-not-allowed':
          return 'Bu işlem şu anda izin verilmiyor.';
        case 'user-disabled':
          return 'Bu kullanıcı hesabı devre dışı bırakılmıştır.';
        case 'too-many-requests':
          return 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.';
        case 'requires-recent-login':
          return 'Bu işlem için yakın zamanda giriş yapmanız gerekiyor.';
        case 'network-request-failed':
          return 'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';
        case 'invalid-verification-code':
          return 'Geçersiz doğrulama kodu.';
        case 'invalid-verification-id':
          return 'Geçersiz doğrulama kimliği.';
        case 'account-exists-with-different-credential':
          return 'Bu e-posta adresi farklı bir giriş yöntemiyle ilişkilendirilmiş.';
        default:
          return 'Bir hata oluştu: ${error.message}';
      }
    } else {
      logWarning('Firebase Auth hatası', 'Bilinmeyen hata: $error');
      return 'Bir hata oluştu: $error';
    }
  }

  /// Firebase Auth hata kodundan anlamlı mesaj döndürür
  String getMessageFromErrorCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış şifre.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter içermelidir.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda izin verilmiyor.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmıştır.';
      case 'too-many-requests':
        return 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.';
      case 'requires-recent-login':
        return 'Bu işlem için yakın zamanda giriş yapmanız gerekiyor.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';
      case 'invalid-verification-code':
        return 'Geçersiz doğrulama kodu.';
      case 'invalid-verification-id':
        return 'Geçersiz doğrulama kimliği.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta adresi farklı bir giriş yöntemiyle ilişkilendirilmiş.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }
}
