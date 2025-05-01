import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tatarai/core/base/base_repository.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/auth/models/user_role.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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

  // Ağ bağlantısı durumu
  bool _hasNetworkConnection = true;
  StreamSubscription? _connectivitySubscription;

  // Offline operasyonlar için kuyruk
  final List<_PendingOperation> _pendingOperations = [];
  Timer? _pendingOperationsTimer;

  // Yeniden deneme parametreleri
  static const int _maxRetries = 5;
  static const int _baseRetryDelayMs = 1000;

  /// Varsayılan olarak Firebase örneklerini kullanır
  UserRepository({AuthService? authService, FirebaseFirestore? firestore})
      : _authService = authService ?? AuthService(),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'tatarai',
            ) {
    _initialize();
    _setupConnectivityListener();
    _startPendingOperationsTimer();
  }

  /// Repository'yi başlatır
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase Manager'ı başlat
      if (!_firebaseManager.isInitialized) {
        AppLogger.i('Firebase Manager başlatılıyor...');
        await _firebaseManager.initialize();
        AppLogger.i('Firebase Manager başlatıldı');
      }

      AppLogger.i('UserRepository başlatılıyor...');
      AppLogger.i('Firestore Database ID: tatarai');

      // Ağ bağlantı durumunu kontrol et
      _hasNetworkConnection = await _checkNetworkConnection();
      AppLogger.i('Ağ bağlantısı durumu: $_hasNetworkConnection');

      // Çevrimdışı kalıcılık ayarları (Firebase Manager'da yapıldığı için burada sadece kontrol)
      try {
        // Firebase Manager'ın çevrimdışı kalıcılık ayarlarını kullanıyoruz
        AppLogger.i('Firebase çevrimdışı kalıcılık ayarları kontrol ediliyor');
      } catch (e) {
        AppLogger.w('Çevrimdışı kalıcılık ayarları kontrol edilemedi: $e');
      }

      // Firestore bağlantısını kontrol et
      if (_hasNetworkConnection) {
        try {
          await _firestore
              .collection(_userCollection)
              .limit(1)
              .get(
                const GetOptions(source: Source.server),
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('Firestore bağlantı zaman aşımı'),
              );
          AppLogger.i('Firestore bağlantısı başarılı');
          AppLogger.i(
              'Firestore Project ID: ${_firestore.app.options.projectId}');
        } catch (firestoreError) {
          AppLogger.w('Firestore bağlantısında sorun: $firestoreError');
          AppLogger.i('Çevrimdışı modda çalışmaya devam edilecek');

          // Daha iyi hata ayrıştırma
          if (firestoreError is TimeoutException) {
            AppLogger.w(
                'Firestore bağlantısı zaman aşımına uğradı, çevrimdışı modda çalışılacak');
          } else if (firestoreError.toString().contains('permission-denied')) {
            AppLogger.e(
                'Firestore izin hatası: Yetkilendirme sorunları olabilir');
          } else if (firestoreError.toString().contains('unavailable')) {
            AppLogger.w(
                'Firestore şu anda kullanılamıyor, çevrimdışı modda çalışılacak');
          }
        }
      } else {
        AppLogger.w('Ağ bağlantısı yok, çevrimdışı modda çalışılacak');
      }

      // SharedPreferences'ı başlat
      try {
        _prefs = await SharedPreferences.getInstance();
        AppLogger.i('SharedPreferences başlatıldı');
      } catch (prefsError) {
        AppLogger.w('SharedPreferences başlatılamadı: $prefsError');
        // SharedPreferences olmadan da devam edebiliriz
      }

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

    while (retryCount < maxRetries && !_isInitialized) {
      try {
        retryCount++;
        final delay = _getExponentialBackoffDelay(retryCount);

        AppLogger.i(
            'UserRepository yeniden başlatma denemesi $retryCount/$maxRetries, $delay ms sonra');
        await Future.delayed(Duration(milliseconds: delay));

        // Firebase Manager'ı yeniden başlatmayı dene
        try {
          await _firebaseManager.initialize();
          AppLogger.i('Firebase Manager başarıyla yeniden başlatıldı');
        } catch (managerError) {
          AppLogger.w('Firebase Manager başlatılamadı: $managerError');
          // Devam et, belki Firestore yine de çalışabilir
        }

        // Ağ bağlantı durumunu kontrol et
        _hasNetworkConnection = await _checkNetworkConnection();
        AppLogger.i('Ağ bağlantısı durumu: $_hasNetworkConnection');

        // Firestore bağlantısını kontrol et (eğer internet varsa)
        if (_hasNetworkConnection) {
          try {
            await _firestore
                .collection(_userCollection)
                .limit(1)
                .get(
                  const GetOptions(source: Source.server),
                )
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () =>
                      throw TimeoutException('Firestore bağlantı zaman aşımı'),
                );
            AppLogger.i('Firestore bağlantısı başarılı');
          } catch (firestoreError) {
            AppLogger.w('Firestore bağlantısı hala başarısız: $firestoreError');
            // Yine de devam et, çevrimdışı kalıcılık sayesinde bazı işlemler çalışabilir
          }
        } else {
          AppLogger.w('Ağ bağlantısı yok, çevrimdışı modda çalışılacak');
        }

        // SharedPreferences'ı tekrar başlatmayı dene
        try {
          _prefs ??= await SharedPreferences.getInstance();
          AppLogger.i('SharedPreferences başlatıldı');
        } catch (prefsError) {
          AppLogger.w('SharedPreferences başlatılamadı: $prefsError');
        }

        _isInitialized = true;
        logSuccess('Repository yeniden başlatma');
        return;
      } catch (e) {
        AppLogger.e('UserRepository yeniden başlatma hatası', e);
      }
    }

    if (!_isInitialized && retryCount >= maxRetries) {
      AppLogger.w('UserRepository başlatılamadı, çevrimdışı modda çalışılacak');
      // Çevrimdışı modda devam etmek için başlatılmış kabul edelim
      _isInitialized = true;
    }
  }

  /// Bağlantı dinleyicisini ayarlar
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final previousState = _hasNetworkConnection;
      _hasNetworkConnection =
          results.any((result) => result != ConnectivityResult.none);

      if (previousState != _hasNetworkConnection) {
        AppLogger.i('Ağ bağlantısı durumu değişti: $_hasNetworkConnection');

        if (_hasNetworkConnection && !previousState) {
          AppLogger.i(
              'Ağ bağlantısı yeniden kuruldu, bekleyen işlemler işlenecek');
          _processPendingOperations();
        }
      }
    });

    AppLogger.i('Bağlantı dinleyicisi kuruldu');
  }

  /// Ağ bağlantı durumunu kontrol eder
  Future<bool> _checkNetworkConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult
          .any((result) => result != ConnectivityResult.none);
    } catch (e) {
      AppLogger.w('Ağ bağlantısı kontrol hatası: $e');
      return false;
    }
  }

  /// Bekleyen işlemleri işlemek için timer başlatır
  void _startPendingOperationsTimer() {
    _pendingOperationsTimer?.cancel();

    _pendingOperationsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (_hasNetworkConnection && _pendingOperations.isNotEmpty) {
          _processPendingOperations();
        }
      },
    );

    AppLogger.i('Bekleyen işlem kontrol timer\'ı başlatıldı');
  }

  /// Bekleyen işlemleri işler
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    AppLogger.i('Bekleyen ${_pendingOperations.length} işlem işleniyor...');

    final operations = List<_PendingOperation>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        // 24 saatten eski işlemleri atla
        if (DateTime.now().difference(operation.timestamp).inHours > 24) {
          AppLogger.w('İşlem 24 saatten eski, atlanıyor: ${operation.type}');
          continue;
        }

        AppLogger.i('İşlem yeniden deneniyor: ${operation.type}');
        await operation.execute();
        AppLogger.i('İşlem başarıyla tamamlandı: ${operation.type}');
      } catch (e) {
        AppLogger.e('İşlem başarısız oldu: ${operation.type}, $e');

        // İşlemi yeniden kuyruğa al
        if (operation.retryCount < _maxRetries - 1) {
          _pendingOperations.add(operation.incrementRetry());
        } else {
          AppLogger.w(
              'Maksimum yeniden deneme sayısına ulaşıldı: ${operation.type}');
        }
      }
    }
  }

  /// Bekleyen işlem ekler
  void _addPendingOperation(_PendingOperation operation) {
    _pendingOperations.add(operation);
    AppLogger.i(
        'Bekleyen işlem eklendi: ${operation.type}, toplam: ${_pendingOperations.length}');
  }

  /// Backoff gecikmesi hesaplar
  int _getExponentialBackoffDelay(int retryCount) {
    // Baz gecikme * 2^(retryCount-1)
    // Örneğin: 1000, 2000, 4000, 8000, ... ms
    return _baseRetryDelayMs * (1 << (retryCount - 1));
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
      AppLogger.i('UserRepository henüz başlatılmamış, başlatılıyor...');

      // Önceki başlatma işlemi tamamlanana kadar bekleme işlemi (en fazla 10 saniye)
      int waitCount = 0;
      const maxWait = 10; // 10 saniye

      while (!_isInitialized && waitCount < maxWait) {
        AppLogger.i(
            'Repository başlatılması bekleniyor... ${waitCount + 1}/$maxWait');
        await Future.delayed(const Duration(seconds: 1));
        waitCount++;

        // 5 saniye sonra tekrar başlatmayı dene
        if (waitCount == 5 && !_isInitialized) {
          AppLogger.i('Başlatma zaman aşımına uğradı, yeniden başlatılıyor...');
          await _initialize();
        }
      }

      // Repository hala başlatılmadıysa çevrimdışı modda çalışmayı dene
      if (!_isInitialized) {
        AppLogger.e(
            'Repository başlatılamadı, çevrimdışı modda çalışmayı deniyorum');

        // Çevrimdışı moda geçmek için bazı ayarlar yapalım
        try {
          // Firestore ağ bağlantısını devre dışı bırak
          await _firestore.disableNetwork();
          AppLogger.i(
              'Firestore ağ bağlantısı devre dışı bırakıldı, çevrimdışı mod etkin');

          // Başlatılmış kabul et
          _isInitialized = true;
          return;
        } catch (offlineError) {
          AppLogger.e('Çevrimdışı moda geçilemedi: $offlineError');
          throw Exception(
              'Veritabanı bağlantısı kurulamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
        }
      }
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

    // Gerçek zamanlı veri akışı için Firestore snapshot
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

          // Hata durumunda offline önbelleği kontrol et
          _recoverFromOfflineCache(userId).then((cachedUser) {
            if (cachedUser != null) {
              AppLogger.i('Önbellekten kullanıcı verisi kullanılıyor: $userId');
            }
          });

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

      AppLogger.w(
          'Kullanıcı verisi dinleme hatası, önbellekten veriyi almaya çalışıyorum');

      // Hata durumunda Firebase Auth kullanıcısından bir model oluşturmayı dene
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null && firebaseUser.uid == userId) {
        return UserModel.fromFirebaseUser(firebaseUser);
      }

      // Önbellekten veri almayı dene ve stream'e aktar
      _recoverFromOfflineCache(userId).then((cachedUser) {
        if (cachedUser != null) {
          return cachedUser;
        }
        return null;
      });

      return null;
    });
  }

  /// Önbellekten kullanıcı verisini kurtarmaya çalışır
  Future<UserModel?> _recoverFromOfflineCache(String userId) async {
    try {
      final cachedData = await getCachedData(_userCachePrefix + userId);
      if (cachedData != null) {
        AppLogger.i('Kullanıcı verisi önbellekte bulundu: $userId');
        final userData = cachedData is String
            ? jsonDecode(cachedData) as Map<String, dynamic>
            : cachedData as Map<String, dynamic>;

        return _createUserModelFromData(userData, userId);
      }
    } catch (e) {
      AppLogger.e('Önbellekten kullanıcı verisi alınamadı: $e');
    }
    return null;
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
        ignoreConnectionCheck: false,
        throwError: true,
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

  /// API çağrıları için güçlendirilmiş yeniden deneme mekanizmalı wrapper
  @override
  Future<T?> apiCall<T>({
    required String operationName,
    required Future<T> Function() apiCall,
    bool throwError = false,
    bool ignoreConnectionCheck = false,
  }) async {
    await _ensureInitialized();

    // İnternet bağlantısı kontrolü (sadece ağ bağlantısı gerektiren operasyonlar için)
    if (!ignoreConnectionCheck && !_hasNetworkConnection) {
      AppLogger.w(
          '$operationName - İnternet bağlantısı yok, çevrimdışı veriler kullanılacak');

      if (throwError) {
        throw FirebaseException(
            plugin: 'UserRepository',
            code: 'network-unavailable',
            message:
                'Firebase bağlantısı kurulamadı, önbellek verileri kullanılacak');
      }
      return null;
    }

    // Retry mekanizması
    int retryCount = 0;
    Exception? lastError;

    while (retryCount <= _maxRetries) {
      try {
        // Operasyon başlangıcını logla
        if (retryCount == 0) {
          AppLogger.d('$operationName işlemi başlatılıyor');
        } else {
          AppLogger.d(
              '$operationName işlemi yeniden deneniyor - Deneme ${retryCount}/${_maxRetries}');
        }

        // API çağrısını yap
        final result = await apiCall();

        // Başarılı sonucu logla
        AppLogger.d('$operationName işlemi başarıyla tamamlandı');
        return result;
      } catch (e) {
        // Hata durumunu işle
        lastError = e is Exception ? e : Exception(e.toString());

        // Ağ hatası veya Firestore hatası mı kontrol et
        if (_isNetworkOrFirestoreError(e)) {
          if (retryCount < _maxRetries) {
            retryCount++;

            // Exponential backoff gecikmesi
            final delay = _getExponentialBackoffDelay(retryCount);
            AppLogger.w(
                '$operationName işlemi başarısız oldu, ${delay}ms sonra yeniden deneniyor - $e');
            await Future.delayed(Duration(milliseconds: delay));
            continue;
          } else {
            // Maksimum yeniden deneme sayısına ulaşıldı
            AppLogger.e(
                '$operationName işlemi için maksimum yeniden deneme sayısına ulaşıldı - $e');

            // Çevrimdışı işlem olabilecek durumlarda uyarı mesajı
            if (!ignoreConnectionCheck) {
              AppLogger.w(
                  '$operationName - Firebase bağlantısı yok uyarısı: $e');

              if (throwError) {
                throw FirebaseException(
                    plugin: 'UserRepository',
                    code: 'network-unavailable',
                    message:
                        'Firebase bağlantısı kurulamadı, önbellek verileri kullanılacak');
              }
              return null;
            }

            if (throwError) throw lastError!;
            return null;
          }
        } else {
          // Ağ hatası değilse (örn. yetkilendirme hatası, format hatası), tekrar denemeye gerek yok
          AppLogger.e(
              '$operationName işlemi ağ ile ilgisi olmayan bir hata nedeniyle başarısız oldu - $e');

          if (throwError) throw lastError!;
          return null;
        }
      }
    }

    // Tüm denemeler başarısız oldu
    if (throwError) {
      throw lastError ?? Exception('$operationName işlemi başarısız oldu');
    }
    return null;
  }

  /// Hatanın ağ bağlantısı veya Firestore ile ilgili olup olmadığını kontrol eder
  bool _isNetworkOrFirestoreError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable') ||
        errorString.contains('timeout') ||
        errorString.contains('offline') ||
        errorString.contains('socket') ||
        errorString.contains('permission-denied') ||
        errorString.contains('unauthenticated') ||
        error is TimeoutException;
  }

  /// Firebase Authentication'dan oturum açıyor
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    // İşlem başlangıcını logla
    AppLogger.i('Giriş işlemi başlatılıyor: $email');
    Stopwatch stopwatch = Stopwatch()..start();

    return await apiCall<UserModel?>(
      operationName: 'E-posta ile giriş yapma',
      apiCall: () async {
        try {
          // Daha kısa timeout'la giriş yap
          final userModel = await _authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Firestore'dan kullanıcı verisini daha hızlı almak için önce auth'dan gelen temel veriyi döndürelim
          final basicUser = userModel;

          // Yeni bir işlem olarak kullanıcı verisini almayı başlatalım (arka planda)
          // Bu, kullanıcının hemen giriş yapmasını sağlar ve veriler arka planda yüklenir
          _loadUserDataInBackground(userModel.id);

          stopwatch.stop();
          logSuccess('Giriş başarılı',
              'Kullanıcı ID: ${userModel.id}, Süre: ${stopwatch.elapsedMilliseconds}ms');

          return basicUser;
        } catch (e) {
          stopwatch.stop();
          AppLogger.e(
              'Giriş hatası: $e, Süre: ${stopwatch.elapsedMilliseconds}ms');

          // Özel hata mesajları ile yeniden fırlat
          if (_isNetworkOrFirestoreError(e)) {
            AppLogger.e('Giriş sırasında bağlantı hatası: $e');
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Giriş yapılırken bağlantı hatası oluştu. Lütfen internet bağlantınızı kontrol edin.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
    );
  }

  /// Kullanıcı verisini arka planda yükleme
  Future<void> _loadUserDataInBackground(String userId) async {
    try {
      AppLogger.i('Kullanıcı verileri arka planda yükleniyor: $userId');
      await fetchFreshUserData(userId);
    } catch (e) {
      AppLogger.w('Arka plan kullanıcı verisi yükleme hatası: $e');
      // Hata olsa bile sessizce devam et, kullanıcı deneyimini etkilemez
    }
  }

  /// E-posta doğrulama durumunu Firestore'a kaydeder
  Future<UserModel?> refreshEmailVerificationStatus() async {
    await _ensureInitialized();

    return await apiCall<UserModel?>(
      operationName: 'E-posta doğrulama durumunu güncelleme',
      apiCall: () async {
        Stopwatch stopwatch = Stopwatch()..start();
        AppLogger.i('E-posta doğrulama durumu kontrol ediliyor');

        try {
          // Firebase Auth'tan kullanıcıyı al
          final firebaseUser = _authService.currentUser;
          if (firebaseUser == null) {
            stopwatch.stop();
            AppLogger.w('Kullanıcı oturum açmamış');
            return null;
          }

          // Firebase Auth'tan kullanıcı bilgilerini yenile
          try {
            await firebaseUser.reload();
            AppLogger.i('Firebase Auth kullanıcı bilgileri yenilendi');
          } catch (e) {
            AppLogger.w('Firebase Auth kullanıcı bilgileri yenilenemedi: $e');
            // Hata olsa bile devam et
          }

          // Yenilenen kullanıcıyı al
          final freshFirebaseUser = _authService.currentUser;
          if (freshFirebaseUser == null) {
            stopwatch.stop();
            AppLogger.w(
                'Yenilenen kullanıcı bilgilerinde kullanıcı bulunamadı');
            return null;
          }

          // Firestore'dan mevcut kullanıcı verisini getir - 2 saniye timeout ile
          UserModel? userModel;
          try {
            final docSnapshot = await _firestore
                .collection(_userCollection)
                .doc(freshFirebaseUser.uid)
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 2));

            if (docSnapshot.exists) {
              userModel = UserModel.fromFirestore(docSnapshot);
            }
          } catch (e) {
            AppLogger.w(
                'Firestore\'dan kullanıcı alınamadı, temel model kullanılacak: $e');
            // Temel kullanıcı modeli oluştur
            userModel = UserModel.fromFirebaseUser(freshFirebaseUser);
          }

          if (userModel == null) {
            userModel = UserModel.fromFirebaseUser(freshFirebaseUser);
          }

          // Doğrulama durumunu güncelle
          final isEmailVerified = freshFirebaseUser.emailVerified;

          if (isEmailVerified != userModel.isEmailVerified) {
            AppLogger.i('E-posta doğrulama durumu değişti: $isEmailVerified');

            // Kullanıcı modelini güncelle
            final updatedUser =
                userModel.copyWith(isEmailVerified: isEmailVerified);

            // Firestore'u güncelle
            try {
              await _firestore
                  .collection(_userCollection)
                  .doc(freshFirebaseUser.uid)
                  .update({'isEmailVerified': isEmailVerified});
              AppLogger.i(
                  'Firestore\'daki e-posta doğrulama durumu güncellendi');
            } catch (e) {
              AppLogger.w(
                  'Firestore\'daki e-posta doğrulama durumu güncellenemedi: $e');
              // Yine de güncellenmiş kullanıcıyı döndür
            }

            stopwatch.stop();
            AppLogger.i(
                'E-posta doğrulama durumu güncellendi, süre: ${stopwatch.elapsedMilliseconds}ms');
            return updatedUser;
          }

          stopwatch.stop();
          AppLogger.i(
              'E-posta doğrulama durumu zaten güncel, süre: ${stopwatch.elapsedMilliseconds}ms');
          return userModel;
        } catch (e) {
          stopwatch.stop();
          AppLogger.e(
              'E-posta doğrulama durumu güncellenirken hata: $e, Süre: ${stopwatch.elapsedMilliseconds}ms');
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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
        try {
          final userModel = await _authService.signUpWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
          );

          // E-posta doğrulama gönder
          try {
            await _authService.sendEmailVerification();
          } catch (verificationError) {
            AppLogger.w('E-posta doğrulama gönderilemedi: $verificationError');
            // E-posta doğrulama hatasında işleme devam et
            if (_isNetworkOrFirestoreError(verificationError)) {
              _addPendingOperation(
                _PendingOperation(
                  type: 'SEND_EMAIL_VERIFICATION',
                  execute: () => _authService.sendEmailVerification(),
                  timestamp: DateTime.now(),
                ),
              );
            }
          }

          logSuccess('Kayıt başarılı', 'Kullanıcı ID: ${userModel.id}');
          return userModel;
        } catch (e) {
          // Özel hata mesajları ile yeniden fırlat
          if (_isNetworkOrFirestoreError(e)) {
            AppLogger.e('Kayıt sırasında bağlantı hatası: $e');
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Kayıt yapılırken bağlantı hatası oluştu. Lütfen internet bağlantınızı kontrol edin.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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
        try {
          await _authService.sendEmailVerification();
          logSuccess('E-posta doğrulama gönderildi');
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            _addPendingOperation(
              _PendingOperation(
                type: 'SEND_EMAIL_VERIFICATION',
                execute: () => _authService.sendEmailVerification(),
                timestamp: DateTime.now(),
              ),
            );
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'E-posta doğrulama gönderilirken bağlantı hatası oluştu. Bağlantı sağlandığında otomatik olarak gönderilecek.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
    );
  }

  /// Şifre sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Şifre sıfırlama e-postası gönderme',
      apiCall: () async {
        try {
          await _authService.sendPasswordResetEmail(email);
          logSuccess('Şifre sıfırlama e-postası gönderildi', email);
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            _addPendingOperation(
              _PendingOperation(
                type: 'SEND_PASSWORD_RESET',
                execute: () => _authService.sendPasswordResetEmail(email),
                timestamp: DateTime.now(),
              ),
            );
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Şifre sıfırlama e-postası gönderilirken bağlantı hatası oluştu. Bağlantı sağlandığında otomatik olarak gönderilecek.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
          // Firebase Auth ve Firestore'da güncelle
          final updatedUser = await _authService.updateUserProfile(
            displayName: displayName,
            photoURL: photoURL,
          );

          logSuccess('Profil güncellendi', 'Kullanıcı ID: ${updatedUser.id}');
          return updatedUser;
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            // Mevcut kullanıcı verilerini al
            final user = await getUserData(firebaseUser.uid);
            final updatedUser = user.copyWith(
              displayName: displayName ?? user.displayName,
              photoURL: photoURL ?? user.photoURL,
            );

            _addPendingOperation(
              _PendingOperation(
                type: 'UPDATE_PROFILE',
                execute: () => _authService.updateUserProfile(
                  displayName: displayName,
                  photoURL: photoURL,
                ),
                timestamp: DateTime.now(),
              ),
            );

            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Profil güncellenirken bağlantı hatası oluştu. Bağlantı sağlandığında otomatik olarak güncellenecek.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
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
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Hesap silinirken bağlantı hatası oluştu. Lütfen bağlantınızı kontrol edip tekrar deneyin.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
          // Mevcut kullanıcı verisini al
          final user = await getUserData(firebaseUser.uid);

          // Premium bilgilerini güncelle
          final updatedUser = user.upgradeToPremium();

          // Firestore'da güncelle
          await updateUserData(updatedUser);

          logSuccess('Premium üyeliğe yükseltildi', 'Kullanıcı ID: ${user.id}');
          return updatedUser;
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Premium üyeliğe yükseltme sırasında bağlantı hatası oluştu. Lütfen bağlantınızı kontrol edip tekrar deneyin.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
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
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            final user = await getCurrentUser();
            if (user != null) {
              _addPendingOperation(
                _PendingOperation(
                  type: 'UPDATE_ANALYSIS_CREDITS',
                  execute: () => _authService.updateAnalysisCredits(
                      user.id, newCreditCount),
                  timestamp: DateTime.now(),
                ),
              );
            }
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Analiz kredisi güncellenirken bağlantı hatası oluştu. Bağlantı sağlandığında otomatik olarak güncellenecek.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
          final updatedUser = currentUser.addCredits(amount);
          await updateUserData(updatedUser);

          logSuccess(
            'Kredi eklendi',
            '$amount kredi eklendi. Kullanıcı ID: ${updatedUser.id}',
          );
          return updatedUser;
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            _addPendingOperation(
              _PendingOperation(
                type: 'ADD_ANALYSIS_CREDITS',
                execute: () => addAnalysisCredits(amount),
                timestamp: DateTime.now(),
              ),
            );
            throw FirebaseException(
                plugin: 'UserRepository',
                code: 'network-unavailable',
                message:
                    'Kredi eklenirken bağlantı hatası oluştu. Bağlantı sağlandığında otomatik olarak eklenecek.');
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: false,
      throwError: true,
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

        try {
          final updatedUser = currentUser.useCredit();
          await updateUserData(updatedUser);

          logSuccess(
            'Kredi kullanıldı',
            'Kalan kredi: ${updatedUser.analysisCredits}',
          );
          return updatedUser;
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            // Çevrimdışı olsa bile krediyi düş (UI'da göstermek için)
            // Ama veritabanında güncellemek için bekleyen işleme ekle
            final updatedUser = currentUser.useCredit();
            _addPendingOperation(
              _PendingOperation(
                type: 'USE_ANALYSIS_CREDIT',
                execute: () => updateUserData(updatedUser),
                timestamp: DateTime.now(),
              ),
            );

            // Offline olarak kredi kullanıldığını bildir
            AppLogger.w(
                'Kredi çevrimdışı olarak kullanıldı, bağlantı geldiğinde güncellenecek');
            return updatedUser;
          }
          rethrow;
        }
      },
      ignoreConnectionCheck: true,
      throwError: false,
    );
  }

  /// Firestore'dan kullanıcı verilerini alır
  Future<UserModel> getUserData(String userId) async {
    await _ensureInitialized();

    try {
      // Önce çevrimdışı veriyi kontrol et
      if (!_hasNetworkConnection) {
        AppLogger.i(
            'Ağ bağlantısı yok, önbellekten kullanıcı verisi kontrol ediliyor');
        final cachedUser = await _recoverFromOfflineCache(userId);
        if (cachedUser != null) {
          AppLogger.i('Önbellekten kullanıcı verisi bulundu');
          return cachedUser;
        }
      }

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

      // Çevrimdışı veriyi kontrol et
      final cachedUser = await _recoverFromOfflineCache(userId);
      if (cachedUser != null) {
        AppLogger.i('Önbellekten kullanıcı verisi kullanılıyor');
        return cachedUser;
      }

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
        },
        ignoreConnectionCheck: false,
        throwError: true);
  }

  /// Firestore'a kullanıcı verilerini ekler
  Future<void> createUserData(UserModel user) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Kullanıcı verisi oluşturma',
      apiCall: () async {
        try {
          await _firestore
              .collection(_userCollection)
              .doc(user.id)
              .set(user.toFirestore());

          // Önbelleğe de kaydet
          await cacheData(_userCachePrefix + user.id, user.toFirestore());
          logSuccess(
              'Kullanıcı verisi oluşturuldu', 'Kullanıcı ID: ${user.id}');
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            // Önbelleğe kaydet ve bağlantı geldiğinde işleyecek şekilde ekle
            await cacheData(_userCachePrefix + user.id, user.toFirestore());
            _addPendingOperation(
              _PendingOperation(
                type: 'CREATE_USER_DATA',
                execute: () => _firestore
                    .collection(_userCollection)
                    .doc(user.id)
                    .set(user.toFirestore()),
                timestamp: DateTime.now(),
              ),
            );
            AppLogger.w(
                'Kullanıcı verisi çevrimdışı olarak kaydedildi, bağlantı geldiğinde güncellenecek');
          }
          rethrow;
        }
      },
    );
  }

  /// Firestore'daki kullanıcı verilerini günceller
  Future<void> updateUserData(UserModel user) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Kullanıcı verisi güncelleme',
      apiCall: () async {
        try {
          await _firestore
              .collection(_userCollection)
              .doc(user.id)
              .update(user.toFirestore());

          // Önbelleği de güncelle
          await cacheData(_userCachePrefix + user.id, user.toFirestore());
          logSuccess(
              'Kullanıcı verisi güncellendi', 'Kullanıcı ID: ${user.id}');
        } catch (e) {
          if (_isNetworkOrFirestoreError(e)) {
            // Önbelleğe kaydet ve bağlantı geldiğinde işleyecek şekilde ekle
            await cacheData(_userCachePrefix + user.id, user.toFirestore());
            _addPendingOperation(
              _PendingOperation(
                type: 'UPDATE_USER_DATA',
                execute: () => _firestore
                    .collection(_userCollection)
                    .doc(user.id)
                    .update(user.toFirestore()),
                timestamp: DateTime.now(),
              ),
            );
            AppLogger.w(
                'Kullanıcı verisi çevrimdışı olarak güncellendi, bağlantı geldiğinde güncellenecek');
          }
          rethrow;
        }
      },
    );
  }

  // CacheableMixin metodları
  @override
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await _preferences;
      Map<String, dynamic> cacheableData;

      if (data is Map) {
        // Harita verisini kopyala
        cacheableData = Map<String, dynamic>.from(data);

        // Timestamp nesnelerini DateTime olarak dönüştür
        for (final entry in cacheableData.entries.toList()) {
          if (entry.value is Timestamp) {
            // Timestamp'i milisaniye cinsinden tamsayıya dönüştür
            cacheableData[entry.key] =
                (entry.value as Timestamp).toDate().millisecondsSinceEpoch;
          } else if (entry.value is FieldValue) {
            // FieldValue.serverTimestamp() gibi değerleri çıkar
            cacheableData[entry.key] = DateTime.now().millisecondsSinceEpoch;
          }
        }
      } else {
        cacheableData = {'value': data.toString()};
      }

      final jsonString = jsonEncode(cacheableData);
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

  /// Repository'yi temizler
  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingOperationsTimer?.cancel();
  }
}

/// Bekleyen işlemleri temsil eden sınıf
class _PendingOperation {
  final String type;
  final Future<void> Function() execute;
  final DateTime timestamp;
  final int retryCount;

  _PendingOperation({
    required this.type,
    required this.execute,
    required this.timestamp,
    this.retryCount = 0,
  });

  /// Retry sayacını arttırarak yeni bir işlem döndürür
  _PendingOperation incrementRetry() {
    return _PendingOperation(
      type: type,
      execute: execute,
      timestamp: timestamp,
      retryCount: retryCount + 1,
    );
  }
}
