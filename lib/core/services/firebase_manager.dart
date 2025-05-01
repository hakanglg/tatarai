import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase servislerini merkezi olarak yöneten sınıf
/// Singleton pattern kullanılarak oluşturulmuştur
class FirebaseManager {
  static final FirebaseManager _instance = FirebaseManager._internal();
  factory FirebaseManager() => _instance;

  // Late kullanmak yerine, constructor'da başlatıyoruz
  final FirebaseAuth _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  /// Firebase servislerinin başlatılıp başlatılmadığını kontrol eder
  bool _isInitialized = false;

  /// Maksimum yeniden deneme sayısı
  static const int _maxRetries = 5;

  /// Yeniden denemeler arasındaki bekleme süresi (milisaniye)
  static const int _baseRetryDelay = 1000;

  /// Firestore bağlantı durumu
  bool _isFirestoreConnected = false;

  /// Firestore bağlantı durumunu kontrol eden timer
  Timer? _connectionCheckTimer;

  /// Firebase bağlantısı için yeniden deneme sayacı
  int _retryCount = 0;

  /// Network bağlantı durumu
  bool _hasNetworkConnection = true;

  /// Network bağlantı tipini takip etmek için subscription
  StreamSubscription? _connectivitySubscription;

  // Constructor'da Auth instance'ını doğrudan başlatıyoruz
  FirebaseManager._internal() : _auth = FirebaseAuth.instance {
    // Constructor'da asenkron işlem yapamayız, bunlar initialize() metodunda yapılacak
  }

