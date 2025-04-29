import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';

/// Kimlik doğrulama ve kullanıcı yönetimi için Cubit
class AuthCubit extends BaseCubit<AuthState> {
  final UserRepository _userRepository;
  final AuthService _authService;
  StreamSubscription<UserModel?>? _userSubscription;
  Timer? _emailVerificationTimer;

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

  /// Cubit başlangıç fonksiyonu - user subscription'ı başlatır
  void _init() {
    try {
      logInfo('AuthCubit başlatılıyor');
      _subscribeToUserChanges();
    } catch (e, stack) {
      handleError('AuthCubit başlatma', e, stack);
      emitErrorState('Kimlik doğrulama servisi başlatılamadı');
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
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage: error.toString(),
      ),
    );
    stopEmailVerificationCheck();
  }

  /// Asenkron işlem başlatma
  void _startLoading() {
    emitLoadingState();
  }

  /// Asenkron işlem hata ile bittiğinde
  void _handleError(String operation, Object error) {
    String errorMessage;

    if (error is firebase_auth.FirebaseAuthException) {
      // Hata mesajını direkt olarak kullanmak daha güvenilir
      errorMessage = error.message ?? 'Bir hata oluştu: ${error.code}';
      handleError(operation, error);
    } else {
      errorMessage =
          '$operation sırasında bir hata oluştu: ${error.toString()}';
      handleError('Beklenmeyen $operation', error);
    }

    emit(
      state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      ),
    );
  }

  /// E-posta ve şifre ile giriş yapar
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _startLoading();
      logInfo('Giriş yapılıyor: $email');

      // En fazla 3 kez yeniden deneme stratejisi ile giriş yap
      int retryCount = 0;
      UserModel? userModel;

      while (retryCount < 3 && userModel == null) {
        try {
          userModel = await _userRepository.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Başarılı giriş
          if (userModel != null) {
            logInfo('Giriş başarılı: ${userModel.email}');

            // E-posta doğrulama durumunu kontrol et
            if (!userModel.isEmailVerified) {
              startEmailVerificationCheck();
            }

            return; // Başarılı ise fonksiyondan çık
          }
        } catch (e) {
          if (e.toString().contains('unavailable') && retryCount < 2) {
            // Servis geçici olarak kullanılamıyor, yeniden dene
            logInfo(
                'Firebase servisine bağlantı hatası, yeniden deneme ${retryCount + 1}/3');
            retryCount++;

            // Exponential backoff: her denemede artan bekleme süresi
            final backoffDelay = (retryCount * 2) * 1000; // ms cinsinden
            await Future.delayed(Duration(milliseconds: backoffDelay));
            continue;
          } else {
            // Maksimum deneme sayısına ulaşıldı veya başka bir hata
            rethrow;
          }
        }
      }

      // Tüm yeniden denemeler başarısız oldu
      if (userModel == null) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: 'Giriş yapılamadı, lütfen bilgilerinizi kontrol edin.',
        ));
      }
    } catch (e) {
      _handleError('Giriş yapma', e);
    }
  }

  // Alias metodu - eski isimle uyumluluk için
  Future<void> signIn({required String email, required String password}) async {
    return signInWithEmailAndPassword(email: email, password: password);
  }

  /// E-posta ve şifre ile kayıt oluşturur
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _startLoading();
      logInfo('Kayıt olunuyor: $email');

      // En fazla 3 kez yeniden deneme stratejisi ile kayıt ol
      int retryCount = 0;
      UserModel? userModel;

      while (retryCount < 3 && userModel == null) {
        try {
          userModel = await _userRepository.signUpWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
          );

          // Başarılı kayıt
          if (userModel != null) {
            logInfo('Kullanıcı başarıyla kayıt oldu: $email');
            logSuccess('Kayıt', 'Kayıt olma başarılı: $email');
            return; // Başarılı ise fonksiyondan çık
          }
        } catch (e) {
          if (e.toString().contains('unavailable') && retryCount < 2) {
            // Servis geçici olarak kullanılamıyor, yeniden dene
            logInfo(
                'Firebase servisine bağlantı hatası, yeniden deneme ${retryCount + 1}/3');
            retryCount++;

            // Exponential backoff: her denemede artan bekleme süresi
            final backoffDelay = (retryCount * 2) * 1000; // ms cinsinden
            await Future.delayed(Duration(milliseconds: backoffDelay));
            continue;
          } else {
            // Maksimum deneme sayısına ulaşıldı veya başka bir hata
            rethrow;
          }
        }
      }

      // Tüm yeniden denemeler başarısız oldu
      if (userModel == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'Kayıt sırasında bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
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
      _startLoading();
      logInfo('Parola sıfırlama e-postası gönderiliyor: $email');

      await _authService.sendPasswordResetEmail(email);

      logSuccess('Parola sıfırlama', 'Parola sıfırlama e-postası gönderildi');
      emit(state.copyWith(isLoading: false));
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
      emit(state.copyWith(errorMessage: null));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    _emailVerificationTimer?.cancel();
    return super.close();
  }
}
