import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Kimlik doğrulama ve kullanıcı yönetimi için Cubit
class AuthCubit extends BaseCubit<AuthState> {
  final UserRepository _userRepository;
  final AuthService _authService;
  StreamSubscription<UserModel?>? _userSubscription;
  Timer? _emailVerificationTimer;
  StreamSubscription? _connectivitySubscription;

  /// İnternet bağlantısı durumu
  bool _hasNetworkConnection = true;

  /// Bekleyen işlem türleri
  bool _hasPendingSignIn = false;
  bool _hasPendingSignUp = false;

  /// Son bağlantı hatası zamanı - art arda çok fazla hata göstermeyi önlemek için
  DateTime? _lastConnectionErrorTime;

  /// Otomatik yeniden bağlanma timer'ı
  Timer? _reconnectTimer;

  AuthCubit({
    required UserRepository userRepository,
    required AuthService authService,
  })  : _userRepository = userRepository,
        _authService = authService,
        super(AuthState.initial()) {
    _init();
  }

  /// Kullanıcı verilerini gerçek zamanlı olarak dinleyen stream
  Stream<UserModel?> get userStream => _userRepository.user;

  @override
  void emitErrorState(String errorMessage) {
    emit(state.copyWith(
      status: AuthStatus.error,
      errorMessage: errorMessage,
      isLoading: false,
    ));
  }