  /// Firebase servislerini başlatır
  Future<void> initialize() async {
    // Zaten başlatılmışsa, bir şey yapma
    if (_isInitialized) {
      AppLogger.i('FirebaseManager zaten başlatılmış');
      return;
    }

    AppLogger.i('FirebaseManager başlatılıyor...');

    // Bağlantı durumunu kontrol et ve güncellemeleri izle
    try {
      _setupConnectivityListener();
    } catch (e) {
      AppLogger.w(
          'Bağlantı dinleyicisi kurulurken hata oluştu, devam ediliyor', e);
      // Bağlantı dinleyicisi hata verse bile devam et
    }

    try {
      // Bağlantı durumunu kontrol et
      var connectivityResult = await Connectivity().checkConnectivity();
      bool hasConnection = false;

      // Uyumluluk için kontrol ediyoruz
      hasConnection =
          connectivityResult.any((result) => result != ConnectivityResult.none);

      _hasNetworkConnection = hasConnection;
      AppLogger.i('Ağ bağlantısı durumu: $_hasNetworkConnection');

      // Çevrimdışı kalıcılığı etkinleştir
      try {
        await enablePersistence();
        AppLogger.i('Firebase çevrimdışı kalıcılık etkinleştirildi');
      } catch (e) {
        AppLogger.w('Çevrimdışı kalıcılık etkinleştirilemedi: $e');
        // Hata olsa bile devam et
      }

      // Auth zaten constructor'da başlatıldı, burada kontrolü yapalım
      try {
        _auth.app; // Bağlantıyı kontrol et
        AppLogger.i('Firebase Auth başarıyla başlatıldı');
      } catch (e, stackTrace) {
        AppLogger.e('Firebase Auth kontrolü hatası', e, stackTrace);
        throw Exception('Firebase Auth kontrolü hatası: $e');
      }

      // Firebase Firestore başlatma
      try {
        AppLogger.i('Firestore başlatılıyor (databaseId: tatarai)');

        // Firebase uygulama örneğini kontrol et
        final firebaseApp = Firebase.app();
        AppLogger.i(
            'Firebase App: ${firebaseApp.name}, Options: ${firebaseApp.options.projectId}');

        // Firestore instance oluştur
        try {
          _firestore = FirebaseFirestore.instanceFor(
            app: firebaseApp,
            databaseId: 'tatarai',
          );
          AppLogger.i('Firestore (tatarai veritabanı) başarıyla başlatıldı');
        } catch (instanceError) {
          AppLogger.e('Firestore.instanceFor() hatası', instanceError);
          // Yedek olarak varsayılan instance'ı dene
          _firestore = FirebaseFirestore.instance;
          AppLogger.w(
              'Firestore varsayılan instance kullanılıyor (tatarai olmadan)');
        }

        // Firestore ayarlarını iyileştir
        _firestore!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          sslEnabled: true,
        );

        // Çevrimdışı durumda da çalışabilmesi için
        if (!hasConnection) {
          AppLogger.i('Ağ bağlantısı yok, çevrimdışı mod etkinleştiriliyor');
          await _firestore!.disableNetwork();
        } else {
          await _firestore!.enableNetwork();
        }

        AppLogger.i('Firestore yapılandırması: ${_firestore!.settings}');
      } catch (e, stackTrace) {
        AppLogger.e('Firestore başlatma hatası', e, stackTrace);
        throw Exception('Firestore başlatma hatası: $e');
      }

      // Firebase Storage başlatma
      try {
        _storage = FirebaseStorage.instance;
        AppLogger.i('Firebase Storage başarıyla başlatıldı');
      } catch (e, stackTrace) {
        AppLogger.e('Firebase Storage başlatma hatası', e, stackTrace);
        throw Exception('Firebase Storage başlatma hatası: $e');
      }

      // İnternet bağlantısı durumuna göre Firestore ayarlarını yap
      try {
        await _configureFirestoreSettings(hasConnection);
      } catch (e, stackTrace) {
        AppLogger.e('Firestore ayarları yapılandırma hatası', e, stackTrace);
        // Ayarlar yapılandırılamasa bile devam et
      }

      // Bağlantı testi yap (ağ bağlantısı yoksa yapma)
      if (hasConnection) {
        try {
          await _testFirebaseConnection();
          if (_isFirestoreConnected) {
            AppLogger.i('Firebase bağlantı testi başarılı');
          } else {
            AppLogger.w(
                'Firebase bağlantı testi başarısız oldu ama devam ediyor');
          }
        } catch (e, stackTrace) {
          AppLogger.w('Firebase bağlantı testi sırasında hata, devam ediyor', e,
              stackTrace);
          // Bağlantı testi başarısız olsa bile devam et
        }
      } else {
        AppLogger.w('Ağ bağlantısı olmadığı için bağlantı testi atlanıyor');
        _isFirestoreConnected = false;
      }

      // Periyodik bağlantı kontrolünü başlat
      _startConnectionCheckTimer();

      // Başarıyla başlatıldı
      _isInitialized = true;
      AppLogger.i('FirebaseManager başarıyla başlatıldı');
      return;
    } catch (e, stackTrace) {
      AppLogger.e('FirebaseManager başlatma hatası', e, stackTrace);

      // Yeniden deneme mekanizması
      if (_retryCount < _maxRetries) {
        _retryCount++;

        final delay =
            Duration(seconds: _getExponentialBackoffDelay(_retryCount));
        AppLogger.i(
            'FirebaseManager ${delay.inSeconds} saniye sonra tekrar denenecek (deneme $_retryCount/$_maxRetries)');

        await Future.delayed(delay);
        return _retryInitialization();
      } else {
        AppLogger.e(
            'FirebaseManager başlatılamadı, maksimum deneme sayısına ulaşıldı');
        throw Exception('Firebase başlatılamadı: $e');
      }
    }
  }

  /// Başlatma işlemini yeniden dener
  Future<void> _retryInitialization() async {
    AppLogger.i(
        'FirebaseManager yeniden başlatılmaya çalışılıyor (deneme $_retryCount/$_maxRetries)');

    try {
      // Firebase servisleri zaten başlatılmış olmalı, sadece bağlantıyı test et
      await _testFirebaseConnection();

      // Başarılı olursa
      _isInitialized = true;
      AppLogger.i('FirebaseManager başarıyla başlatıldı (deneme $_retryCount)');
      return;
    } catch (e, stackTrace) {
      AppLogger.e(
          'FirebaseManager yeniden başlatma denemesi başarısız ($_retryCount/$_maxRetries)',
          e,
          stackTrace);

      if (_retryCount < _maxRetries) {
        _retryCount++;

        final delay =
            Duration(seconds: _getExponentialBackoffDelay(_retryCount));
        AppLogger.i(
            'FirebaseManager ${delay.inSeconds} saniye sonra tekrar denenecek');

        await Future.delayed(delay);
        return _retryInitialization();
      } else {
        AppLogger.e(
            'FirebaseManager başlatılamadı, maksimum deneme sayısına ulaşıldı');
        throw Exception('Firebase yeniden başlatma başarısız: $e');
      }
    }
  }

  /// Firestore çevrimdışı kalıcılığını etkinleştirir
  Future<void> enablePersistence() async {
    try {
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(
          synchronizeTabs: true,
        ),
      );
      AppLogger.i('Firestore çevrimdışı kalıcılık etkinleştirildi');
    } catch (e) {
      if (e.toString().contains('already enabled')) {
        AppLogger.i('Firestore çevrimdışı kalıcılık zaten etkin');
      } else {
        AppLogger.w('Çevrimdışı kalıcılık etkinleştirilemedi: $e');
        rethrow;
      }
    }
  }

  /// Network bağlantısını izler
  void _monitorConnectivity() {
    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((result) {
        // Eğer birden fazla sonuç varsa (Liste olarak döndüyse), ilk sonucu al
        // API değişikliği nedeniyle uyumluluk sağlanıyor
        ConnectivityResult connectivityResult;
        connectivityResult =
            result.isNotEmpty ? result.first : ConnectivityResult.none;

        final wasConnected = _hasNetworkConnection;
        _hasNetworkConnection = connectivityResult != ConnectivityResult.none;

        // Bağlantı durumu değiştiyse
        if (wasConnected != _hasNetworkConnection) {
          if (_hasNetworkConnection) {
            AppLogger.i('Network bağlantısı kuruldu');
            _attemptReconnection();
          } else {
            AppLogger.w('Network bağlantısı kesildi');
          }
        }
      });
    } catch (e) {
      AppLogger.e('Connectivity izleme hatası', e);
      // İzleme başlatılamazsa, periyodik kontrol mekanizmasına güveniyoruz
    }
  }

  /// Bağlantı kurulduktan sonra Firebase'e yeniden bağlanmaya çalışır
  Future<void> _attemptReconnection() async {
    if (!_isInitialized) return;

    AppLogger.i('Firebase bağlantısı yeniden kuruluyor...');
    _retryCount = 0;

    try {
      await _testFirebaseConnection();
      AppLogger.i('Firebase bağlantısı yeniden kuruldu');
    } catch (e) {
      AppLogger.e('Firebase bağlantısı kurulamadı', e);
      _reconnectWithBackoff();
    }
  }

  /// Bağlantı kesildiğinde backoff stratejisiyle yeniden bağlanır
  Future<void> _reconnectWithBackoff() async {
    _retryCount = 0;
    const maxReconnectRetries = 20; // Daha uzun süre deneme yapılabilir

    while (_retryCount < maxReconnectRetries && !_isFirestoreConnected) {
      try {
        _retryCount++;
        final backoffDelay = _getExponentialBackoffDelay(_retryCount);

        AppLogger.i(
            'Firebase yeniden bağlanma denemesi $_retryCount/$maxReconnectRetries (${backoffDelay}ms sonra)');
        await Future.delayed(Duration(milliseconds: backoffDelay));

        // Network bağlantısını kontrol et
        try {
          var connectivityResult = await Connectivity().checkConnectivity();
          bool hasConnection = false;

          // Uyumluluk için kontrol ediyoruz
          hasConnection = connectivityResult
              .any((result) => result != ConnectivityResult.none);

          if (!hasConnection) {
            AppLogger.w('Network bağlantısı yok, yeniden bağlanma atlanıyor');
            continue;
          }
        } catch (e) {
          AppLogger.w(
              'Connectivity kontrolü hatası, yine de devam ediliyor', e);
          // Connectivity hatası varsa bile devam et
        }

        try {
          await _testFirebaseConnection();
        } catch (e) {
          AppLogger.w('Firebase bağlantı testi hatası', e);
          // Başarısız olsa bile döngüye devam et
          continue;
        }

        if (_isFirestoreConnected) {
          AppLogger.i(
              'Firebase bağlantısı $_retryCount. denemede yeniden kuruldu');
          break;
        }
      } catch (e, stackTrace) {
        AppLogger.e(
            'Firebase yeniden bağlanma hatası (deneme $_retryCount/$maxReconnectRetries)',
            e,
            stackTrace);

        if (_retryCount >= maxReconnectRetries) {
          AppLogger.e(
              'Firebase yeniden bağlanma işlemi başarısız oldu: Maksimum yeniden deneme sayısına ulaşıldı');

          // Bağlantı durumunu yenilemeyi başaramadık, bu durumda hiçbir şey yapmıyoruz
          // ve bağlantı kontrolü zaman aşımında tekrar denenecek
          return;
        }
      }
    }
  }

  /// Firebase bağlantısını test eder
  Future<void> _testFirebaseConnection() async {
    try {
      // Önce network bağlantısı olup olmadığını kontrol et
      try {
        var connectivityResult = await Connectivity().checkConnectivity();
        bool hasConnection = false;

        // Uyumluluk için kontrol ediyoruz
        hasConnection = connectivityResult
            .any((result) => result != ConnectivityResult.none);

        if (!hasConnection) {
          AppLogger.w(
              'Network bağlantısı yok, Firestore offline modda çalışacak');
          _isFirestoreConnected = false;
          return;
        }
        AppLogger.i(
            'Network bağlantısı mevcut, Firestore bağlantı testi yapılıyor...');
        AppLogger.i('Firestore Database ID: tatarai');
      } catch (e) {
        AppLogger.w('Connectivity kontrolü hatası, işleme devam ediliyor', e);
        // Connectivity hatası olsa bile devam et
      }

      // Önce Firebase Auth bağlantısını test et
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        _auth.tenantId;
        AppLogger.i('Firebase Auth bağlantı testi başarılı');
      } catch (e) {
        AppLogger.w('Firebase Auth bağlantı testi başarısız', e);
        // Auth bağlantısı başarısız olsa bile, Firestore'u kontrol edelim
      }

      // Sonra Firestore bağlantısını test et - timeout ile
      try {
        AppLogger.i('Firestore bağlantısı test ediliyor...');
        AppLogger.i(
            'Firestore yapılandırması: ${_firestore?.settings.toString() ?? "null"}');
        AppLogger.i('Firestore host: ${_firestore?.settings.host ?? "null"}');

        await _timeoutFuture(
          _firestore!
              .collection('test')
              .limit(1)
              .get(const GetOptions(source: Source.server)),
          const Duration(seconds: 10),
          'Firestore connection timeout',
        );

        // Bağlantı başarılı
        _isFirestoreConnected = true;
        _retryCount = 0;
        AppLogger.i('Firebase bağlantı testi başarılı');
      } catch (e) {
        _isFirestoreConnected = false;
        AppLogger.e('Firestore bağlantı testi başarısız', e);

        // Daha fazla hata ayıklama bilgisi
        AppLogger.e('Firestore bağlantı hatası detayları:', {
          'hata_tipi': e.runtimeType.toString(),
          'firestore_null': _firestore == null,
          'database_id': 'tatarai',
          'hata_mesajı': e.toString(),
        });

        // Network hatası olup olmadığını kontrol et
        if (e is SocketException ||
            e is TimeoutException ||
            e.toString().contains('network') ||
            e.toString().contains('unavailable')) {
          AppLogger.w('Network kaynaklı bağlantı hatası tespit edildi');
        }

        rethrow;
      }
    } catch (e, stackTrace) {
      _isFirestoreConnected = false;
      AppLogger.e('Firebase bağlantı testi başarısız', e, stackTrace);
      rethrow;
    }
  }

  /// Future'ı belirli bir timeout ile çalıştırır
  Future<T> _timeoutFuture<T>(
    Future<T> future,
    Duration timeout,
    String timeoutMessage,
  ) {
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(timeoutMessage),
    );
  }

  /// Firebase Auth instance'ını döndürür
  FirebaseAuth get auth {
    // Auth doğrudan constructor'da başlatıldığı için her zaman erişilebilir
    return _auth;
  }

  /// Firestore instance'ını döndürür
  FirebaseFirestore get firestore {
    if (!_isInitialized) {
      AppLogger.w('FirebaseManager henüz başlatılmamış, başlatılıyor...');
      unawaited(initialize());
    }
    return _firestore ??
        FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'tatarai',
        );
  }

  /// Firebase Storage instance'ını döndürür
  FirebaseStorage get storage {
    if (!_isInitialized) {
      AppLogger.w('FirebaseManager henüz başlatılmamış, başlatılıyor...');
      unawaited(initialize());
    }
    return _storage ?? FirebaseStorage.instance;
  }

  /// Firebase bağlantı durumunu döndürür
  bool get isConnected {
    return _isFirestoreConnected && _hasNetworkConnection;
  }

  /// Firebase servislerinin başlatılıp başlatılmadığını kontrol eder
  bool get isInitialized {
    return _isInitialized;
  }

  /// Firebase servislerini sıfırlar (test amaçlı)
  Future<void> reset() async {
    try {
      _connectionCheckTimer?.cancel();
      _connectivitySubscription?.cancel();
      await _auth.signOut();
      _isInitialized = false;
      _isFirestoreConnected = false;
      AppLogger.i('Firebase servisleri sıfırlandı');
    } catch (e, stackTrace) {
      AppLogger.e(
          'Firebase servisleri sıfırlanırken hata oluştu', e, stackTrace);
      rethrow;
    }
  }

  /// Sınıf dispose edildiğinde çağrılır
  void dispose() {
    _connectionCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Bağlantı dinleyicisini kurar
  void _setupConnectivityListener() {
    // Mevcut dinleyiciyi temizle
    _connectivitySubscription?.cancel();

    // Yeni dinleyici kur
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      // Uyumluluk için kontrol ediyoruz
      bool hasConnection = false;

      hasConnection = result.any((res) => res != ConnectivityResult.none);

      // Eğer bağlantı durumu değiştiyse
      if (_hasNetworkConnection != hasConnection) {
        _hasNetworkConnection = hasConnection;
        AppLogger.i('Ağ bağlantısı durumu değişti: $_hasNetworkConnection');

        if (hasConnection && !_isFirestoreConnected) {
          AppLogger.i(
              'Ağ bağlantısı yeniden kuruldu, Firebase yeniden bağlanmaya çalışılıyor');
          _attemptReconnection();
        }
      }
    });

    AppLogger.i('Bağlantı dinleyicisi kuruldu');
  }

  /// Firestore ayarlarını yapılandırır
  Future<void> _configureFirestoreSettings(bool hasConnection) async {
    if (_firestore == null) {
      AppLogger.w('Firestore null olduğu için ayarlar yapılandırılamıyor');
      return;
    }

    // Bağlantı durumuna göre farklı ayarlar uygula
    if (hasConnection) {
      // Çevrimiçi mod
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );
      AppLogger.i('Firestore ayarları çevrimiçi mod için yapılandırıldı');
    } else {
      // Çevrimdışı mod
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );
      AppLogger.i('Firestore ayarları çevrimdışı mod için yapılandırıldı');
    }
  }

  /// Periyodik bağlantı kontrolünü başlatır
  void _startConnectionCheckTimer() {
    // Eğer zaten çalışan bir timer varsa durdur
    _connectionCheckTimer?.cancel();

    // Periyodik kontrol için timer başlat
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          // Ağ bağlantısı yoksa kontrol etme
          if (!_hasNetworkConnection) {
            return;
          }

          // Firestore bağlantısını kontrol et
          await _testFirebaseConnection();

          if (!_isFirestoreConnected) {
            _isFirestoreConnected = true;
            AppLogger.i('Firestore bağlantısı yeniden kuruldu');
          }
        } catch (e) {
          if (_isFirestoreConnected) {
            _isFirestoreConnected = false;
            AppLogger.w('Firestore bağlantısı kesildi: $e');
            _reconnectWithBackoff();
          }
        }
      },
    );

    AppLogger.i('Periyodik bağlantı kontrolü başlatıldı');
  }

  /// Üstel geri çekilme gecikmesi hesaplar (exponential backoff)
  int _getExponentialBackoffDelay(int retryAttempt) {
    // Baz gecikme (saniye cinsinden) * 2^(retryAttempt-1)
    // Örneğin: 1, 2, 4, 8, 16, 32, ... saniye
    const baseDelay = 1;
    return baseDelay * (1 << (retryAttempt - 1));
  }
}

// Future'ı beklemeden çalıştırmak için extension
extension FutureExtension on Future {
  static void unawaited(Future future) {
    // Bilinçli olarak await kullanılmıyor
  }
}
