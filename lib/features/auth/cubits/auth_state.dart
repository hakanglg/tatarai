import '../../../core/models/user_model.dart';
import '../../../core/base/base_state.dart';

/// Authentication durumu base sınıfı
///
/// Tüm auth state'leri bu sınıftan türetilir. BaseState kullanarak
/// ortak loading ve error handling özelliklerini devralır.
///
/// Desteklenen durumlar:
/// - AuthInitial: Başlangıç durumu
/// - AuthLoading: Yükleme durumu
/// - AuthAuthenticated: Kimlik doğrulanmış durumu
/// - AuthUnauthenticated: Kimlik doğrulanmamış durumu
/// - AuthError: Hata durumu
abstract class AuthState extends BaseState {
  const AuthState({
    super.isLoading = false,
    super.errorMessage,
    super.error,
  });

  /// Kullanıcının kimlik doğrulanmış olup olmadığını kontrol eder
  bool get isAuthenticated => this is AuthAuthenticated;

  /// Auth durumunun string temsilini döner
  String get status {
    if (this is AuthInitial) return 'initial';
    if (this is AuthLoading) return 'loading';
    if (this is AuthAuthenticated) return 'authenticated';
    if (this is AuthUnauthenticated) return 'unauthenticated';
    if (this is AuthError) return 'error';
    return 'unknown';
  }
}

/// Auth sistem başlangıç durumu
///
/// Uygulama ilk açıldığında bu state aktif olur.
/// Auth kontrolü henüz yapılmamıştır.
class AuthInitial extends AuthState {
  const AuthInitial() : super();

  @override
  List<Object?> get props => [...super.props];

  @override
  String toString() => 'AuthInitial';
}

/// Auth işlemi devam ediyor durumu
///
/// Giriş, kayıt, çıkış gibi auth işlemleri sırasında
/// bu state aktif olur. Loading indicator göstermek için kullanılır.
class AuthLoading extends AuthState {
  /// Yükleme mesajı (opsiyonel)
  final String? message;

  const AuthLoading({
    this.message,
  }) : super(isLoading: true);

  @override
  List<Object?> get props => [...super.props, message];

  @override
  String toString() => 'AuthLoading{message: $message}';
}

/// Kimlik doğrulanmış kullanıcı durumu
///
/// Kullanıcı başarılı bir şekilde giriş yaptığında bu state aktif olur.
/// UserModel ile birlikte kullanıcı bilgilerini tutar.
class AuthAuthenticated extends AuthState {
  /// Kimlik doğrulanmış kullanıcı bilgileri
  final UserModel user;

  /// Kullanıcının ilk kez giriş yapıp yapmadığı (onboarding için)
  final bool isFirstTime;

  const AuthAuthenticated({
    required this.user,
    this.isFirstTime = false,
  }) : super();

  @override
  List<Object?> get props => [...super.props, user, isFirstTime];

  @override
  String toString() =>
      'AuthAuthenticated{user: ${user.id}, isFirstTime: $isFirstTime}';

  /// State kopyalama metodu
  AuthAuthenticated copyWith({
    UserModel? user,
    bool? isFirstTime,
  }) {
    return AuthAuthenticated(
      user: user ?? this.user,
      isFirstTime: isFirstTime ?? this.isFirstTime,
    );
  }

  /// Kullanıcının anonim olup olmadığını kontrol eder (hep true)
  bool get isAnonymous => true;

  /// Kullanıcının profili tam dolu mu kontrol eder
  bool get isProfileComplete =>
      user.name.isNotEmpty && user.name != 'Misafir Kullanıcı';

  /// Kullanıcının premium üye olup olmadığını kontrol eder
  bool get isPremium => user.isPremium;

  /// Kullanıcının analiz hakkı var mı kontrol eder
  bool get canAnalyze => user.canAnalyze;
}

