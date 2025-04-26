import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/features/auth/repositories/user_repository.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';

/// Kimlik doğrulama ve kullanıcı yönetimi için Cubit
class AuthCubit extends Cubit<AuthState> {
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

  // Log metotları
  void logInfo(String message) {
    AppLogger.i('AuthCubit: $message');
  }

  void logError(String message, Object error, [StackTrace? stackTrace]) {
    AppLogger.e('AuthCubit: $message', error, stackTrace);
  }

  void logSuccess(String message) {
    AppLogger.i('AuthCubit: $message');
  }

  void logWarning(String message) {
    AppLogger.w('AuthCubit: $message');
  }

  /// Cubit başlangıç fonksiyonu - user subscription'ı başlatır
  void _init() {
    try {
      logInfo('AuthCubit başlatılıyor');
      _subscribeToUserChanges();
    } catch (e, stack) {
      logError('AuthCubit başlatma hatası', e, stack);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Kimlik doğrulama servisi başlatılamadı',
        ),
      );
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
      logError('Kullanıcı durumu işleme hatası', e, stack);
    }
  }

  /// Kullanıcı stream'inde hata olduğunda çağrılır
  void _onUserError(Object error, StackTrace stack) {
    logError('Kullanıcı dinleme hatası', error, stack);
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
    emit(state.copyWith(isLoading: true, errorMessage: null));
  }

  /// Asenkron işlem hata ile bittiğinde
  void _handleError(String operation, Object error) {
    String errorMessage;

    if (error is FirebaseAuthException) {
      // Hata mesajını direkt olarak kullanmak daha güvenilir
      errorMessage = error.message ?? 'Bir hata oluştu: ${error.code}';
      logError('$operation hatası: ${error.code}', error);
    } else {
      errorMessage =
          '$operation sırasında bir hata oluştu: ${error.toString()}';
      logError('Beklenmeyen $operation hatası', error);
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

      final userModel = await _userRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userModel != null) {
        // Kullanıcı bilgileri, user stream tarafından otomatik güncellenecek
        logSuccess('Giriş başarılı: ${userModel.email}');

        // E-posta doğrulama durumunu kontrol et
        if (!userModel.isEmailVerified) {
          startEmailVerificationCheck();
        }
      } else {
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

      final userModel = await _userRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (userModel != null) {
        logSuccess('Kayıt olma başarılı: $email');
        // Kullanıcı bilgileri, user stream tarafından otomatik güncellenecek
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Kayıt sırasında bir sorun oluştu',
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

      logSuccess('Oturum kapatma başarılı');
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

      emit(state.copyWith(isLoading: false));
      logSuccess('Parola sıfırlama e-postası gönderildi: $email');
    } catch (e) {
      _handleError('Parola sıfırlama', e);
    }
  }

  /// E-posta doğrulama e-postası gönderir
  Future<void> sendEmailVerification() async {
    try {
      _startLoading();
      logInfo('E-posta doğrulama e-postası gönderiliyor');

      await _authService.sendEmailVerification();

      emit(state.copyWith(isLoading: false));
      logSuccess('E-posta doğrulama e-postası gönderildi');
    } catch (e) {
      _handleError('E-posta doğrulama e-postası gönderme', e);
    }
  }

  /// E-posta doğrulama kontrolünü başlatır
  void startEmailVerificationCheck() {
    logInfo('E-posta doğrulama kontrolü başlatılıyor');
    stopEmailVerificationCheck(); // Önceki zamanlayıcıyı temizle

    // 5 saniyede bir kontrol et
    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkEmailVerificationStatus(),
    );
  }

  /// E-posta doğrulama kontrolünü durdurur
  void stopEmailVerificationCheck() {
    if (_emailVerificationTimer != null) {
      logInfo('E-posta doğrulama kontrolü durduruluyor');
      _emailVerificationTimer?.cancel();
      _emailVerificationTimer = null;
    }
  }

  /// E-posta doğrulama durumunu kontrol eder ve günceller
  Future<void> checkEmailVerificationStatus() async {
    try {
      if (state.user != null && !state.user!.isEmailVerified) {
        logInfo('E-posta doğrulama durumu kontrol ediliyor');
        emit(state.copyWith(isLoading: true));

        final updatedUser =
            await _userRepository.refreshEmailVerificationStatus();

        if (updatedUser != null) {
          emit(state.copyWith(user: updatedUser, isLoading: false));

          if (updatedUser.isEmailVerified) {
            logSuccess('E-posta doğrulama durumu güncellendi');
            stopEmailVerificationCheck(); // Doğrulandıysa kontrol etmeyi durdur
          }
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      logError('E-posta doğrulama durumu güncelleme hatası', e);
    }
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
  String getErrorMessage(FirebaseAuthException exception) {
    return exception.message ?? 'Bir hata oluştu: ${exception.code}';
  }

  /// Kullanıcı hesabını siler
  Future<void> deleteAccount() async {
    try {
      _startLoading();
      logInfo('Hesap siliniyor');

      await _userRepository.deleteAccount();
      // User stream, state'i otomatik güncelleyecek

      logSuccess('Hesap silme başarılı');
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
        logWarning('Kredi güncellemesi yapılamıyor: Kullanıcı oturum açmamış');
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
      logWarning('Kredi kontrolü yapılamıyor: Kullanıcı oturum açmamış');
      return false;
    }

    // Premium kullanıcılar her zaman analiz yapabilir
    if (state.user!.isPremium) {
      return true;
    }

    // Normal kullanıcılar için kredi kontrolü
    final hasCredits = state.user!.analysisCredits > 0;

    if (!hasCredits) {
      logWarning('Yetersiz analiz kredisi: ${state.user!.analysisCredits}');
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
        logWarning('Profil güncellenemedi: Kullanıcı bilgisi alınamadı');
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
    stopEmailVerificationCheck();
    _userSubscription?.cancel();
    return super.close();
  }
}