  @override
  void emitLoadingState() {
    emit(state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      errorMessage: null,
    ));
  }

  /// Hata uyarılarını işleme wrapper
  void handleWarning(String operation, String message) {
    AppLogger.w('$operation: $message');
  }

  /// Log Error wrapper
  void logError(String message, String detail) {
    handleError(message, Exception(detail));
  }

  /// Log Warning wrapper
  void logWarning(String message, [dynamic detail]) {
    if (detail != null) {
      handleWarning(message, detail.toString());
    } else {
      handleWarning(message, '');
    }
  }

  /// Cubit başlangıç fonksiyonu - user subscription'ı başlatır
  void _init() {
    try {
      logInfo('AuthCubit başlatılıyor');
      _subscribeToUserChanges();
      _setupConnectivityListener();
    } catch (e, stack) {
      handleError('AuthCubit başlatma', e, stack);
      emitErrorState('Kimlik doğrulama servisi başlatılamadı');
    }
  }

  /// Ağ bağlantısı değişikliklerini dinler
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final previousState = _hasNetworkConnection;
      _hasNetworkConnection =
          results.any((result) => result != ConnectivityResult.none);

      if (previousState != _hasNetworkConnection) {
        logInfo('Ağ bağlantısı durumu değişti: $_hasNetworkConnection');

        if (_hasNetworkConnection && !previousState) {
          logInfo('Ağ bağlantısı geri geldi, yeniden bağlanmaya çalışılıyor');

          // Bağlantı geri geldiğinde Firebase ile yeniden bağlantı kurmaya çalış
          _reconnectToFirebase();

          // Bekleyen işlemleri kontrol et
          _checkPendingOperations();
        }
      }
    });
  }

  /// Firebase ile yeniden bağlantı kurmaya çalışır
  Future<void> _reconnectToFirebase() async {
    try {
      // Kullanıcı aboneliğini yenile
      _subscribeToUserChanges();

      // Eğer oturum açık ise, kullanıcı verilerini yenile
      if (state.user != null) {
        final userId = state.user!.id;
        logInfo('Kullanıcı verilerini yenilemeye çalışılıyor: $userId');

        try {
          final freshUser = await _userRepository.fetchFreshUserData(userId);
          if (freshUser != null) {
            logSuccess('Kullanıcı verileri yenilendi',
                'Kullanıcı: ${freshUser.email}');
            emit(state.copyWith(user: freshUser));
          }
        } catch (e) {
          logError('Kullanıcı verilerini yenileme hatası', e.toString());
          // Kullanıcı deneyimi açısından hata mesajı göstermeyelim
        }
      }
    } catch (e, stack) {
      handleError('Firebase yeniden bağlantı', e, stack);
    }
  }

  /// Bekleyen işlemleri kontrol eder
  void _checkPendingOperations() {
    // Bekleyen oturum açma işlemi varsa kullanıcıya bildir
    if (_hasPendingSignIn) {
      logInfo('Bekleyen oturum açma işlemi var, lütfen tekrar deneyin');
      emit(state.copyWith(
        pendingOperationMessage:
            'İnternet bağlantınız geri geldi. Lütfen oturum açma işlemini tekrar deneyin.',
      ));
      _hasPendingSignIn = false;
    }

    // Bekleyen kayıt işlemi varsa kullanıcıya bildir
    if (_hasPendingSignUp) {
      logInfo('Bekleyen kayıt işlemi var, lütfen tekrar deneyin');
      emit(state.copyWith(
        pendingOperationMessage:
            'İnternet bağlantınız geri geldi. Lütfen kayıt işlemini tekrar deneyin.',
      ));
      _hasPendingSignUp = false;
    }
  }

  /// Kullanıcı değişikliklerini dinler
  void _subscribeToUserChanges() {
    _userSubscription?.cancel();
    _userSubscription = _userRepository.user.listen(
      _onUserChanged,
      onError: _onUserError,
    );
  }

  /// Kullanıcı değiştiğinde çağrılır
  void _onUserChanged(UserModel? user) {
    try {
      if (user != null) {
        logInfo('Kullanıcı oturum açtı: ${user.email}');

        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
            errorMessage: null,
            pendingOperationMessage: null,
          ),
        );

        if (!user.isEmailVerified) {
          startEmailVerificationCheck();
        }
      } else {
        logInfo('Kullanıcı oturum açmadı');
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            isLoading: false,
            errorMessage: null,
          ),
        );
        stopEmailVerificationCheck();
      }
    } catch (e, stack) {
      handleError('Kullanıcı durumu işleme', e, stack);
    }
  }

  /// Kullanıcı stream'inde hata olduğunda çağrılır
  void _onUserError(Object error, StackTrace stack) {
    handleError('Kullanıcı dinleme', error, stack);

    // Ağ bağlantısıyla ilgili hataları daha kullanıcı dostu şekilde göster
    String errorMessage = error.toString();

    if (_isNetworkError(error)) {
      // Son bağlantı hatası üzerinden 30 saniye geçtiyse göster
      final now = DateTime.now();
      final showError = _lastConnectionErrorTime == null ||
          now.difference(_lastConnectionErrorTime!).inSeconds > 30;

      if (showError) {
        _lastConnectionErrorTime = now;
        errorMessage =
            'Sunucuya bağlanırken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.';

        // Yeniden bağlantı timer'ı başlat (eğer zaten çalışmıyorsa)
        _startReconnectTimer();
      } else {
        // Çok fazla hata mesajı göstermemek için sessizce devam et
        logWarning('Ağ bağlantısı hatası (sessiz): ${error.toString()}');
        return;
      }
    }

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage: errorMessage,
      ),
    );
    stopEmailVerificationCheck();
  }

  /// Yeniden bağlantı kurmak için timer başlatır
  void _startReconnectTimer() {
    _reconnectTimer?.cancel();

    // 10 saniyede bir yeniden bağlanmayı dene
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (_hasNetworkConnection) {
          logInfo('Otomatik yeniden bağlanma deneniyor...');
          await _reconnectToFirebase();

          // Başarılı olduysa timer'ı durdur
          if (state.status == AuthStatus.authenticated) {
            logSuccess('Yeniden bağlantı başarılı');
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
          }
        }
      },
    );
  }

  /// Hatanın ağ bağlantısıyla ilgili olup olmadığını kontrol eder
  bool _isNetworkError(Object error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('unavailable') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('offline') ||
        errorMessage.contains('socket') ||
        errorMessage.contains('internet');
  }

  /// Asenkron işlem başlatma
  void _startLoading() {
    emitLoadingState();
  }

  /// Hata durumlarını işleyen özel metod.
  void _handleError(String operation, Object error, [StackTrace? stackTrace]) {
    handleError(operation, error, stackTrace);

    String userFriendlyMessage;

    // Firebase hata mesajlarını özelleştir
    if (error.toString().contains('firebase_auth') ||
        error.toString().contains('FirebaseAuth')) {
      if (error.toString().contains('network-request-failed')) {
        userFriendlyMessage =
            'İnternet bağlantınızda bir sorun var. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.';
      } else if (error.toString().contains('too-many-requests')) {
        userFriendlyMessage =
            'Çok fazla istek gönderildi. Lütfen bir süre bekleyip tekrar deneyin.';
      } else if (error.toString().contains('email-already-in-use')) {
        userFriendlyMessage =
            'Bu e-posta adresi zaten kullanılıyor. Lütfen başka bir e-posta adresi deneyin.';
      } else if (error.toString().contains('weak-password')) {
        userFriendlyMessage =
            'Şifreniz çok zayıf. Lütfen en az 6 karakter içeren daha güçlü bir şifre belirleyin.';
      } else if (error.toString().contains('invalid-email')) {
        userFriendlyMessage =
            'Geçersiz e-posta adresi. Lütfen geçerli bir e-posta adresi girin.';
      } else if (error.toString().contains('user-not-found') ||
          error.toString().contains('wrong-password')) {
        userFriendlyMessage =
            'E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol edin.';
      } else if (error.toString().contains('createUserWithEmailAndPassword')) {
        userFriendlyMessage =
            'Hesap oluşturulurken bir sorun oluştu. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
      } else {
        // Genel Firebase hatası
        userFriendlyMessage =
            'İşlem sırasında bir sorun oluştu. Lütfen daha sonra tekrar deneyin.';
      }
    } else if (error.toString().contains('timeout') ||
        error.toString().contains('timed out')) {
      userFriendlyMessage =
          'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (_isNetworkError(error)) {
      userFriendlyMessage =
          'İnternet bağlantınızda bir sorun var. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.';
    } else {
      // Genel hata
      userFriendlyMessage =
          'Bir sorun oluştu. Lütfen daha sonra tekrar deneyin.';
    }

    emit(state.copyWith(
      status: state.user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      isLoading: false,
      errorMessage: userFriendlyMessage,
    ));
  }

  /// E-posta ve şifre ile giriş yapar
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // İnternet bağlantısı kontrolü
      if (!_hasNetworkConnection) {
        logWarning('İnternet bağlantısı yok, giriş yapılamıyor');
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage:
              'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.',
        ));
        _hasPendingSignIn = true;
        return;
      }

      _startLoading();
      logInfo('Giriş yapılıyor: $email');

      // Timeout ekle - 60 saniye sonra işlem tamamlanmazsa hata dön
      Timer? timeoutTimer;
      timeoutTimer = Timer(const Duration(seconds: 60), () {
        if (state.isLoading) {
          handleError(
              'Giriş timeout',
              Exception(
                  'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.'));
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            isLoading: false,
            errorMessage:
                'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
          ));
        }
      });

      // En fazla 3 kez yeniden deneme stratejisi ile giriş yap
      int retryCount = 0;
      UserModel? userModel;
      Exception? lastException;

      while (retryCount < 3 && userModel == null) {
        try {
          // İşlem mesajını güncelle
          emit(state.copyWith(
            pendingOperationMessage: retryCount > 0
                ? 'Giriş yapılıyor (${retryCount + 1}/3)...'
                : 'Giriş yapılıyor...',
            isLoading: true,
          ));

          logInfo('Giriş denemesi ${retryCount + 1}/3');

          userModel = await _userRepository.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Başarılı giriş
          if (userModel != null) {
            timeoutTimer.cancel(); // Timeout'u iptal et
            logInfo('Giriş başarılı: ${userModel.email}');
            logSuccess('Giriş yapıldı', 'Kullanıcı: ${userModel.email}');

            // Oturum başarıyla açıldığında state güncellemesi
            emit(state.copyWith(
              status: AuthStatus.authenticated,
              user: userModel,
              isLoading: false,
              errorMessage: null,
              pendingOperationMessage: null,
            ));

            // E-posta doğrulama durumunu kontrol et
            if (!userModel.isEmailVerified) {
              startEmailVerificationCheck();
            }

            // Başarılı giriş sonrası işlemler...
            _hasPendingSignIn = false;
            return;
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          logWarning('Giriş denemesi ${retryCount + 1} başarısız: $e');

          // Ağ hatası veya zaman aşımı hatası ise yeniden deneme
          if (_isNetworkError(e)) {
            retryCount++;

            if (retryCount < 3) {
              // Üstel geri çekilme stratejisi (exponential backoff)
              final backoffMs = 1000 * (1 << (retryCount - 1)); // 1s, 2s, 4s
              logInfo(
                  'Ağ hatası nedeniyle ${backoffMs}ms sonra tekrar deneniyor');

              // Bekleyen işlem mesajını güncelle
              emit(state.copyWith(
                pendingOperationMessage:
                    'Bağlantı hatası nedeniyle ${backoffMs ~/ 1000} saniye sonra tekrar denenecek...',
                isLoading: true,
              ));

              await Future.delayed(Duration(milliseconds: backoffMs));
            }
          } else {
            // Ağ hatası değilse (kimlik bilgileri hatası vb.), tekrar denemeyi durdur
            timeoutTimer.cancel();
            _handleError('Giriş', e);
            return;
          }
        }
      }

      // Tüm denemeler tamamlandı ama hala başarısız
      if (userModel == null) {
        timeoutTimer.cancel();
        final errorMessage =
            lastException?.toString() ?? 'Bilinmeyen bir hata oluştu';

        if (lastException != null && _isNetworkError(lastException)) {
          _handleError(
              'Giriş',
              Exception(
                  'İnternet bağlantısı sorunu nedeniyle giriş yapılamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.'));
        } else {
          _handleError(
              'Giriş',
              lastException ??
                  Exception('Giriş yapılamadı, lütfen tekrar deneyin.'));
        }
      }
    } catch (e, stack) {
      handleError('Giriş işlemi', e, stack);
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: 'Giriş işlemi sırasında bir hata oluştu: ${e.toString()}',
      ));
    }
  }

  /// Google ile giriş yapar
  Future<void> signInWithGoogle() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        emit(state.copyWith(isLoading: true, errorMessage: null));

        // GoogleSignIn nesnesini oluşturma
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
          signInOption: SignInOption.standard, // Native platformu kullan
          hostedDomain: null, // Tüm domain'lere izin ver
        );

        // Önce mevcut oturumu kapatmayı dene
        try {
          await googleSignIn.signOut();
        } catch (e) {
          // Sessizce devam et
          logWarning('Google sign out sırasında hata: $e');
        }

        // Google ile giriş diyaloğunu göster
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        // Kullanıcı işlemi iptal ettiyse
        if (googleUser == null) {
          emit(state.copyWith(isLoading: false));
          return;
        }

        logInfo('Google kullanıcısı seçildi: ${googleUser.email}');

        // Google kimlik doğrulama bilgilerini al
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        logInfo(
            'Google authentication alındı, accessToken: ${googleAuth.accessToken != null}');

        // Firebase kimlik bilgilerini oluştur
        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Firebase'e giriş yap
        logInfo('Firebase\'e Google credential ile giriş yapılıyor...');

        try {
          // Kalıcı oturum açma (true parametresi)
          final userCredential = await _timeoutFuture(
              _authService.signInWithCredential(credential, true),
              const Duration(seconds: 30),
              'Google ile giriş zaman aşımına uğradı');

          if (userCredential.user != null) {
            logSuccess('Google',
                'Google ile giriş başarılı: ${userCredential.user?.email}');

            // User'ı kaydet
            try {
              final basicUser =
                  UserModel.fromFirebaseUser(userCredential.user!);

              // AuthService üzerinden Firestore'a kaydet
              await _authService.saveUserToFirestore(basicUser.copyWith(
                lastLoginAt: DateTime.now(),
              ));

              logInfo('Google kullanıcısı veritabanına kaydedildi/güncellendi');
            } catch (dbError) {
              logWarning(
                  'Kullanıcı veritabanına kaydedilemedi, ama giriş başarılı: $dbError');
            }

            // Başarılı giriş
            emit(state.copyWith(
              isLoading: false,
              errorMessage: null,
            ));
            return;
          } else {
            logError('Google ile giriş başarısız', 'Kullanıcı null');
            emit(state.copyWith(
              isLoading: false,
              errorMessage: 'Google ile giriş yapılamadı.',
            ));
            return;
          }
        } catch (firebaseError) {
          // Firebase hatası durumunda, unavailable hatası için yeniden dene
          if (firebaseError.toString().contains('unavailable') &&
              retryCount < maxRetries - 1) {
            retryCount++;
            final retryDelay = _getExponentialBackoffDelay(retryCount);
            logWarning('Firebase geçici olarak kullanılamıyor',
                '$retryDelay saniye sonra tekrar denenecek (${retryCount}/${maxRetries - 1})');

            // Kullanıcıya bilgi ver
            emit(state.copyWith(
              isLoading: true,
              errorMessage: null,
              pendingOperationMessage:
                  'Sunucuya bağlanılamadı. $retryDelay saniye içinde tekrar deneniyor...',
            ));

            await Future.delayed(Duration(seconds: retryDelay));
            continue;
          } else {
            // Diğer hatalar veya son deneme başarısız oldu
            throw firebaseError;
          }
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        logError('Firebase Auth Hatası', '${e.code} - ${e.message}');
        emit(state.copyWith(
          isLoading: false,
          errorMessage: getErrorMessage(e),
        ));
        return;
      } catch (e) {
        logError('Google Sign In Hatası', e.toString());
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Google ile giriş sırasında bir hata oluştu: $e',
        ));
        return;
      }
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
      onTimeout: () {
        throw TimeoutException(timeoutMessage);
      },
    );
  }

  /// Üstel geri çekilme gecikmesi hesaplar (exponential backoff)
  int _getExponentialBackoffDelay(int retryAttempt) {
    // Baz gecikme (saniye cinsinden) * 2^(retryAttempt-1)
    // Örneğin: 2, 4, 8, 16, 32, ... saniye
    const baseDelay = 2;
    return baseDelay * (1 << (retryAttempt - 1));
  }

  /// E-posta ve şifre ile kayıt oluşturur
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // İnternet bağlantısı kontrolü
      if (!_hasNetworkConnection) {
        logWarning('İnternet bağlantısı yok, kayıt yapılamıyor');
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage:
              'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.',
        ));
        _hasPendingSignUp = true;
        return;
      }

      _startLoading();
      logInfo('Kayıt olunuyor: $email');

      // Timeout ekle - 30 saniye sonra işlem tamamlanmazsa hata dön
      Timer? timeoutTimer;
      timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.isLoading) {
          handleError(
              'Kayıt timeout',
              Exception(
                  'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.'));
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            isLoading: false,
            errorMessage:
                'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
          ));
        }
      });

      // En fazla 3 kez yeniden deneme stratejisi ile kayıt ol
      int retryCount = 0;
      UserModel? userModel;
      Exception? lastException;

      while (retryCount < 3 && userModel == null) {
        try {
          logInfo('Kayıt denemesi ${retryCount + 1}/3');

          userModel = await _userRepository.signUpWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
          );

          // Başarılı kayıt
          if (userModel != null) {
            timeoutTimer.cancel(); // Timeout'u iptal et
            logInfo('Kullanıcı başarıyla kayıt oldu: $email');
            logSuccess('Kayıt', 'Kayıt olma başarılı: $email');

            // State'i güncelle
            emit(state.copyWith(
              status: AuthStatus.authenticated,
              user: userModel,
              isLoading: false,
              errorMessage: null,
              pendingOperationMessage: null,
            ));

            // Bekleyen kayıt işaretini temizle
            _hasPendingSignUp = false;

            return; // Başarılı ise fonksiyondan çık
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          handleError('Kayıt denemesi başarısız', e);

          if (_isNetworkError(e) && retryCount < 2) {
            // Servis geçici olarak kullanılamıyor, yeniden dene
            logInfo(
                'Firebase servisine bağlantı hatası, yeniden deneme ${retryCount + 1}/3');
            retryCount++;

            // Exponential backoff: her denemede artan bekleme süresi
            final backoffDelay = (retryCount * 2) * 1000; // ms cinsinden
            logInfo('$backoffDelay ms bekliyor...');
            await Future.delayed(Duration(milliseconds: backoffDelay));
            continue;
          } else {
            // Maksimum deneme sayısına ulaşıldı veya başka bir hata
            timeoutTimer.cancel(); // Timeout'u iptal et
            handleError('Kayıt başarısız', e);

            // Ağ hatası ise bekleyen kayıt işaretle
            if (_isNetworkError(e)) {
              _hasPendingSignUp = true;
            }

            // Hata mesajını UI'da göster
            String errorMessage;
            if (_isNetworkError(e)) {
              errorMessage =
                  'Bağlantı sorunu nedeniyle kayıt yapılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
            } else if (lastException != null &&
                lastException.toString().contains('email-already-in-use')) {
              errorMessage =
                  'Bu e-posta adresi zaten kullanılıyor. Lütfen başka bir e-posta adresi deneyin.';
            } else if (lastException != null &&
                lastException.toString().contains('weak-password')) {
              errorMessage =
                  'Şifreniz çok zayıf. Lütfen en az 6 karakter içeren daha güçlü bir şifre belirleyin.';
            } else if (lastException != null &&
                lastException.toString().contains('invalid-email')) {
              errorMessage =
                  'Geçersiz e-posta adresi formatı. Lütfen geçerli bir e-posta adresi giriniz.';
            } else if (lastException != null &&
                lastException
                    .toString()
                    .contains('createUserWithEmailAndPassword')) {
              errorMessage =
                  'Hesap oluşturulurken bir sorun oluştu. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
            } else {
              // Daha kullanıcı dostu genel hata mesajı
              errorMessage =
                  'Kayıt yapılamadı, lütfen daha sonra tekrar deneyin.';

              // Debug için detaylı hatayı loglara yaz
              if (lastException != null) {
                logError('Ham hata mesajı', lastException.toString());
              }
            }

            emit(state.copyWith(
              status: AuthStatus.unauthenticated,
              isLoading: false,
              errorMessage: errorMessage,
              showRetryButton:
                  lastException != null && _isNetworkError(lastException),
            ));
            return;
          }
        }
      }

      // Tüm yeniden denemeler başarısız oldu
      if (userModel == null) {
        timeoutTimer.cancel(); // Timeout'u iptal et
        handleError('Kayıt başarısız',
            lastException ?? Exception('Tüm denemeler başarısız oldu'));

        // Ağ hatası ise bekleyen kayıt işaretle
        if (lastException != null && _isNetworkError(lastException)) {
          _hasPendingSignUp = true;
        }

        String errorMessage;
        if (lastException != null && _isNetworkError(lastException)) {
          errorMessage =
              'Bağlantı sorunu nedeniyle kayıt yapılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
        } else if (lastException != null &&
            lastException.toString().contains('email-already-in-use')) {
          errorMessage =
              'Bu e-posta adresi zaten kullanılıyor. Lütfen başka bir e-posta adresi deneyin.';
        } else if (lastException != null &&
            lastException.toString().contains('weak-password')) {
          errorMessage =
              'Şifreniz çok zayıf. Lütfen en az 6 karakter içeren daha güçlü bir şifre belirleyin.';
        } else if (lastException != null &&
            lastException.toString().contains('invalid-email')) {
          errorMessage =
              'Geçersiz e-posta adresi formatı. Lütfen geçerli bir e-posta adresi giriniz.';
        } else if (lastException != null &&
            lastException
                .toString()
                .contains('createUserWithEmailAndPassword')) {
          errorMessage =
              'Hesap oluşturulurken bir sorun oluştu. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
        } else {
          // Daha kullanıcı dostu genel hata mesajı
          errorMessage = 'Kayıt yapılamadı, lütfen daha sonra tekrar deneyin.';

          // Debug için detaylı hatayı loglara yaz
          if (lastException != null) {
            logError('Ham hata mesajı', lastException.toString());
          }
        }

        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: errorMessage,
          showRetryButton:
              lastException != null && _isNetworkError(lastException),
        ));
      }
    } catch (e) {
      _handleError('Kayıt olma', e);
    }
  }

  // Alias metodu - eski isimle uyumluluk için
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return signUpWithEmailAndPassword(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  /// Kullanıcının oturumunu kapatır
  Future<void> signOut() async {
    try {
      _startLoading();
      logInfo('Oturum kapatılıyor');

      await _userRepository.signOut();
      // User stream, state'i otomatik güncelleyecek

      logSuccess('Oturum kapatma', 'Oturum kapatma başarılı');
    } catch (e) {
      _handleError('Oturum kapatma', e);
    }
  }

  /// Parola sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // İnternet bağlantısı kontrolü
      if (!_hasNetworkConnection) {
        logWarning(
            'İnternet bağlantısı yok, şifre sıfırlama işlemi yapılamıyor');
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.',
        ));
        return;
      }

      _startLoading();
      logInfo('Parola sıfırlama e-postası gönderiliyor: $email');

      await _authService.sendPasswordResetEmail(email);

      logSuccess('Parola sıfırlama', 'Parola sıfırlama e-postası gönderildi');
      emit(state.copyWith(
        isLoading: false,
        successMessage:
            'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen e-postanızı kontrol edin.',
      ));
    } catch (e) {
      _handleError('Parola sıfırlama e-postası gönderme', e);
    }
  }

  /// E-posta doğrulama kontrolünü başlatır
  void startEmailVerificationCheck() {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        try {
          final user = _authService.currentUser;
          if (user != null && user.emailVerified) {
            timer.cancel();
            logSuccess('E-posta doğrulama', 'E-posta doğrulandı');
          }
        } catch (e) {
          handleError('E-posta doğrulama kontrolü', e);
        }
      },
    );
  }

  /// E-posta doğrulama kontrolünü durdurur
  void stopEmailVerificationCheck() {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = null;
  }

  /// E-posta doğrulama durumu için doğrudan güncelleme
  Future<void> refreshEmailVerificationStatus() async {
    try {
      _startLoading();
      final updatedUser =
          await _userRepository.refreshEmailVerificationStatus();

      if (updatedUser != null) {
        emit(state.copyWith(user: updatedUser, isLoading: false));
        logSuccess('E-posta doğrulama durumu güncellendi');
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      _handleError('E-posta doğrulama durumu güncelleme', e);
    }
  }

  /// Firebase hata kodlarını kullanıcı dostu mesaja dönüştürür
  String getErrorMessage(firebase_auth.FirebaseAuthException exception) {
    return exception.message ?? 'Bir hata oluştu: ${exception.code}';
  }

  /// Yeniden deneme fonksiyonu - UI'da Tekrar Dene butonu için
  Future<void> retryLastOperation() async {
    if (_hasPendingSignIn) {
      // UI'dan e-posta ve şifre bilgilerini almak gerekecek
      emit(state.copyWith(
        retryOperation: 'sign_in',
        pendingOperationMessage: 'Lütfen giriş bilgilerinizi yeniden girin.',
      ));
    } else if (_hasPendingSignUp) {
      // UI'dan kayıt bilgilerini almak gerekecek
      emit(state.copyWith(
        retryOperation: 'sign_up',
        pendingOperationMessage: 'Lütfen kayıt bilgilerinizi yeniden girin.',
      ));
    } else {
      // Diğer bekleyen işlemler
      _reconnectToFirebase();
      emit(state.copyWith(
        errorMessage: null,
        showRetryButton: false,
      ));
    }
  }

  /// Kullanıcı hesabını siler
  Future<void> deleteAccount() async {
    try {
      _startLoading();
      logInfo('Hesap siliniyor');

      await _userRepository.deleteAccount();
      // User stream, state'i otomatik güncelleyecek

      logSuccess('Hesap silme', 'Hesap silme başarılı');
    } catch (e) {
      _handleError('Hesap silme', e);
    }
  }

  /// Premium hesaba yükseltme
  Future<void> upgradeToPremium() async {
    try {
      _startLoading();
      logInfo('Premium yükseltme yapılıyor');

      final user = await _userRepository.upgradeToPremium();

      if (user != null) {
        emit(state.copyWith(user: user, isLoading: false, errorMessage: null));
        logSuccess('Kullanıcı premium\'a yükseltildi: ${user.id}');
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      _handleError('Premium yükseltme', e);
    }
  }

  /// Kullanıcının analiz kredilerini günceller
  /// [creditsToAdd] eklenecek kredi miktarı (negatif değer düşülebilir)
  Future<void> updateAnalysisCredits(int creditsToAdd) async {
    try {
      if (state.user == null) {
        logInfo('Kredi güncellemesi yapılamıyor: Kullanıcı oturum açmamış');
        return;
      }

      _startLoading();
      final currentCredits = state.user!.analysisCredits;
      final newCredits = currentCredits + creditsToAdd;

      // Negatif değer olamaz
      final finalCredits = newCredits < 0 ? 0 : newCredits;

      logInfo('Analiz kredisi güncelleniyor: $currentCredits -> $finalCredits');

      // Firestore'da kullanıcı dökümanını güncelle
      final updatedUser =
          await _userRepository.updateAnalysisCredits(finalCredits);

      if (updatedUser != null) {
        emit(state.copyWith(user: updatedUser, isLoading: false));
        logSuccess('Analiz kredisi güncellendi: $finalCredits');
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      _handleError('Analiz kredisi güncelleme', e);
    }
  }

  /// Kullanıcının analiz kredilerini kontrol eder
  /// Yeterli kredi yoksa false döner
  bool checkCredits() {
    if (state.user == null) {
      logInfo('Kredi kontrolü yapılamıyor: Kullanıcı oturum açmamış');
      return false;
    }

    // Premium kullanıcılar her zaman analiz yapabilir
    if (state.user!.isPremium) {
      return true;
    }

    // Normal kullanıcılar için kredi kontrolü
    final hasCredits = state.user!.analysisCredits > 0;

    if (!hasCredits) {
      logInfo('Yetersiz analiz kredisi: ${state.user!.analysisCredits}');
    }

    return hasCredits;
  }

  /// Kullanıcı profil bilgilerini günceller
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      _startLoading();
      logInfo('Profil güncelleniyor');

      final updatedUser = await _userRepository.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      if (updatedUser != null) {
        emit(state.copyWith(user: updatedUser, isLoading: false));
        logSuccess('Profil güncelleme başarılı');
      } else {
        emit(state.copyWith(isLoading: false));
        logInfo('Profil güncellenemedi: Kullanıcı bilgisi alınamadı');
      }
    } catch (e) {
      _handleError('Profil güncelleme', e);
    }
  }

  /// Hata mesajını temizler
  void clearErrorMessage() {
    if (state.errorMessage != null) {
      emit(state.copyWith(
        errorMessage: null,
        showRetryButton: false,
        pendingOperationMessage: null,
      ));
    }
  }

  /// Başarı mesajını temizler
  void clearSuccessMessage() {
    if (state.successMessage != null) {
      emit(state.copyWith(successMessage: null));
    }
  }

  /// Bekleyen işlem mesajını temizler
  void clearPendingOperationMessage() {
    if (state.pendingOperationMessage != null) {
      emit(state.copyWith(
        pendingOperationMessage: null,
        retryOperation: null,
      ));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    _emailVerificationTimer?.cancel();
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    return super.close();
  }
}
