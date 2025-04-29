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
  // Servisler ve değişkenler
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final String _userCollection = 'users';
  final String _userCachePrefix = 'user_';
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  final FirebaseManager _firebaseManager = FirebaseManager();

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
      // Firebase Manager'ı başlat
      if (!_firebaseManager.isInitialized) {
        await _firebaseManager.initialize();
      }

      AppLogger.i('UserRepository başlatılıyor...');
      AppLogger.i('Firestore Database ID: tatarai');

      // Firestore bağlantısını kontrol et
      await _firestore.collection(_userCollection).limit(1).get();

      AppLogger.i('Firestore bağlantısı başarılı');
      AppLogger.i('Firestore Project ID: ${_firestore.app.options.projectId}');

      // SharedPreferences'ı başlat
      _prefs = await SharedPreferences.getInstance();

      _isInitialized = true;
      logSuccess('Repository başlatma');
    } catch (e) {
      AppLogger.e('UserRepository başlatma hatası', e);
      _retryInitialization();
    }
  }

  /// Başlatma işlemini yeniden dener
  Future<void> _retryInitialization() async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseRetryDelay = 2000;

    while (retryCount < maxRetries && !_isInitialized) {
      try {
        retryCount++;
        final delay = baseRetryDelay * (1 << (retryCount - 1)); // 2s, 4s, 8s...

        AppLogger.i(
            'UserRepository yeniden başlatma denemesi $retryCount/$maxRetries, $delay ms sonra');
        await Future.delayed(Duration(milliseconds: delay));

        await _firebaseManager.initialize();
        await _firestore.collection(_userCollection).limit(1).get();

        _prefs ??= await SharedPreferences.getInstance();

        _isInitialized = true;
        logSuccess('Repository yeniden başlatma');
        return;
      } catch (e) {
        AppLogger.e('UserRepository yeniden başlatma hatası', e);
      }
    }

    // Başarısız olunca log ekle ama exception fırlatma
    AppLogger.w('UserRepository başlatılamadı, çalışmaya devam edilecek');
  }

  /// SharedPreferences instance'ını başlatır
  Future<SharedPreferences> get _preferences async {
    if (!_isInitialized) {
      await _ensureInitialized();
    }

    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Repository'nin başlatıldığından emin ol
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  /// Giriş durumu değişikliklerini stream olarak döndürür
  Stream<UserModel?> get user {
    if (!_isInitialized) {
      AppLogger.i('UserRepository henüz başlatılmamış, başlatılıyor...');
      _initialize();
    }
    return _authService.userStream;
  }

  /// Belirli bir kullanıcı ID'si için Firestore değişikliklerini gerçek zamanlı dinler
  Stream<UserModel?> getUserStream(String userId) {
    if (!_isInitialized) {
      AppLogger.i('UserRepository henüz başlatılmamış, başlatılıyor...');
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
          logInfo('Kullanıcı verisi güncellendi',
              'Email: ${userModel.email}, Analiz kredisi: ${userModel.analysisCredits}');
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
    await _ensureInitialized();

    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      // Yeni API çağrısı pattern'i kullan
      return await apiCall<UserModel>(
        operationName: 'Mevcut kullanıcı verisi alma',
        apiCall: () => getUserData(firebaseUser.uid),
      );
    } catch (e) {
      logWarning('Mevcut kullanıcı verisi alınamadı', e.toString());

      // Önbellekten almayı dene
      final cachedData =
          await getCachedData(_userCachePrefix + firebaseUser.uid);
      if (cachedData != null) {
        try {
          // Önbellekten alınan veriyi kullanarak bir model oluştur
          final Map<String, dynamic> userData;
          if (cachedData is String) {
            userData = jsonDecode(cachedData) as Map<String, dynamic>;
          } else {
            userData = cachedData as Map<String, dynamic>;
          }

          return _createUserModelFromData(userData, firebaseUser.uid);
        } catch (parseError) {
          logError('Önbellekteki veri işlenemedi', parseError.toString());
        }
      }

      // Son çare olarak Firebase Auth'tan model oluştur
      return UserModel.fromFirebaseUser(firebaseUser);
    }
  }

  /// Cache veya Firebase verilerinden UserModel oluştur
  UserModel _createUserModelFromData(
      Map<String, dynamic> userData, String userId) {
    final firebaseUser = _authService.currentUser;

    return UserModel(
      id: userId,
      email: userData['email'] ?? firebaseUser?.email ?? '',
      displayName: userData['displayName'] ?? firebaseUser?.displayName,
      photoURL: userData['photoURL'] ?? firebaseUser?.photoURL,
      isEmailVerified:
          userData['isEmailVerified'] ?? firebaseUser?.emailVerified ?? false,
      createdAt: userData['createdAt'] != null
          ? (userData['createdAt'] is Timestamp
              ? (userData['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      lastLoginAt: userData['lastLoginAt'] != null
          ? (userData['lastLoginAt'] is Timestamp
              ? (userData['lastLoginAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      role: userData['role'] != null
          ? UserRole.fromString(userData['role'])
          : UserRole.free,
      analysisCredits: userData['analysisCredits'] ?? 0,
      favoriteAnalysisIds: userData['favoriteAnalysisIds'] != null
          ? List<String>.from(userData['favoriteAnalysisIds'])
          : [],
    );
  }

  /// Firebase Authentication'dan oturum açıyor
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'E-posta ile giriş yapma',
      apiCall: () async {
        final userModel = await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        logSuccess('Giriş başarılı', 'Kullanıcı ID: ${userModel.id}');
        return userModel;
      },
    );
  }

  /// Firebase Authentication'da kayıt oluyor ve Firestore'da kullanıcı verilerini oluşturuyor
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'E-posta ile kayıt olma',
      apiCall: () async {
        final userModel = await _authService.signUpWithEmailAndPassword(
          email: email,
          password: password,
          displayName: displayName,
        );

        // E-posta doğrulama gönder
        await _authService.sendEmailVerification();

        logSuccess('Kayıt başarılı', 'Kullanıcı ID: ${userModel.id}');
        return userModel;
      },
    );
  }

  /// Oturumu kapatır
  Future<void> signOut() async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Çıkış yapma',
      apiCall: () async {
        await _authService.signOut();
        logSuccess('Çıkış başarılı');
      },
    );
  }

  /// E-posta doğrulama bağlantısı gönderir
  Future<void> sendEmailVerification() async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'E-posta doğrulama gönderme',
      apiCall: () async {
        await _authService.sendEmailVerification();
        logSuccess('E-posta doğrulama gönderildi');
      },
    );
  }

  /// E-posta doğrulama durumunu günceller
  Future<UserModel?> refreshEmailVerificationStatus() async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'E-posta doğrulama durumu yenileme',
      apiCall: () async {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          return null;
        }

        // E-posta doğrulama durumunu kontrol et ve güncelle
        final isVerified = await _authService.checkEmailVerification();
        if (isVerified) {
          logSuccess('E-posta doğrulama durumu güncellendi');
        }

        // Güncel kullanıcı modelini döndür
        return await getCurrentUser();
      },
    );
  }

  /// Şifre sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Şifre sıfırlama e-postası gönderme',
      apiCall: () async {
        await _authService.sendPasswordResetEmail(email);
        logSuccess('Şifre sıfırlama e-postası gönderildi', email);
      },
    );
  }

  /// Kullanıcının profilini günceller (hem Firebase Auth hem de Firestore)
  Future<UserModel?> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'Profil güncelleme',
      apiCall: () async {
        final firebaseUser = _authService.currentUser;
        if (firebaseUser == null) {
          logWarning('Profil güncelleme başarısız', 'Kullanıcı oturum açmamış');
          return null;
        }

        // Firebase Auth ve Firestore'da güncelle
        final updatedUser = await _authService.updateUserProfile(
          displayName: displayName,
          photoURL: photoURL,
        );

        logSuccess('Profil güncellendi', 'Kullanıcı ID: ${updatedUser.id}');
        return updatedUser;
      },
    );
  }

  /// Kullanıcı hesabını siler (hem Firebase Auth hem de Firestore)
  Future<void> deleteAccount() async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Hesap silme',
      apiCall: () async {
        final currentUser = await getCurrentUser();
        if (currentUser == null) {
          throw Exception('Oturum açık değil.');
        }

        // Önce Firestore'dan kullanıcıyı sil
        await _firestore
            .collection(_userCollection)
            .doc(currentUser.id)
            .delete();

        // Önbellekten kullanıcı verisini sil
        await removeCachedData(_userCachePrefix + currentUser.id);

        // Sonra Firebase Auth'dan kullanıcıyı sil
        await _authService.deleteAccount();

        logSuccess('Hesap silindi', 'Kullanıcı ID: ${currentUser.id}');
      },
    );
  }

  /// Kullanıcının premium üyeliğe yükseltir
  Future<UserModel?> upgradeToPremium() async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'Premium üyeliğe yükseltme',
      apiCall: () async {
        final firebaseUser = _authService.currentUser;
        if (firebaseUser == null) {
          logWarning('Premium yükseltme başarısız', 'Kullanıcı oturum açmamış');
          return null;
        }

        // Mevcut kullanıcı verisini al
        final user = await getUserData(firebaseUser.uid);

        // Premium bilgilerini güncelle
        final updatedUser = user.upgradeToPremium();

        // Firestore'da güncelle
        await updateUserData(updatedUser);

        logSuccess('Premium üyeliğe yükseltildi', 'Kullanıcı ID: ${user.id}');
        return updatedUser;
      },
    );
  }

  /// Kullanıcının analiz kredilerini günceller
  Future<UserModel?> updateAnalysisCredits(int newCreditCount) async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'Analiz kredisi güncelleme',
      apiCall: () async {
        final firebaseUser = _authService.currentUser;
        if (firebaseUser == null) {
          logWarning('Kredi güncelleme başarısız', 'Kullanıcı oturum açmamış');
          return null;
        }

        // Mevcut kullanıcı verisini al
        final user = await getUserData(firebaseUser.uid);

        // Kredi sayısını güncelle
        final updatedUser = user.copyWith(analysisCredits: newCreditCount);

        // Firestore'da güncelle
        await updateUserData(updatedUser);

        logSuccess(
          'Analiz kredisi güncellendi',
          'Kullanıcı ID: ${user.id}, Yeni Kredi: $newCreditCount',
        );
        return updatedUser;
      },
    );
  }

  /// Analiz kredisi ekleme
  Future<UserModel?> addAnalysisCredits(int amount) async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'Kredi ekleme',
      apiCall: () async {
        final currentUser = await getCurrentUser();
        if (currentUser == null) {
          throw Exception('Oturum açık değil.');
        }

        final updatedUser = currentUser.addCredits(amount);
        await updateUserData(updatedUser);

        logSuccess(
          'Kredi eklendi',
          '$amount kredi eklendi. Kullanıcı ID: ${updatedUser.id}',
        );
        return updatedUser;
      },
    );
  }

  /// Analiz kredisi kullanma
  Future<UserModel?> useAnalysisCredit() async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'Kredi kullanma',
      apiCall: () async {
        final currentUser = await getCurrentUser();
        if (currentUser == null) {
          throw Exception('Oturum açık değil.');
        }

        if (!currentUser.hasAnalysisCredits) {
          throw Exception('Yeterli analiz krediniz bulunmamaktadır.');
        }

        final updatedUser = currentUser.useCredit();
        await updateUserData(updatedUser);

        logSuccess(
          'Kredi kullanıldı',
          'Kalan kredi: ${updatedUser.analysisCredits}',
        );
        return updatedUser;
      },
    );
  }

  /// Firestore'dan kullanıcı verilerini alır
  Future<UserModel> getUserData(String userId) async {
    await _ensureInitialized();

    try {
      final docSnapshot =
          await _firestore.collection(_userCollection).doc(userId).get();

      if (docSnapshot.exists) {
        final userModel = UserModel.fromFirestore(docSnapshot);
        // Önbelleğe kaydet
        await cacheData(_userCachePrefix + userId, userModel.toFirestore());
        return userModel;
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
    await _ensureInitialized();

    return await apiCall<UserModel?>(
        operationName: 'Taze kullanıcı verisi getirme',
        apiCall: () async {
          // Retry mekanizması için gerekli değişkenler
          int retryCount = 0;
          const maxRetries = 3;
          const initialDelayMs = 1000;

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

                logSuccess(
                    'Taze kullanıcı verisi alındı', 'Kullanıcı ID: $userId');
                return user;
              } else {
                logWarning('Taze kullanıcı verisi bulunamadı',
                    'Kullanıcı ID: $userId');
                return null;
              }
            } catch (e) {
              retryCount++;

              // Son denemede başarısız olunca yedek mekanizmayı kullan
              if (retryCount > maxRetries) {
                logError('Taze kullanıcı verisi alma hatası', e.toString());

                // Önbellekten veri almayı dene
                try {
                  final cachedData =
                      await getCachedData(_userCachePrefix + userId);
                  if (cachedData != null) {
                    final Map<String, dynamic> userData;
                    if (cachedData is String) {
                      userData = jsonDecode(cachedData) as Map<String, dynamic>;
                    } else {
                      userData = cachedData as Map<String, dynamic>;
                    }

                    final user = _createUserModelFromData(userData, userId);
                    logSuccess(
                        'Önbellekten kullanıcı verisi alındı (yedek çözüm)');
                    return user;
                  }
                } catch (cacheError) {
                  logError(
                      'Önbellekten veri alma hatası', cacheError.toString());
                }

                return null;
              }

              // Exponential backoff (üstel geri çekilme) ile bekleme süresi
              final delayMs =
                  initialDelayMs * (1 << (retryCount - 1)); // 1s, 2s, 4s, 8s...
              logInfo('Yeniden deneniyor...', '$delayMs ms sonra');
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }

          return null;
        });
  }

  /// Firestore'a kullanıcı verilerini ekler
  Future<void> createUserData(UserModel user) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Kullanıcı verisi oluşturma',
      apiCall: () async {
        await _firestore
            .collection(_userCollection)
            .doc(user.id)
            .set(user.toFirestore());

        // Önbelleğe de kaydet
        await cacheData(_userCachePrefix + user.id, user.toFirestore());
        logSuccess('Kullanıcı verisi oluşturuldu', 'Kullanıcı ID: ${user.id}');
      },
    );
  }

  /// Firestore'daki kullanıcı verilerini günceller
  Future<void> updateUserData(UserModel user) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Kullanıcı verisi güncelleme',
      apiCall: () async {
        await _firestore
            .collection(_userCollection)
            .doc(user.id)
            .update(user.toFirestore());

        // Önbelleği de güncelle
        await cacheData(_userCachePrefix + user.id, user.toFirestore());
        logSuccess('Kullanıcı verisi güncellendi', 'Kullanıcı ID: ${user.id}');
      },
    );
  }

  // CacheableMixin metodları
  @override
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await _preferences;
      final jsonString = data is Map ? jsonEncode(data) : data.toString();
      await prefs.setString(key, jsonString);
      logDebug('Önbellek kaydedildi', key);
    } catch (e) {
      logWarning('Önbellek kaydetme hatası', '$key: $e');
    }
  }

  @override
  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await _preferences;
      final data = prefs.getString(key);
      if (data != null) {
        logDebug('Önbellekten okundu', key);
        try {
          // JSON olarak parse etmeyi dene
          return jsonDecode(data);
        } catch (e) {
          // JSON değilse string olarak döndür
          return data;
        }
      }
      return null;
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
      logDebug('Önbellekten silindi', key);
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
      logSuccess('Önbellek temizlendi');
    } catch (e) {
      logWarning('Önbellek temizleme hatası', e.toString());
    }
  }
}
