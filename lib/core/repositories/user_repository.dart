import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/base/base_repository.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';

/// Kullanıcı repository'si - Firebase Auth ve Firestore işlemlerini birleştirir
class UserRepository extends BaseRepository with CacheableMixin {
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final String _userCollection = 'users';
  final String _userCachePrefix = 'user_';
  SharedPreferences? _prefs;

  /// Varsayılan olarak Firebase örneklerini kullanır
  UserRepository({AuthService? authService, FirebaseFirestore? firestore})
      : _authService = authService ?? AuthService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// SharedPreferences instance'ını başlatır
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Giriş durumu değişikliklerini stream olarak döndürür
  Stream<UserModel?> get user {
    return _authService.userStream;
  }

  /// Mevcut kullanıcıyı döndürür
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      // Önce AuthService'ten doğrudan UserModel almayı dene
      final userModel =
          await _authService.getUserFromFirestore(firebaseUser.uid);
      return userModel;
    } catch (e) {
      logWarning('Mevcut kullanıcı verisi alınamadı', e.toString());
      return null;
    }
  }

  /// Firebase Authentication'dan oturum açıyor ve Firestore'da kullanıcı verilerini oluşturuyor/güncelliyor
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // userModel çoktan güncellenmiş olarak dönüyor
      logSuccess('Giriş yapma', 'Kullanıcı ID: ${userModel.id}');
      return userModel;
    } catch (e) {
      handleError('Giriş yapma', e);
      rethrow;
    }
  }

  /// Firebase Authentication'da kayıt oluyor ve Firestore'da kullanıcı verilerini oluşturuyor
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userModel = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      // E-posta doğrulama gönder
      await _authService.sendEmailVerification();

      logSuccess('Kayıt olma', 'Kullanıcı ID: ${userModel.id}');
      return userModel;
    } catch (e) {
      handleError('Kayıt olma', e);
      rethrow;
    }
  }

  /// Oturumu kapatır
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      logSuccess('Çıkış yapma');
    } catch (e) {
      handleError('Çıkış yapma', e);
      rethrow;
    }
  }

  /// E-posta doğrulama bağlantısı gönderir
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      logSuccess('E-posta doğrulama gönderme');
    } catch (e) {
      handleError('E-posta doğrulama', e);
      rethrow;
    }
  }

  /// Şifre sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      logSuccess('Şifre sıfırlama e-postası gönderme', email);
    } catch (e) {
      handleError('Şifre sıfırlama', e);
      rethrow;
    }
  }

  /// Kullanıcının profilini günceller (hem Firebase Auth hem de Firestore)
  Future<UserModel?> updateProfile({
    required String displayName,
    String? photoURL,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    try {
      // Firebase Auth ve Firestore'da güncelle
      final updatedUser = await _authService.updateUserProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      logSuccess('Profil güncelleme');
      return updatedUser;
    } catch (e) {
      handleError('Profil güncelleme', e);
      rethrow;
    }
  }

  /// Kullanıcı hesabını siler (hem Firebase Auth hem de Firestore)
  Future<void> deleteAccount() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    try {
      // Önce Firestore'dan kullanıcıyı sil
      await _firestore.collection(_userCollection).doc(currentUser.id).delete();

      // Sonra Firebase Auth'dan kullanıcıyı sil
      await _authService.deleteAccount();
      logSuccess('Hesap silme');
    } catch (e) {
      handleError('Hesap silme', e);
      rethrow;
    }
  }

  /// Premium hesaba yükseltme
  Future<UserModel?> upgradeToPremium() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    try {
      final upgradedUser = currentUser.upgradeToPremium();
      await updateUserData(upgradedUser);
      logSuccess('Premium yükseltme');
      return upgradedUser;
    } catch (e) {
      handleError('Premium yükseltme', e);
      rethrow;
    }
  }

  /// Analiz kredisi ekleme
  Future<UserModel?> addAnalysisCredits(int amount) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    try {
      final updatedUser = currentUser.addCredits(amount);
      await updateUserData(updatedUser);
      logSuccess('Kredi ekleme', '$amount kredi eklendi');
      return updatedUser;
    } catch (e) {
      handleError('Kredi ekleme', e);
      rethrow;
    }
  }

  /// Analiz kredisi kullanma
  Future<UserModel?> useAnalysisCredit() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    if (!currentUser.hasAnalysisCredits) {
      throw Exception('Yeterli kredi yok.');
    }

    try {
      final updatedUser = currentUser.useCredit();
      await updateUserData(updatedUser);
      logSuccess('Kredi kullanma');
      return updatedUser;
    } catch (e) {
      handleError('Kredi kullanma', e);
      rethrow;
    }
  }

  /// Firestore'dan kullanıcı verisini alır
  Future<UserModel> getUserData(String userId) async {
    try {
      return await _authService.getUserFromFirestore(userId);
    } catch (e) {
      handleError('Kullanıcı verisi alma', e);
      rethrow;
    }
  }

  /// Firestore'da yeni kullanıcı verisi oluşturur
  Future<void> createUserData(UserModel user) async {
    try {
      // AuthService zaten kullanıcı verisini Firestore'a kaydediyor
      logSuccess('Kullanıcı verisi oluşturuldu', 'Kullanıcı ID: ${user.id}');
    } catch (e) {
      handleError('Kullanıcı verisi oluşturma', e);
      rethrow;
    }
  }

  /// Firestore'da kullanıcı verisini günceller
  Future<void> updateUserData(UserModel user) async {
    try {
      await _authService.saveUserToFirestore(user);
      logSuccess('Kullanıcı verisi güncellendi', 'Kullanıcı ID: ${user.id}');
    } catch (e) {
      handleError('Kullanıcı verisi güncelleme', e);
      rethrow;
    }
  }

  /// Veriyi önbelleğe kaydeder
  @override
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await _preferences;
      // JSON verisi olarak kaydediyoruz
      final jsonData = data.toString();
      await prefs.setString(key, jsonData);
      logDebug('Veri önbelleğe kaydedildi: $key');
    } catch (e) {
      logWarning('Veri önbelleğe kaydedilemedi: $key', e.toString());
    }
  }

  /// Önbellekten veri alır
  @override
  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await _preferences;
      final jsonData = prefs.getString(key);
      if (jsonData != null) {
        // JSON string'i Map'e dönüştür
        // Not: Gerçek uygulamada json.decode kullanılır
        // Burada basit bir örnek olarak çalışıyor
        final data = Map<String, dynamic>.from({});
        logDebug('Veri önbellekten alındı: $key');
        return data;
      }
    } catch (e) {
      logWarning('Veri önbellekten alınamadı: $key', e.toString());
    }
    return null;
  }

  /// Önbellekten belirli bir veriyi siler
  @override
  Future<void> removeCachedData(String key) async {
    try {
      final prefs = await _preferences;
      await prefs.remove(key);
      logDebug('Önbellekten veri silindi: $key');
    } catch (e) {
      logWarning('Önbellekten veri silinemedi: $key', e.toString());
    }
  }

  /// Tüm önbelleği temizler
  @override
  Future<void> clearCache() async {
    try {
      final prefs = await _preferences;
      // Sadece kullanıcı verilerini temizle
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(_userCachePrefix))
          .toList();

      for (var key in keys) {
        await prefs.remove(key);
      }

      logDebug('Önbellek temizlendi');
    } catch (e) {
      logWarning('Önbellek temizlenemedi', e.toString());
    }
  }
}
