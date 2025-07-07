import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/base/base_cubit.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/models/user_model.dart';
import 'auth_state.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/utils/cache_manager.dart';

/// Authentication işlemlerini yöneten Cubit
///
/// BaseCubit'den türetilmiş auth state management sınıfıdır.
/// Firebase Authentication ve Firestore entegrasyonunu yönetir.
/// ServiceLocator ile dependency injection kullanır.
///
/// Özellikler:
/// - ServiceLocator tabanlı dependency injection
/// - Anonim authentication
/// - Kullanıcı session takibi
/// - Onboarding logic
/// - Hata yönetimi ve loglama
/// - Stream-based auth state changes
/// - Döngüsel hata önleme mekanizması
class AuthCubit extends BaseCubit<AuthState> {
  /// Auth repository instance (ServiceLocator'dan alınır)
  late final AuthRepository _authRepository;

  /// Firebase Auth stream subscription
  StreamSubscription<User?>? _authSubscription;

  /// Anonim giriş deneme sayacı (döngüsel hata önleme için)
  int _anonymousSignInAttempts = 0;
  static const int _maxAnonymousSignInAttempts = 3;

  /// Constructor - ServiceLocator kullanarak dependency injection
  AuthCubit() : super(const AuthInitial()) {
    try {
      // ServiceLocator'ın hazır olup olmadığını kontrol et
      if (!ServiceLocator.isRegistered<AuthRepository>()) {
        logWarning('ServiceLocator henüz hazır değil, fallback kullanılıyor');
        _createFallbackRepository();
        return;
      }

      // ServiceLocator'dan repository'yi al
      _authRepository = ServiceLocator.get<AuthRepository>();

      // Firebase Auth state changes'ı dinlemeye başla
      _initializeAuthListener();
    } catch (e, stackTrace) {
      handleError('AuthCubit constructor hatası', e, stackTrace);

      // Fallback: Manuel repository oluştur
      _createFallbackRepository();
    }
  }

  /// ServiceLocator başarısız olursa fallback repository oluşturur
  void _createFallbackRepository() {
    try {
      logWarning('ServiceLocator başarısız, fallback repository oluşturuluyor');

      // Repository'yi manuel olarak oluştur (Firebase direkt kullanarak)
      _authRepository = AuthRepository();

      // Firebase Auth state changes'ı dinlemeye başla
      _initializeAuthListener();

      logInfo('Fallback AuthRepository başarıyla oluşturuldu');
    } catch (e, stackTrace) {
      handleError('Fallback repository oluşturma hatası', e, stackTrace);
      emit(const AuthError(
        message: 'Authentication servisi başlatılamadı',
        isCritical: true,
      ));
    }
  }

  /// Firebase Auth state changes'ı dinlemeye başlar
  void _initializeAuthListener() {
    logInfo('Auth listener başlatılıyor');

    _authSubscription = _authRepository.userStream.listen(
      _onAuthStateChanged,
      onError: (error, stackTrace) {
        handleError('Auth listener hatası', error, stackTrace);
      },
    );
  }