/// Kimlik doğrulanmamış kullanıcı durumu
///
/// Kullanıcı çıkış yaptığında veya session süresi dolduğunda
/// bu state aktif olur. Login ekranına yönlendirme için kullanılır.
class AuthUnauthenticated extends AuthState {
  /// Çıkış nedenini açıklayan mesaj (opsiyonel)
  final String? reason;

  /// Kullanıcının daha önce giriş yapıp yapmadığı
  final bool hasLoggedInBefore;

  const AuthUnauthenticated({
    this.reason,
    this.hasLoggedInBefore = false,
  }) : super();

  @override
  List<Object?> get props => [...super.props, reason, hasLoggedInBefore];

  @override
  String toString() =>
      'AuthUnauthenticated{reason: $reason, hasLoggedInBefore: $hasLoggedInBefore}';
}

/// Auth işlemi hata durumu
///
/// Giriş, kayıt veya diğer auth işlemleri sırasında
/// hata oluştuğunda bu state aktif olur.
class AuthError extends AuthState {
  /// Hata kodu (opsiyonel)
  final String? errorCode;

  /// Önceki auth durumu (hata sonrası geri dönmek için)
  final AuthState? previousState;

  /// Hatanın kritik olup olmadığı
  final bool isCritical;

  const AuthError({
    required String message,
    this.errorCode,
    this.previousState,
    this.isCritical = false,
    super.error,
  }) : super(
          errorMessage: message,
        );

  @override
  List<Object?> get props =>
      [...super.props, errorCode, previousState, isCritical];

  @override
  String toString() =>
      'AuthError{message: $errorMessage, errorCode: $errorCode, isCritical: $isCritical}';

  /// Yaygın Firebase Auth hata kodları için Türkçe mesajlar
  String get localizedMessage {
    switch (errorCode) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Hatalı şifre';
      case 'email-already-in-use':
        return 'Bu email adresi zaten kullanımda';
      case 'weak-password':
        return 'Şifre çok zayıf';
      case 'invalid-email':
        return 'Geçersiz email adresi';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
      case 'network-request-failed':
        return 'İnternet bağlantısı hatası';
      case 'user-disabled':
        return 'Kullanıcı hesabı devre dışı bırakılmış';
      case 'operation-not-allowed':
        return 'Bu işlem izinli değil';
      case 'invalid-credential':
        return 'Geçersiz kimlik bilgileri';
      default:
        return errorMessage ?? 'Bilinmeyen hata';
    }
  }

  /// Hata türüne göre kullanıcıya önerilecek aksiyonlar
  List<String> get suggestedActions {
    switch (errorCode) {
      case 'user-not-found':
        return ['Yeni hesap oluşturun', 'Email adresinizi kontrol edin'];
      case 'wrong-password':
        return ['Şifreyi sıfırlayın', 'Şifrenizi kontrol edin'];
      case 'email-already-in-use':
        return ['Giriş yapmayı deneyin', 'Farklı email kullanın'];
      case 'weak-password':
        return [
          'En az 6 karakter kullanın',
          'Büyük/küçük harf ve sayı ekleyin'
        ];
      case 'invalid-email':
        return ['Email formatını kontrol edin', 'Geçerli bir email girin'];
      case 'too-many-requests':
        return ['15 dakika bekleyin', 'Şifreyi sıfırlamayı deneyin'];
      case 'network-request-failed':
        return ['İnternet bağlantınızı kontrol edin', 'Tekrar deneyin'];
      default:
        return ['Tekrar deneyin', 'Destek ile iletişime geçin'];
    }
  }

  /// Hatanın otomatik düzelip düzelmeyeceği
  bool get isRetryable {
    switch (errorCode) {
      case 'network-request-failed':
      case 'too-many-requests':
        return true;
      case 'user-not-found':
      case 'wrong-password':
      case 'email-already-in-use':
      case 'weak-password':
      case 'invalid-email':
      case 'user-disabled':
      case 'operation-not-allowed':
      case 'invalid-credential':
        return false;
      default:
        return false;
    }
  }
}
