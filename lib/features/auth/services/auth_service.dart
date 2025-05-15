import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  final FirebaseManager _firebaseManager;
  StreamSubscription? _connectivitySubscription;

  /// Ağ bağlantısı durumu
  bool _hasNetworkConnection = true;

  /// Maksimum yeniden deneme sayısı
  static const int _maxRetries = 5;

  /// Yeniden denemeler arasındaki bekleme süresi (milisaniye)
  static const int _retryDelay = 2000;

  /// Offline işlemler için başarısız istekleri depolayan kuyruk
  final List<_PendingOperation> _pendingOperations = [];

  /// Timer for processing pending operations
  Timer? _pendingOperationsTimer;

  /// Varsayılan constructor
  AuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseManager? firebaseManager,
  })  : _firebaseManager = firebaseManager ?? FirebaseManager(),
        _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _initFirebase();
    _setupConnectivityListener();
    _startPendingOperationsTimer();
  }

  /// Firebase servislerini başlat
  Future<void> _initFirebase() async {
    try {
      // Firebase Manager'ı başlat
      if (!_firebaseManager.isInitialized) {
        _logger.i('Firebase Manager başlatılıyor...');
        await _firebaseManager.initialize();
        _logger.i('Firebase Manager başlatıldı');
      }

      // Firebase çevrimdışı kalıcılığı etkinleştir
      await _enableFirestoreOfflinePersistence();
    } catch (e) {
      _logger.e('Firebase Manager başlatma hatası: $e');
    }
  }

  /// Çevrimdışı kalıcılığı etkinleştirir
  Future<void> _enableFirestoreOfflinePersistence() async {
    try {
      // iOS ve Android için kalıcılığı etkinleştir
      _logger.i(
          'Mobil platformlar için çevrimdışı kalıcılık etkinleştiriliyor...');
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _logger.i('Firebase çevrimdışı kalıcılık etkinleştirildi');
    } catch (e) {
      if (e.toString().contains('already enabled')) {
        _logger.i('Firebase çevrimdışı kalıcılık zaten etkin');
      } else {
        _logger.w('Çevrimdışı kalıcılık etkinleştirilemedi: $e');
        // Hata olsa bile devam et
      }
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

      // Bağlantı durumu değiştiyse
      if (previousState != _hasNetworkConnection) {
        _logger.i('Ağ bağlantısı durumu değişti: $_hasNetworkConnection');

        // Bağlantı yeniden kurulduysa
        if (_hasNetworkConnection && !previousState) {
          _logger
              .i('Ağ bağlantısı yeniden kuruldu, bekleyen işlemler işlenecek');
          _processPendingOperations();
        }
      }
    });
  }

  /// Timer başlatarak bekleyen işlemleri işler
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
  }

  /// Bekleyen işlemleri işler
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    _logger.i('Bekleyen ${_pendingOperations.length} işlem işleniyor...');

    final operations = List<_PendingOperation>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        if (DateTime.now().difference(operation.timestamp).inHours > 24) {
          _logger.w('İşlem 24 saatten eski, atlanıyor: ${operation.type}');
          continue;
        }

        _logger.i('İşlem yeniden deneniyor: ${operation.type}');
        await operation.execute();
        _logger.i('İşlem başarıyla tamamlandı: ${operation.type}');
      } catch (e) {
        _logger.e('İşlem başarısız oldu: ${operation.type}, $e');

        // İşlemi yeniden kuyruğa al
        if (operation.retryCount < _maxRetries - 1) {
          _pendingOperations.add(operation.incrementRetry());
        } else {
          _logger.w(
              'Maksimum yeniden deneme sayısına ulaşıldı: ${operation.type}');
        }
      }
    }
  }

  /// İnternet bağlantısını kontrol eder
  Future<bool> _checkNetworkConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult
          .any((result) => result != ConnectivityResult.none);
    } catch (e) {
      _logger.w('Bağlantı kontrolü hatası: $e');
      return false;
    }
  }

  /// Yeniden deneme mekanizması ile işlem yapma
  Future<T> _withRetry<T>(Future<T> Function() operation,
      [String operationName = 'İşlem']) async {
    // Firebase başlatıldığından emin ol
    await _initFirebase();

    // Ağ bağlantısı kontrolü
    final hasConnection = await _checkNetworkConnection();
    if (!hasConnection) {
      _logger
          .w('$operationName: Ağ bağlantısı yok, çevrimdışı modda çalışılıyor');
    }

    int retryCount = 0;
    Exception? lastException;

    while (retryCount < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        retryCount++;
        _logger.w(
          '$operationName başarısız oldu (Deneme $retryCount/$_maxRetries): $e',
        );

        // Firebase bağlantı hatalarını kontrol et
        if (_isNetworkRelatedError(e)) {
          _logger.i('Ağ bağlantısı sorunu tespit edildi');

          if (retryCount < _maxRetries) {
            // Exponential backoff
            final delay = _retryDelay * (1 << (retryCount - 1));
            _logger.i('$delay ms sonra yeniden denenecek...');
            await Future.delayed(Duration(milliseconds: delay));
          } else {
            _logger.e('Maksimum deneme sayısına ulaşıldı: $e');
            throw Exception(
                '$operationName sırasında ağ bağlantısı hatası oluştu. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
          }
        } else {
          // Eğer ağ bağlantısı hatası değilse, tekrar deneme olmadan hata fırlat
          _logger.e('$operationName işlemi başarısız oldu: $e');
          rethrow;
        }
      }
    }

    // Tüm denemeler başarısız oldu
    _logger.e('$operationName için tüm denemeler başarısız oldu');
    throw lastException ??
        Exception('$operationName sırasında beklenmeyen bir hata oluştu');
  }

  /// Hatanın ağ bağlantısı ile ilgili olup olmadığını kontrol eder
  bool _isNetworkRelatedError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('unavailable') ||
        errorString.contains('connection') ||
        errorString.contains('offline') ||
        errorString.contains('socket');
  }

  /// Mevcut giriş yapmış kullanıcıyı stream olarak döndürür
  Stream<UserModel?> get userStream {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return null;
      }

      try {
        return await _withRetry(
          () => getUserFromFirestore(user.uid),
          'Kullanıcı verisi alma',
        );
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
    }, 'Kullanıcı kaydı');
  }

  /// E-posta ve şifre ile giriş yapma işlemini yapar
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _withRetry(() async {
      try {
        _logger.i('E-posta ile giriş başlatılıyor: $email');
        Stopwatch stopwatch = Stopwatch()..start();

        // Önce token yenileme işlemini kaldıralım - bu işlem çok zaman alabilir
        // ve giriş sırasında gerekli değil, giriş sonrası arka planda yapılabilir
        // await _renewFirebaseToken();

        // Firebase Auth doğrulaması başlatılıyor
        _logger.d('Firebase Auth doğrulaması yapılıyor...');

        // Timeout ekleyerek giriş işlemini sınırlayalım
        final userCredential = await _firebaseAuth
            .signInWithEmailAndPassword(
              email: email,
              password: password,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  throw TimeoutException('Giriş işlemi zaman aşımına uğradı'),
            );

        final user = userCredential.user!;
        _logger
            .i('Firebase Auth doğrulaması başarılı, kullanıcı ID: ${user.uid}');

        // Temel kullanıcı modeli oluştur - Firestore verisi olmadan hızlıca dönüş yapmak için
        final basicUserModel = UserModel.fromFirebaseUser(user);

        // Firestore'dan kullanıcı bilgilerini arka planda getir
        _logger.d('Firestore\'dan kullanıcı verisi arka planda alınacak...');

        // Token yenileme işlemini arka planda gerçekleştir
        unawaited(_renewFirebaseTokenInBackground());

        // Giriş zamanını güncelle - arka planda
        unawaited(_updateLoginTimestamp(basicUserModel));

        stopwatch.stop();
        _logger.i(
            'Giriş işlemi tamamlandı: ${user.uid}, süre: ${stopwatch.elapsedMilliseconds}ms');

        return basicUserModel;
      } on firebase_auth.FirebaseAuthException catch (e) {
        _logger.w('Giriş hatası: ${e.code}, Mesaj: ${e.message}');
        throw _handleAuthException(e);
      } on TimeoutException catch (e) {
        _logger.e('Giriş zaman aşımı: $e');
        throw Exception(
            'Giriş işlemi zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
      } catch (e) {
        _logger.e('Beklenmeyen giriş hatası: $e');
        throw Exception(
            'Giriş işlemi sırasında beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
      }
    }, 'Kullanıcı girişi');
  }

  /// Token yenileme işlemini arka planda gerçekleştirir
  Future<void> _renewFirebaseTokenInBackground() async {
    try {
      await _renewFirebaseToken();
      _logger.i('Firebase token arka planda yenilendi');
    } catch (e) {
      _logger.w('Arka planda token yenileme hatası: $e');
      // Hata olsa bile sessizce devam et
    }
  }

  /// Giriş zamanını arka planda günceller
  Future<void> _updateLoginTimestamp(UserModel userModel) async {
    try {
      // Firestore'a güncelleme yap
      final updatedModel = userModel.copyWith(
        lastLoginAt: DateTime.now(),
      );

      await saveUserToFirestore(updatedModel);
      _logger.i('Kullanıcı giriş tarihi arka planda güncellendi');
    } catch (e) {
      _logger.w('Giriş tarihi güncellenemedi: $e');

      // Güncelleme hatası durumunda bekleyen işlemlere ekle
      _addPendingOperation(
        _PendingOperation(
          type: 'UPDATE_LOGIN_TIMESTAMP',
          execute: () => saveUserToFirestore(
              userModel.copyWith(lastLoginAt: DateTime.now())),
          timestamp: DateTime.now(),
        ),
      );
    }
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
    }, 'Kullanıcı çıkışı');
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

      if (_isNetworkRelatedError(e)) {
        // Ağ bağlantısı hatasıysa bekleyen işlemlere ekle
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          _addPendingOperation(
            _PendingOperation(
              type: 'SEND_EMAIL_VERIFICATION',
              execute: () => currentUser.sendEmailVerification(),
              timestamp: DateTime.now(),
            ),
          );
          _logger.i('E-posta doğrulama bekleyen işlemlere eklendi');
        }
      }

      throw Exception(
          'E-posta doğrulama bağlantısı gönderilirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// E-posta doğrulama durumunu kontrol eder
  Future<bool> checkEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;

      if (user == null) {
        _logger.w('E-posta doğrulama kontrolü: Kullanıcı oturum açmamış');
        return false;
      }

      // Önce kullanıcıyı sunucudan yenile
      try {
        await user.reload();
        _logger.i('Kullanıcı bilgileri sunucudan yenilendi');
      } catch (e) {
        _logger.w('Kullanıcı bilgileri yenilenirken hata: $e');
        // Hata olsa bile devam et, mevcut durumu kullan
      }

      // Yenilenen kullanıcıyı al
      final freshUser = _firebaseAuth.currentUser;
      if (freshUser == null) {
        _logger.w('Kullanıcı bilgileri yenilendikten sonra null');
        return false;
      }

      if (freshUser.emailVerified) {
        _logger.i('E-posta doğrulandı: ${freshUser.email}');

        // Firestore'daki kullanıcı bilgilerini güncelle
        try {
          final userModel = await getUserFromFirestore(freshUser.uid);

          // Eğer Firestore'daki veri güncel değilse güncelle
          if (!userModel.isEmailVerified) {
            final updatedModel = userModel.copyWith(isEmailVerified: true);
            await saveUserToFirestore(updatedModel);
            _logger.i(
                'Kullanıcı e-posta doğrulama durumu Firestore\'da güncellendi');
          } else {
            _logger.i('Kullanıcı e-posta doğrulama durumu zaten güncel');
          }
        } catch (e) {
          _logger.w('Kullanıcı e-posta doğrulama durumu güncellenemedi: $e');

          // Ağ bağlantısı hatasıysa bekleyen işlemlere ekle
          if (_isNetworkRelatedError(e)) {
            try {
              // Önce kullanıcı verisini almayı dene
              final userModel = await getUserFromFirestore(freshUser.uid);

              // Veri varsa ve güncellenmesi gerekiyorsa bekleyen işlemlere ekle
              if (!userModel.isEmailVerified) {
                final updatedModel = userModel.copyWith(isEmailVerified: true);

                _addPendingOperation(
                  _PendingOperation(
                    type: 'UPDATE_EMAIL_VERIFICATION_STATUS',
                    execute: () => saveUserToFirestore(updatedModel),
                    timestamp: DateTime.now(),
                  ),
                );
                _logger.i(
                    'E-posta doğrulama durumu güncelleme işlemi kuyruğa eklendi');
              }
            } catch (innerError) {
              _logger.e('Bekleyen işlem oluşturma hatası: $innerError');
            }
          }
        }

        return true;
      } else {
        _logger.i('E-posta henüz doğrulanmadı');
        return false;
      }
    } catch (e) {
      _logger.e('E-posta doğrulama kontrolü hatası: $e');
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

      // Ağ bağlantısı hatasıysa bekleyen işlemlere ekle
      if (_isNetworkRelatedError(e)) {
        _addPendingOperation(
          _PendingOperation(
            type: 'SEND_PASSWORD_RESET',
            execute: () => _firebaseAuth.sendPasswordResetEmail(email: email),
            timestamp: DateTime.now(),
          ),
        );
        _logger.i('Şifre sıfırlama bekleyen işlemlere eklendi: $email');
      }

      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Beklenmeyen şifre sıfırlama hatası: $e');
      throw Exception(
          'Şifre sıfırlama e-postası gönderilirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Hesap silme - Firebase Authentication'dan kullanıcıyı siler
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil.');
    }

    final userId = user.uid;
    _logger.i('🔄 Authentication hesabı silme işlemi başlatıldı: $userId');

    try {
      // Firebase Authentication'dan kullanıcıyı sil
      await user.delete();
      _logger.i('✅ Firebase Authentication hesabı silindi: $userId');

      // Başarılı silme durumunda oturumu kapat
      await _firebaseAuth.signOut();
      _logger.i('✅ Hesap silme sonrası oturum kapatıldı');

      return;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e(
          '❌ Firebase Authentication hesabı silinirken hata: ${e.code} - ${e.message}');

      if (e.code == 'requires-recent-login') {
        // Yeniden giriş gerektiği durumda oturumu kapat
        await _firebaseAuth.signOut();
        _logger.i('⚠️ Yeniden giriş gerektiği için oturum kapatıldı');
        throw Exception('REQUIRES_REAUTH');
      }

      // Diğer Authentication hataları için
      throw Exception('AUTH_DELETE_ERROR:${e.code}');
    } catch (e) {
      _logger.e('❌ Beklenmeyen hesap silme hatası: $e');
      throw Exception('AUTH_DELETE_UNKNOWN_ERROR');
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

      // Profil güncellemeyi bekleyen işlemlere ekle
      if (_isNetworkRelatedError(e)) {
        try {
          final user = _firebaseAuth.currentUser;
          if (user != null) {
            final userModel = await getUserFromFirestore(user.uid);
            final updatedUserModel = userModel.copyWith(
              displayName: displayName ?? userModel.displayName,
              photoURL: photoURL ?? userModel.photoURL,
            );

            _addPendingOperation(
              _PendingOperation(
                type: 'UPDATE_USER_PROFILE',
                execute: () => saveUserToFirestore(updatedUserModel),
                timestamp: DateTime.now(),
              ),
            );
            _logger.i('Profil güncelleme bekleyen işlemlere eklendi');
          }
        } catch (innerError) {
          _logger.e('Bekleyen işlem oluşturma hatası: $innerError');
        }
      }

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

      // Kredi güncellemeyi bekleyen işlemlere ekle
      if (_isNetworkRelatedError(e)) {
        try {
          final userModel = await getUserFromFirestore(userId);
          final updatedUserModel = userModel.copyWith(
            analysisCredits: credits,
          );

          _addPendingOperation(
            _PendingOperation(
              type: 'UPDATE_ANALYSIS_CREDITS',
              execute: () => saveUserToFirestore(updatedUserModel),
              timestamp: DateTime.now(),
            ),
          );
          _logger.i('Kredi güncelleme bekleyen işlemlere eklendi');
        } catch (innerError) {
          _logger.e('Bekleyen işlem oluşturma hatası: $innerError');
        }
      }

      throw Exception(
          'Kullanıcı kredileri güncellenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Firestore'dan kullanıcı bilgilerini alır
  Future<UserModel> getUserFromFirestore(String userId) async {
    try {
      _logger.d('Firestore\'dan kullanıcı verisi alınıyor: $userId');

      // Retry ile Firestore'dan veri alma
      final docSnapshot = await _withRetry(
        () => _firestore.collection('users').doc(userId).get(),
        'Kullanıcı verisi alma',
      );

      if (docSnapshot.exists) {
        _logger.d('Kullanıcı verisi bulundu');
        final data = docSnapshot.data();
        if (data != null) {
          final user = UserModel.fromFirestore(docSnapshot);
          _logger.d('Kullanıcı modeli oluşturuldu: ${user.email}');
          return user;
        }
      }

      _logger.w(
          'Firestore\'da kullanıcı dokümanı bulunamadı, varsayılan model oluşturuluyor');
      // Eğer Firestore'da veri yoksa, Firebase Auth'dan bir model oluştur
      final authUser = _firebaseAuth.currentUser;
      if (authUser != null && authUser.uid == userId) {
        final userModel = UserModel(
          id: userId,
          email: authUser.email ?? '',
          displayName: authUser.displayName,
          isEmailVerified: authUser.emailVerified,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          role: UserRole.free,
          analysisCredits: 3,
          favoriteAnalysisIds: const [],
        );

        // Otomatik olarak Firestore'a kaydet
        try {
          await saveUserToFirestore(userModel);
        } catch (e) {
          _logger.w('Yeni kullanıcı verisi kaydedilemedi: $e');
          // Ağ bağlantısı hatasıysa bekleyen işlemlere ekle
          if (_isNetworkRelatedError(e)) {
            _addPendingOperation(
              _PendingOperation(
                type: 'SAVE_NEW_USER',
                execute: () => saveUserToFirestore(userModel),
                timestamp: DateTime.now(),
              ),
            );
          }
        }
        return userModel;
      }

      throw Exception('Kullanıcı bilgileri alınamadı');
    } catch (e) {
      _logger.e('Firestore\'dan kullanıcı alma hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı bilgilerini Firestore'a kaydeder
  Future<void> saveUserToFirestore(UserModel user) async {
    try {
      _logger.d('Kullanıcı Firestore\'a kaydediliyor: ${user.id}');

      // Retry mekanizmasıyla Firestore'a kaydetme
      await _withRetry(
        () => _firestore.collection('users').doc(user.id).set(
              user.toFirestore(),
              SetOptions(merge: true),
            ),
        'Kullanıcı verisi kaydetme',
      );

      _logger.i('Kullanıcı Firestore\'a kaydedildi: ${user.email}');
    } catch (e) {
      _logger.e('Firestore\'a kullanıcı kaydetme hatası: $e');

      // Ağ bağlantısı hatasıysa bekleyen işlemlere ekle
      if (_isNetworkRelatedError(e)) {
        _addPendingOperation(
          _PendingOperation(
            type: 'SAVE_USER_TO_FIRESTORE',
            execute: () => _firestore.collection('users').doc(user.id).set(
                  user.toFirestore(),
                  SetOptions(merge: true),
                ),
            timestamp: DateTime.now(),
          ),
        );
        _logger.i('Kullanıcı kaydetme bekleyen işlemlere eklendi: ${user.id}');
      }

      throw Exception('Kullanıcı bilgileri kaydedilemedi: $e');
    }
  }

  /// Bekleyen işlemlere ekler
  void _addPendingOperation(_PendingOperation operation) {
    _pendingOperations.add(operation);
    _logger.i(
        'Bekleyen işlem eklendi: ${operation.type}, toplam: ${_pendingOperations.length}');
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

  /// Kaynakları temizler
  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingOperationsTimer?.cancel();
  }

  /// Firebase token'ını yeniler
  Future<void> _renewFirebaseToken() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.getIdToken(true);
        _logger.i('Firebase token yenilendi, userId: ${currentUser.uid}');
      }
    } catch (e) {
      _logger.w('Token yenilenirken hata oluştu: $e');
      // Hata olsa bile devam et
    }
  }

  /// Google veya diğer sağlayıcılar üzerinden kimlik bilgileriyle giriş yapar
  Future<firebase_auth.UserCredential> signInWithCredential(
      firebase_auth.AuthCredential credential,
      [bool persistSession = true] // Varsayılan olarak kalıcı oturum açma
      ) async {
    // Kalıcı oturum açma ayarını kontrol et
    if (persistSession) {
      try {
        // (Mobilde setPersistence gereksiz ve hata verir, tamamen kaldırıldı)
      } catch (e) {
        _logger.w('Kalıcı oturum açma ayarlanamadı: $e');
      }
    }

    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Kayıt ol - yeni kullanıcı oluşturur
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// E-posta ve şifre ile giriş yapar
  Future<firebase_auth.UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    return _withRetry<firebase_auth.UserCredential>(() async {
      // Kalıcılık ayarı (Beni hatırla özelliği için)
      if (rememberMe) {
        // (Mobilde setPersistence gereksiz ve hata verir, tamamen kaldırıldı)
      } else {
        // (Mobilde setPersistence gereksiz ve hata verir, tamamen kaldırıldı)
      }

      // Giriş işlemi
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _logger.i('E-posta ile giriş başarılı: ${credential.user?.email}');
      return credential;
    }, 'E-posta ile giriş yapma');
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

  /// Retry sayacını arttırıp yeni bir operasyon döndürür
  _PendingOperation incrementRetry() {
    return _PendingOperation(
      type: type,
      execute: execute,
      timestamp: timestamp,
      retryCount: retryCount + 1,
    );
  }
}
