import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/auth_state.dart';
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

  void _init() {
    try {
      logInfo('AuthCubit başlatılıyor');
      _userSubscription = _userRepository.user.listen(
        (user) {
          try {
            if (user != null) {
              logInfo('Kullanıcı oturum açtı: ${user.email}');

              emit(
                state.copyWith(
                  status: AuthStatus.authenticated,
                  user: user,
                  isLoading: false,
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
                ),
              );
              stopEmailVerificationCheck();
            }
          } catch (e, stack) {
            logError('Kullanıcı durumu işleme hatası', e, stack);
          }
        },
        onError: (error, stack) {
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
        },
      );
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

  /// E-posta ve şifre ile giriş yapar
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Giriş yapılıyor: $email');

      final userModel = await _userRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userModel != null) {
        // Eğer kullanıcının displayName'i yoksa ve Firestore'da varsa güncelle
        if ((userModel.displayName == null || userModel.displayName!.isEmpty)) {
          logInfo('Kullanıcı displayName güncellemesi yapılıyor');
          // Firebase'den güncel kullanıcıyı al
          final currentUser = await _userRepository.getCurrentUser();
          if (currentUser != null && currentUser.displayName != null) {
            await _userRepository.updateProfile(
              displayName: currentUser.displayName!,
            );
            // Güncellenmiş kullanıcı bilgilerini al
            final updatedUser = await _userRepository.getCurrentUser();
            if (updatedUser != null) {
              emit(AuthState.authenticated(updatedUser));
            } else {
              emit(AuthState.authenticated(userModel));
            }
          } else {
            emit(AuthState.authenticated(userModel));
          }
        } else {
          emit(AuthState.authenticated(userModel));
        }

        // E-posta doğrulama durumunu kontrol et
        if (userModel.isEmailVerified == false) {
          // E-posta doğrulama kontrolünü başlat
          startEmailVerificationCheck();
        }
      } else {
        emit(AuthState.unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      logError('Giriş yapma hatası', e);
      emit(AuthState.error(_authService.getMessageFromErrorCode(e.code)));
    } catch (e) {
      logError('Beklenmeyen giriş hatası', e);
      emit(AuthState.error('Giriş yaparken bir hata oluştu.'));
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
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Kayıt olunuyor: $email');

      await _userRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      emit(state.copyWith(isLoading: false));
      logSuccess('Kayıt olma başarılı: $email');
    } on FirebaseAuthException catch (e) {
      logError('Kayıt olma hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _authService.getMessageFromErrorCode(e.code),
        ),
      );
    } catch (e) {
      logError('Beklenmeyen kayıt olma hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Kayıt olurken bir hata oluştu.',
        ),
      );
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
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Oturum kapatılıyor');

      await _userRepository.signOut();

      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          isLoading: false,
        ),
      );
      logSuccess('Oturum kapatma başarılı');
    } catch (e) {
      logError('Oturum kapatma hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Oturum kapatılırken bir hata oluştu.',
        ),
      );
    }
  }

  /// Parola sıfırlama e-postası gönderir
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Parola sıfırlama e-postası gönderiliyor: $email');

      await _authService.sendPasswordResetEmail(email);

      emit(state.copyWith(isLoading: false));
      logSuccess('Parola sıfırlama e-postası gönderildi: $email');
    } on FirebaseAuthException catch (e) {
      logError('Parola sıfırlama e-postası gönderme hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _authService.getMessageFromErrorCode(e.code),
        ),
      );
    } catch (e) {
      logError('Beklenmeyen parola sıfırlama hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              'Parola sıfırlama e-postası gönderilirken bir hata oluştu.',
        ),
      );
    }
  }

  /// E-posta doğrulama e-postası gönderir
  Future<void> sendEmailVerification() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('E-posta doğrulama e-postası gönderiliyor');

      await _authService.sendEmailVerification();

      emit(state.copyWith(isLoading: false));
      logSuccess('E-posta doğrulama e-postası gönderildi');
    } catch (e) {
      logError('E-posta doğrulama e-postası gönderme hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              'E-posta doğrulama e-postası gönderilirken bir hata oluştu.',
        ),
      );
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
      emit(state.copyWith(isLoading: true));
      final updatedUser =
          await _userRepository.refreshEmailVerificationStatus();
      if (updatedUser != null) {
        emit(state.copyWith(user: updatedUser, isLoading: false));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      logError('E-posta doğrulama durumu güncelleme hatası', e);
    }
  }

  /// Firebase hata kodlarını kullanıcı dostu mesaja dönüştürür
  String getErrorMessage(FirebaseAuthException exception) {
    return _authService.getMessageFromErrorCode(exception.code);
  }

  /// Kullanıcı hesabını siler
  Future<void> deleteAccount() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Hesap siliniyor');

      await _userRepository.deleteAccount();

      emit(AuthState.unauthenticated());
      logSuccess('Hesap silme başarılı');
    } catch (e) {
      logError('Hesap silme hatası', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Hesap silinirken bir hata oluştu: ${e.toString()}',
        ),
      );
    }
  }

  /// Premium hesaba yükseltme
  Future<void> upgradeToPremium() async {
    try {
      // _userRepository'i kullanarak premium yükseltme işlemleri
      final user = await _userRepository.upgradeToPremium();

      if (user != null) {
        // Kullanıcı başarıyla premium'a yükseltildi
        emit(
          state.copyWith(
            user: user,
            status: AuthStatus.authenticated,
            errorMessage: null,
          ),
        );

        AppLogger.i('Kullanıcı premium\'a yükseltildi: ${user.id}');
      }
    } catch (e, stackTrace) {
      // Hata durumunu logla
      AppLogger.e('Premium yükseltme hatası', e, stackTrace);

      // Hata durumunu state'e ekle
      emit(
        state.copyWith(
          errorMessage: 'Premium yükseltme sırasında bir hata oluştu',
        ),
      );
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

      final currentCredits = state.user!.analysisCredits;
      final newCredits = currentCredits + creditsToAdd;

      // Negatif değer olamaz
      final finalCredits = newCredits < 0 ? 0 : newCredits;

      logInfo('Analiz kredisi güncelleniyor: $currentCredits -> $finalCredits');

      // Firestore'da kullanıcı dökümanını güncelle
      final updatedUser = await _userRepository.updateAnalysisCredits(
        finalCredits,
      );

      if (updatedUser != null) {
        // State'i güncelle
        emit(state.copyWith(user: updatedUser));
        logSuccess('Analiz kredisi güncellendi: $finalCredits');
      }
    } catch (e) {
      logError('Analiz kredisi güncelleme hatası', e);
      emit(
        state.copyWith(
          errorMessage: 'Analiz kredisi güncellenirken bir hata oluştu',
        ),
      );
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
      emit(state.copyWith(isLoading: true, errorMessage: null));
      logInfo('Profil güncelleniyor');

      final updatedUser = await _userRepository.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      if (updatedUser != null) {
        emit(state.copyWith(
          user: updatedUser,
          isLoading: false,
        ));
        logSuccess('Profil güncelleme başarılı');
      } else {
        emit(state.copyWith(isLoading: false));
        logWarning('Profil güncellenemedi: Kullanıcı bilgisi alınamadı');
      }
    } catch (e) {
      logError('Profil güncelleme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Profil güncellenirken bir hata oluştu: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    stopEmailVerificationCheck();
    _userSubscription?.cancel();
    return super.close();
  }
}