  /// Firebase Auth state değişikliklerini işler
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    try {
      logInfo('Auth state değişikliği algılandı', firebaseUser?.uid);

      if (firebaseUser == null) {
        // Kullanıcı çıkış yapmış
        logInfo('Kullanıcı çıkış yapmış');
        emit(const AuthUnauthenticated());
        return;
      }

      // Mevcut state'i kontrol et - zaten loading ise tekrar loading'e geçme
      if (state is AuthLoading) {
        logInfo('Zaten loading state\'te, işlem atlanıyor');
        return;
      }

      // Loading state'e geç
      emit(const AuthLoading(message: 'Kullanıcı bilgileri yükleniyor...'));

      try {
        // Firestore'dan kullanıcı verilerini al
        logInfo('Firestore\'dan kullanıcı verisi alınıyor', firebaseUser.uid);
        final UserModel? userData = await _authRepository.getCurrentUserData();

        if (userData == null) {
          // Firestore'da kullanıcı verisi yok, yeni kullanıcı olarak işle
          logInfo(
              'Firestore\'da kullanıcı verisi bulunamadı, yeni kullanıcı oluşturuluyor');

          // Ancak döngüsel hatayı önlemek için attempt sayısını kontrol et
          if (_anonymousSignInAttempts < _maxAnonymousSignInAttempts) {
            logInfo(
                'Yeni kullanıcı algılandı, direkt user oluşturuluyor (Deneme: ${_anonymousSignInAttempts + 1})');
            // SignInAnonymously çağırmak yerine direkt user oluştur
            await _createAnonymousUserDirectly(firebaseUser.uid);
          } else {
            logWarning(
                'Maksimum anonim giriş denemesi aşıldı, fallback user oluşturuluyor');
            await _createFallbackUser(firebaseUser.uid);
          }
          return;
        }

        // Başarılı durumda attempt sayısını sıfırla
        _anonymousSignInAttempts = 0;

        // İlk kez giriş yapan kullanıcı mı kontrol et
        final bool isFirstTime =
            await _authRepository.isFirstTimeUser(userData.id);

        logSuccess('Kullanıcı verisi başarıyla yüklendi', userData.id);

        emit(AuthAuthenticated(
          user: userData,
          isFirstTime: isFirstTime,
        ));
      } on FirebaseException catch (firestoreError, stackTrace) {
        // Firestore-specific hatalar
        logWarning(
            'Firestore hatası (${firestoreError.code}): ${firestoreError.message}');

        // Retry yapılabilir hatalar için fallback user oluştur
        if (_isRetryableFirestoreError(firestoreError.code)) {
          logInfo('Geçici Firestore hatası, fallback user oluşturuluyor');
          await _createFallbackUser(firebaseUser.uid);
        } else {
          // Kalıcı hatalar için error state
          handleError('Kalıcı Firestore hatası', firestoreError, stackTrace);
          emit(AuthError(
            message:
                'Kullanıcı verilerine erişilemiyor: ${_getFirestoreErrorMessage(firestoreError.code, null)}',
            errorCode: firestoreError.code,
            isCritical: false,
          ));
        }
      } catch (firestoreError, stackTrace) {
        // Diğer hatalar
        logWarning(
            'Beklenmeyen Firestore hatası, fallback user oluşturuluyor: $firestoreError');
        handleError('Beklenmeyen Firestore hatası', firestoreError, stackTrace);
        await _createFallbackUser(firebaseUser.uid);
      }
    } catch (error, stackTrace) {
      handleError('Auth state değişikliği işleme hatası', error, stackTrace);
    }
  }

  /// Döngüyü önlemek için direkt anonymous user oluşturur
  Future<void> _createAnonymousUserDirectly(String userId) async {
    try {
      logInfo('Direkt anonymous user oluşturuluyor', userId);

      final user = UserModel.anonymous(
        id: userId,
        name: 'Misafir Kullanıcı ${userId.substring(0, 8)}',
      );

      // Kullanıcıyı Firestore'a kaydetmeyi dene
      try {
        logInfo('Kullanıcı Firestore\'a kaydediliyor', userId);
        await _authRepository.updateUser(user);
        logSuccess('Kullanıcı başarıyla Firestore\'a kaydedildi', userId);
      } catch (firestoreError) {
        logWarning('Firestore kaydetme hatası, memory user kullanılıyor',
            '$userId: $firestoreError');
        // Hata olsa bile devam et
      }

      // Başarılı durumda attempt sayısını sıfırla
      _anonymousSignInAttempts = 0;

      emit(AuthAuthenticated(
        user: user,
        isFirstTime: true,
      ));

      logSuccess('Anonymous user direkt oluşturuldu', userId);
    } catch (e, stackTrace) {
      handleError('Direkt user oluşturma hatası', e, stackTrace);
      await _createFallbackUser(userId);
    }
  }

  /// Fallback user oluşturur (son çare)
  Future<void> _createFallbackUser(String userId) async {
    try {
      logWarning('Fallback user oluşturuluyor', userId);

      final user = UserModel.anonymous(
        id: userId,
        name: 'Misafir ${userId.substring(0, 6)}',
      );

      emit(AuthAuthenticated(
        user: user,
        isFirstTime: true,
      ));

      logInfo('Fallback user oluşturuldu', userId);
    } catch (e, stackTrace) {
      handleError('Fallback user oluşturma hatası', e, stackTrace);
      emit(const AuthError(
        message: 'Kullanıcı oluşturulamadı',
        isCritical: true,
      ));
    }
  }

  /// Firebase'in hazır olup olmadığını kontrol eder
  bool _isFirebaseReady() {
    try {
      // Firebase Core başlatılmış mı kontrol et
      if (Firebase.apps.isEmpty) {
        logWarning('Firebase henüz başlatılmamış');
        return false;
      }

      // Firebase Auth mevcut mu kontrol et
      try {
        // _authRepository'nin userStream'ine erişim test et
        _authRepository.userStream;
      } catch (e) {
        logWarning('AuthRepository henüz hazır değil: $e');
        return false;
      }

      return true;
    } catch (e) {
      logWarning('Firebase hazırlık kontrolü hatası: $e');
      return false;
    }
  }

  /// Anonim giriş yapar
  ///
  /// Kullanıcıyı anonim olarak giriş yapar ve ilk kez ise
  /// onboarding'e yönlendirilmek üzere isFirstTime=true ile işaretler.
  Future<void> signInAnonymously() async {
    try {
      // Firebase hazırlık kontrolü
      if (!_isFirebaseReady()) {
        logWarning('Firebase henüz hazır değil, anonim giriş erteleniyor');
        emit(const AuthError(
          message: 'Sistem henüz hazır değil, lütfen bekleyin',
          isCritical: false,
        ));
        return;
      }

      // Attempt sayısını artır
      _anonymousSignInAttempts++;

      logInfo(
          'Anonim giriş işlemi başlatılıyor (Deneme: $_anonymousSignInAttempts)');
      emit(const AuthLoading(message: 'Giriş yapılıyor...'));

      // Anonim giriş yap
      final UserModel user = await _authRepository.signInAnonymously();

      // İlk kez giriş yapan kullanıcı mı kontrol et
      final bool isFirstTime = await _authRepository.isFirstTimeUser(user.id);

      // Başarılı durumda attempt sayısını sıfırla
      _anonymousSignInAttempts = 0;

      logSuccess('Anonim giriş başarılı', user.id);

      emit(AuthAuthenticated(
        user: user,
        isFirstTime: isFirstTime,
      ));
    } on FirebaseAuthException catch (error, stackTrace) {
      handleError('Anonim giriş Firebase hatası', error, stackTrace);
      emit(AuthError(
        message: _getFirebaseErrorMessage(error, null),
        errorCode: error.code,
        isCritical: true,
      ));
    } catch (error, stackTrace) {
      handleError('Anonim giriş genel hatası', error, stackTrace);

      // Maksimum deneme sayısına ulaşıldıysa kritik hata
      final isCritical =
          _anonymousSignInAttempts >= _maxAnonymousSignInAttempts;

      emit(AuthError(
        message: isCritical
            ? 'Giriş yapılırken tekrarlanan hata oluştu. Lütfen uygulamayı yeniden başlatın.'
            : 'Giriş yapılırken bir sorun oluştu',
        isCritical: isCritical,
      ));
    }
  }

  /// Çıkış yapar
  Future<void> signOut() async {
    try {
      logInfo('Çıkış işlemi başlatılıyor');
      emit(const AuthLoading(message: 'Çıkış yapılıyor...'));

      await _authRepository.signOut();

      logSuccess('Çıkış işlemi başarılı');

      emit(const AuthUnauthenticated(
        reason: 'Kullanıcı çıkış yaptı',
        hasLoggedInBefore: true,
      ));
    } catch (error, stackTrace) {
      handleError('Çıkış işlemi hatası', error, stackTrace);
      emit(const AuthError(
        message: 'Çıkış yapılırken bir sorun oluştu',
        isCritical: false,
      ));
    }
  }

  /// Kullanıcı verilerini günceller
  Future<void> updateUser(UserModel updatedUser) async {
    try {
      logInfo('Kullanıcı verisi güncelleniyor', updatedUser.id);

      final currentState = state;
      if (currentState is! AuthAuthenticated) {
        logWarning('Kullanıcı güncellemesi için authenticated state gerekli');
        return;
      }

      emit(const AuthLoading(message: 'Profil güncelleniyor...'));

      final UserModel updated = await _authRepository.updateUser(updatedUser);

      logSuccess('Kullanıcı verisi güncellendi', updated.id);

      emit(currentState.copyWith(user: updated));
    } catch (error, stackTrace) {
      handleError('Kullanıcı verisi güncelleme hatası', error, stackTrace);
      emit(AuthError(
        message: 'Profil güncellenirken bir sorun oluştu',
        isCritical: false,
        previousState: state,
      ));
    }
  }

  /// Kullanıcının analiz kredisini günceller
  Future<void> updateAnalysisCredits(int newCredits) async {
    try {
      final currentState = state;
      if (currentState is! AuthAuthenticated) {
        logWarning('Kredi güncellemesi için authenticated state gerekli');
        return;
      }

      logInfo('Analiz kredisi güncelleniyor',
          '${currentState.user.id}: $newCredits');

      final UserModel updated = await _authRepository.updateAnalysisCredits(
        currentState.user.id,
        newCredits,
      );

      logSuccess('Analiz kredisi güncellendi', '${updated.id}: $newCredits');

      emit(currentState.copyWith(user: updated));
    } catch (error, stackTrace) {
      handleError('Analiz kredisi güncelleme hatası', error, stackTrace);
      emit(AuthError(
        message: 'Kredi güncellenirken bir sorun oluştu',
        isCritical: false,
        previousState: state,
      ));
    }
  }

  /// Onboarding tamamlandığını işaretler
  void completeOnboarding() {
    final currentState = state;
    if (currentState is! AuthAuthenticated) {
      logWarning('Onboarding tamamlama için authenticated state gerekli');
      return;
    }

    logInfo('Onboarding tamamlandı', currentState.user.id);

    emit(currentState.copyWith(isFirstTime: false));
  }

  /// Kullanıcı verilerini Firestore'dan yeniden yükler
  Future<void> refresh() async {
    try {
      final currentState = state;
      if (currentState is! AuthAuthenticated) {
        logWarning('Refresh için authenticated state gerekli');
        return;
      }

      logInfo('Kullanıcı verileri refresh ediliyor', currentState.user.id);

      // Firestore'dan güncel kullanıcı verilerini al
      final updatedUser = await _authRepository.getCurrentUserData();
      
      if (updatedUser != null) {
        logSuccess('Kullanıcı verileri başarıyla refresh edildi', updatedUser.id);
        logInfo('Güncel analiz kredileri: ${updatedUser.analysisCredits}');
        
        emit(currentState.copyWith(user: updatedUser));
      } else {
        logWarning('Refresh sırasında kullanıcı verisi bulunamadı');
      }
    } catch (error, stackTrace) {
      handleError('Kullanıcı verileri refresh hatası', error, stackTrace);
      // Hata durumunda mevcut state'i korumaya devam et, critical error verme
      logWarning('Refresh hatası, mevcut state korunuyor');
    }
  }

  /// Hesabı tamamen siler
  Future<void> deleteAccount() async {
    try {
      final currentState = state;
      if (currentState is! AuthAuthenticated) {
        logWarning('Hesap silme için authenticated state gerekli');
        return;
      }

      logInfo('Hesap silme işlemi başlatılıyor', currentState.user.id);
      emit(const AuthLoading(message: 'Hesap siliniyor...'));

      await _authRepository.deleteAccount();

      logSuccess('Hesap başarıyla silindi', currentState.user.id);

      emit(const AuthUnauthenticated(
        reason: 'Hesap silindi',
        hasLoggedInBefore: false,
      ));
    } catch (error, stackTrace) {
      handleError('Hesap silme hatası', error, stackTrace);
      emit(AuthError(
        message: 'Hesap silinirken bir sorun oluştu',
        isCritical: true,
        previousState: state,
      ));
    }
  }

  /// Firestore hata kodunun retry yapılabilir olup olmadığını kontrol eder
  bool _isRetryableFirestoreError(String errorCode) {
    switch (errorCode) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'aborted':
      case 'internal':
        return true;
      case 'permission-denied':
      case 'not-found':
      case 'already-exists':
      case 'invalid-argument':
      case 'unauthenticated':
        return false;
      default:
        // Bilinmeyen hatalar için retry yapma
        return false;
    }
  }

  /// Firestore hata mesajlarını Türkçe'ye çevirir
  String _getFirestoreErrorMessage(String errorCode, BuildContext? context) {
    if (context == null) {
      // Fallback to default messages if context is not available
      switch (errorCode) {
        case 'unavailable':
          return 'Veritabanı servisi geçici olarak kullanılamıyor';
        case 'deadline-exceeded':
          return 'İşlem zaman aşımına uğradı';
        case 'resource-exhausted':
          return 'Sistem kaynaklarına erişim sınırı aşıldı';
        case 'permission-denied':
          return 'Bu işlem için yetkiniz bulunmuyor';
        case 'not-found':
          return 'İstenen veri bulunamadı';
        case 'already-exists':
          return 'Bu veri zaten mevcut';
        case 'invalid-argument':
          return 'Geçersiz veri gönderildi';
        case 'unauthenticated':
          return 'Kimlik doğrulaması gerekli';
        case 'aborted':
          return 'İşlem iptal edildi';
        case 'internal':
          return 'Sistem iç hatası';
        default:
          return 'Veritabanı hatası oluştu';
      }
    }

    switch (errorCode) {
      case 'unavailable':
        return 'firestore_unavailable'.locale(context);
      case 'deadline-exceeded':
        return 'firestore_deadline_exceeded'.locale(context);
      case 'resource-exhausted':
        return 'firestore_resource_exhausted'.locale(context);
      case 'permission-denied':
        return 'firestore_permission_denied'.locale(context);
      case 'not-found':
        return 'firestore_not_found'.locale(context);
      case 'already-exists':
        return 'firestore_already_exists'.locale(context);
      case 'invalid-argument':
        return 'firestore_invalid_argument'.locale(context);
      case 'unauthenticated':
        return 'firestore_unauthenticated'.locale(context);
      case 'aborted':
        return 'firestore_aborted'.locale(context);
      case 'internal':
        return 'firestore_internal'.locale(context);
      default:
        return 'firestore_default'.locale(context);
    }
  }

  /// Firebase Auth hata kodlarını Türkçe mesajlara çevirir
  String _getFirebaseErrorMessage(
      FirebaseAuthException error, BuildContext? context) {
    if (context == null) {
      // Fallback to default messages if context is not available
      switch (error.code) {
        case 'user-not-found':
          return 'Bu email adresine kayıtlı kullanıcı bulunamadı';
        case 'wrong-password':
          return 'Hatalı şifre girdiniz';
        case 'email-already-in-use':
          return 'Bu email adresi zaten kullanımda';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter olmalı';
        case 'invalid-email':
          return 'Geçersiz email adresi';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
        case 'network-request-failed':
          return 'İnternet bağlantısı hatası';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış';
        case 'operation-not-allowed':
          return 'Bu işlem şu anda izinli değil';
        case 'invalid-credential':
          return 'Geçersiz kimlik bilgileri';
        default:
          return error.message ?? 'Bilinmeyen bir hata oluştu';
      }
    }

    switch (error.code) {
      case 'user-not-found':
        return 'auth_user_not_found'.locale(context);
      case 'wrong-password':
        return 'auth_wrong_password'.locale(context);
      case 'email-already-in-use':
        return 'auth_email_already_in_use'.locale(context);
      case 'weak-password':
        return 'auth_weak_password'.locale(context);
      case 'invalid-email':
        return 'auth_invalid_email'.locale(context);
      case 'too-many-requests':
        return 'auth_too_many_requests'.locale(context);
      case 'network-request-failed':
        return 'auth_network_request_failed'.locale(context);
      case 'user-disabled':
        return 'auth_user_disabled'.locale(context);
      case 'operation-not-allowed':
        return 'auth_operation_not_allowed'.locale(context);
      case 'invalid-credential':
        return 'auth_invalid_credential'.locale(context);
      default:
        return error.message ?? 'auth_unknown_error'.locale(context);
    }
  }

  /// BaseCubit'den gelen hata state emit metodu
  @override
  void emitErrorState(String errorMessage) {
    emit(AuthError(
      message: errorMessage,
      isCritical: false,
      previousState: state,
    ));
  }

  /// BaseCubit'den gelen loading state emit metodu
  @override
  void emitLoadingState() {
    emit(const AuthLoading());
  }

  /// Cubit dispose edildiğinde stream subscription'ı iptal et
  @override
  Future<void> close() {
    logInfo('AuthCubit kapatılıyor');
    _authSubscription?.cancel();
    return super.close();
  }
}
