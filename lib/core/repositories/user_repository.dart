import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/base/base_repository.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/auth/models/user_role.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';

/// Kullanıcı repository'si - Firebase Auth ve Firestore işlemlerini birleştirir
class UserRepository extends BaseRepository with CacheableMixin {
  final AuthService _authService;
  FirebaseFirestore _firestore;
  final String _userCollection = 'users';
  final String _userCachePrefix = 'user_';
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Varsayılan olarak Firebase örneklerini kullanır
  UserRepository({AuthService? authService, FirebaseFirestore? firestore})
      : _authService = authService ?? AuthService(),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'tatarai',
            ) {
    _initialize();
  }

  /// Repository'yi başlatır
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Firestore bağlantısını kontrol et
      AppLogger.i('UserRepository başlatılıyor...');
      AppLogger.i('Firestore Database ID: tatarai');

      // Firestore ayarlarını yapılandır
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );

      // Bağlantıyı test et
      await _firestore.collection(_userCollection).limit(1).get();

      AppLogger.i('Firestore bağlantısı başarılı');
      AppLogger.i('Firestore Project ID: ${_firestore.app.options.projectId}');
      AppLogger.i('Firestore settings: ${_firestore.settings}');

      _isInitialized = true;
    } catch (e) {
      AppLogger.e('UserRepository başlatma hatası', e);
      // Hata durumunda yeniden deneme mekanizması
      _retryInitialization();
    }
  }

  /// Başlatma işlemini yeniden dener
  Future<void> _retryInitialization() async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = 2000;

    while (retryCount < maxRetries && !_isInitialized) {
      try {
        retryCount++;
        AppLogger.i(
            'UserRepository yeniden başlatma denemesi $retryCount/$maxRetries');

        // Firestore'u yeniden başlat
        final freshFirestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'tatarai',
        );

        // Ayarları tekrar yap
        freshFirestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          sslEnabled: true,
        );

        await freshFirestore.collection(_userCollection).limit(1).get();

        // Başarılı olursa yeni örneği ana değişkene ata
        _firestore = freshFirestore;

        _isInitialized = true;
        AppLogger.i('UserRepository başarıyla başlatıldı');
        return;
      } catch (e) {
        AppLogger.e('UserRepository yeniden başlatma hatası', e);

        if (retryCount < maxRetries) {
          final delay = retryDelay * retryCount;
          AppLogger.i('$delay ms sonra yeniden denenecek...');
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }
  }

  /// SharedPreferences instance'ını başlatır
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Giriş durumu değişikliklerini stream olarak döndürür
  Stream<UserModel?> get user {
    if (!_isInitialized) {
      AppLogger.w('UserRepository henüz başlatılmamış, başlatılıyor...');
      _initialize();
    }
    return _authService.userStream;
  }

  /// Belirli bir kullanıcı ID'si için Firestore değişikliklerini gerçek zamanlı dinler
  Stream<UserModel?> getUserStream(String userId) {
    if (!_isInitialized) {
      AppLogger.w('UserRepository henüz başlatılmamış, başlatılıyor...');
      _initialize();
    }

    return _firestore
        .collection(_userCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        try {
          final userModel = UserModel.fromFirestore(snapshot);

          // Kullanıcı verisini önbelleğe alma
          cacheData(
            _userCachePrefix + userId,
            userModel.toFirestore(),
          );

          logInfo(
              'Kullanıcı verisi güncellendi: ${userModel.email}, Analiz kredisi: ${userModel.analysisCredits}');
          return userModel;
        } catch (e) {
          logError('Kullanıcı verisi işlenirken hata', e.toString());
          rethrow;
        }
      } else {
        // Kullanıcı Firestore'da yok, Firebase Auth kullanıcısından model oluştur
        final firebaseUser = _authService.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          return UserModel.fromFirebaseUser(firebaseUser);
        }
        return null;
      }
    }).handleError((error) {
      logError('Firestore kullanıcı dinleme hatası', error.toString());
      // Hata durumunda Firebase Auth kullanıcısından bir model oluşturmayı dene
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null && firebaseUser.uid == userId) {
        return UserModel.fromFirebaseUser(firebaseUser);
      }
      return null;
    });
  }

  /// Mevcut kullanıcıyı döndürür
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      return await getUserData(firebaseUser.uid);
    } catch (e) {
      logWarning('Mevcut kullanıcı verisi alınamadı', e.toString());

      // Önbellekten almayı deneyelim
      try {
        final cachedData = await getCachedData(
          _userCachePrefix + firebaseUser.uid,
        );
        if (cachedData != null) {
          // Önbellekten alınan veriyi kullanarak bir model oluştur
          final userDoc = await _firestore
              .collection(_userCollection)
              .doc(firebaseUser.uid)
              .get();
          return UserModel.fromFirestore(userDoc);
        }
      } catch (_) {
        // Önbellekten de alınamadı, Firebase Auth kullanıcısından bir model oluştur
      }

      return UserModel.fromFirebaseUser(firebaseUser);
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
    String? displayName,
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

  /// E-posta doğrulama durumunu günceller
  Future<UserModel?> refreshEmailVerificationStatus() async {
    try {
      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        return null;
      }

      // E-posta doğrulama durumunu kontrol et ve güncelle
      final isVerified = await _authService.checkEmailVerification();

      // checkEmailVerification metodu zaten Firestore güncelleme yapar
      if (isVerified) {
        logSuccess('E-posta doğrulama durumu güncellendi');
      }

      // Güncel kullanıcı modelini döndür
      return await getCurrentUser();
    } catch (e) {
      handleError('E-posta doğrulama durumu yenileme', e);
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
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        logWarning('Profil güncelleme başarısız: Kullanıcı oturum açmamış');
        return null;
      }

      // Firebase Auth ve Firestore'da güncelle
      final updatedUser = await _authService.updateUserProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      logSuccess('Profil güncelleme', 'Kullanıcı ID: ${updatedUser.id}');
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

      // Önbellekten kullanıcı verisini sil
      await removeCachedData(_userCachePrefix + currentUser.id);

      // Sonra Firebase Auth'dan kullanıcıyı sil
      await _authService.deleteAccount();

      logSuccess('Hesap silme', 'Kullanıcı ID: ${currentUser.id}');
    } catch (e) {
      handleError('Hesap silme', e);
      rethrow;
    }
  }

  /// Kullanıcının premium üyeliğe yükseltir
  Future<UserModel?> upgradeToPremium() async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        logWarning('Premium yükseltme başarısız: Kullanıcı oturum açmamış');
        return null;
      }

      // Mevcut kullanıcı verisini al
      final user = await getUserData(firebaseUser.uid);

      // Premium bilgilerini güncelle
      final updatedUser = user.upgradeToPremium();

      // Firestore'da güncelle
      await updateUserData(updatedUser);

      logSuccess('Premium yükseltme', 'Kullanıcı ID: ${user.id}');
      return updatedUser;
    } catch (e) {
      handleError('Premium yükseltme', e);
      rethrow;
    }
  }

  /// Kullanıcının analiz kredilerini günceller
  Future<UserModel?> updateAnalysisCredits(int newCreditCount) async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        logWarning('Kredi güncelleme başarısız: Kullanıcı oturum açmamış');
        return null;
      }

      // Mevcut kullanıcı verisini al
      final user = await getUserData(firebaseUser.uid);

      // Kredi sayısını güncelle
      final updatedUser = user.copyWith(analysisCredits: newCreditCount);

      // Firestore'da güncelle
      await updateUserData(updatedUser);

      logSuccess(
        'Analiz kredisi güncelleme',
        'Kullanıcı ID: ${user.id}, Yeni Kredi: $newCreditCount',
      );
      return updatedUser;
    } catch (e) {
      handleError('Analiz kredisi güncelleme', e);
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
      logSuccess(
        'Kredi ekleme',
        '$amount kredi eklendi. Kullanıcı ID: ${updatedUser.id}',
      );
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
      throw Exception('Yeterli analiz krediniz bulunmamaktadır.');
    }

    try {
      final updatedUser = currentUser.useCredit();
      await updateUserData(updatedUser);
      logSuccess(
        'Kredi kullanma',
        'Kalan kredi: ${updatedUser.analysisCredits}',
      );
      return updatedUser;
    } catch (e) {
      handleError('Kredi kullanma', e);
      rethrow;
    }
  }

  /// Firestore'dan kullanıcı verilerini alır
  Future<UserModel> getUserData(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_userCollection).doc(userId).get();

      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      } else {
        // Eğer kullanıcı Firestore'da yoksa, Firebase Auth kullanıcısından oluştur
        final firebaseUser = _authService.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          final userModel = UserModel.fromFirebaseUser(firebaseUser);
          // Veritabanına kaydet
          await createUserData(userModel);
          return userModel;
        }
        throw Exception('Kullanıcı verisi bulunamadı.');
      }
    } catch (e) {
      handleError('Kullanıcı verisi alma', e);
      rethrow;
    }
  }

  /// Firestore'dan taze kullanıcı verilerini getirir (önbellek kullanmadan)
  Future<UserModel?> fetchFreshUserData(String userId) async {
    int retryCount = 0;
    const maxRetries = 3;
    const initialDelayMs = 1000; // 1 saniye

    while (retryCount <= maxRetries) {
      try {
        logInfo('Taze kullanıcı verisi getiriliyor',
            'Kullanıcı ID: $userId, Deneme: ${retryCount + 1}/${maxRetries + 1}');

        // Firestore'dan doğrudan veriyi getir (cache kullanılmaz)
        final docSnapshot = await _firestore
            .collection(_userCollection)
            .doc(userId)
            .get(GetOptions(source: Source.server));

        if (docSnapshot.exists) {
          final user = UserModel.fromFirestore(docSnapshot);

          // Önbelleği de güncelle
          await cacheData(_userCachePrefix + userId, user.toFirestore());

          logSuccess('Taze kullanıcı verisi alındı', 'Kullanıcı ID: $userId');
          return user;
        } else {
          logWarning(
              'Taze kullanıcı verisi bulunamadı', 'Kullanıcı ID: $userId');
          return null;
        }
      } catch (e) {
        retryCount++;

        // Son denemede başarısız olunca hata at
        if (retryCount > maxRetries) {
          handleError('Taze kullanıcı verisi alma', e);

          // Hata varsa ve deneme sınırına ulaştıysak, önbellekten veriyi almayı dene
          try {
            logInfo('Önbellekten kullanıcı verisi alınıyor (yedek çözüm)');
            final cachedData = await getCachedData(_userCachePrefix + userId);
            if (cachedData != null) {
              try {
                // Önbellekteki veriyi Firebase Auth ile birleştirerek dönelim
                final Map<String, dynamic> userData;
                if (cachedData is String) {
                  userData = jsonDecode(cachedData) as Map<String, dynamic>;
                } else {
                  userData = cachedData as Map<String, dynamic>;
                }

                // Eksik olabilecek bilgileri doldurmak için Firebase Auth'tan bilgi alalım
                final firebaseUser = _authService.currentUser;

                // Firebase Auth ve önbellekten birleştirilmiş kullanıcı modeli
                final UserModel user = UserModel(
                  id: userId,
                  email: userData['email'] ?? firebaseUser?.email ?? '',
                  displayName:
                      userData['displayName'] ?? firebaseUser?.displayName,
                  photoURL: userData['photoURL'] ?? firebaseUser?.photoURL,
                  isEmailVerified: userData['isEmailVerified'] ??
                      firebaseUser?.emailVerified ??
                      false,
                  createdAt: userData['createdAt'] != null
                      ? (userData['createdAt'] as Timestamp).toDate()
                      : DateTime.now(),
                  lastLoginAt: userData['lastLoginAt'] != null
                      ? (userData['lastLoginAt'] as Timestamp).toDate()
                      : DateTime.now(),
                  role: userData['role'] != null
                      ? UserRole.fromString(userData['role'])
                      : UserRole.free,
                  analysisCredits: userData['analysisCredits'] ?? 0,
                  favoriteAnalysisIds: userData['favoriteAnalysisIds'] != null
                      ? List<String>.from(userData['favoriteAnalysisIds'])
                      : [],
                );

                logSuccess('Önbellekten kullanıcı verisi alındı (yedek çözüm)');
                return user;
              } catch (parseError) {
                logError(
                    'Önbellekteki veri işlenirken hata', parseError.toString());
                return null;
              }
            }
          } catch (cacheError) {
            logError('Önbellekten veri alma hatası', cacheError.toString());
          }

          return null;
        }

        // Exponential backoff (üstel geri çekilme) ile bekleme süresi
        final delayMs =
            initialDelayMs * (2 << (retryCount - 1)); // 1s, 2s, 4s, 8s...
        logInfo('Yeniden deneniyor...', '$delayMs ms sonra');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return null;
  }

  /// Firestore'a kullanıcı verilerini ekler
  Future<void> createUserData(UserModel user) async {
    try {
      await _firestore
          .collection(_userCollection)
          .doc(user.id)
          .set(user.toFirestore());
      // Önbelleğe de kaydet
      await cacheData(_userCachePrefix + user.id, user.toFirestore());
      logSuccess('Kullanıcı verisi oluşturma', 'Kullanıcı ID: ${user.id}');
    } catch (e) {
      handleError('Kullanıcı verisi oluşturma', e);
      rethrow;
    }
  }

  /// Firestore'daki kullanıcı verilerini günceller
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection(_userCollection)
          .doc(user.id)
          .update(user.toFirestore());
      // Önbelleği de güncelle
      await cacheData(_userCachePrefix + user.id, user.toFirestore());
      logSuccess('Kullanıcı verisi güncelleme', 'Kullanıcı ID: ${user.id}');
    } catch (e) {
      handleError('Kullanıcı verisi güncelleme', e);
      rethrow;
    }
  }

  // CacheableMixin metodları

  @override
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await _preferences;
      final jsonString = data is String ? data : data.toString();
      await prefs.setString(key, jsonString);
      logDebug('Önbellek kaydetme', key);
    } catch (e) {
      logWarning('Önbellek kaydetme hatası', '$key: $e');
    }
  }

  @override
  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(key);
      logDebug('Önbellekten okuma', key);
      return data;
    } catch (e) {
      logWarning('Önbellekten okuma hatası', '$key: $e');
      return null;
    }
  }

  @override
  Future<void> removeCachedData(String key) async {
    try {
      final prefs = await _preferences;
      await prefs.remove(key);
      logDebug('Önbellekten silme', key);
    } catch (e) {
      logWarning('Önbellekten silme hatası', '$key: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys().where(
            (key) => key.startsWith(_userCachePrefix),
          );
      for (final key in keys) {
        await prefs.remove(key);
      }
      logSuccess('Önbellek temizleme');
    } catch (e) {
      logWarning('Önbellek temizleme hatası', e.toString());
    }
  }
}
