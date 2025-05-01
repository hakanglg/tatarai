import 'package:tatarai/core/base/base_state.dart';
import 'package:tatarai/features/auth/models/user_model.dart';

/// Kimlik doğrulama durumunu temsil eden sınıf
class AuthState extends BaseState {
  final AuthStatus status;
  final UserModel? user;
  final bool showRetryButton;
  final String? successMessage;
  final String? pendingOperationMessage;
  final String? retryOperation;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    super.isLoading = false,
    super.errorMessage,
    this.showRetryButton = false,
    this.successMessage,
    this.pendingOperationMessage,
    this.retryOperation,
  });

  /// İlk durum
  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial, isLoading: false);
  }

  /// Kullanıcı giriş yapmış
  factory AuthState.authenticated(UserModel user) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isLoading: false,
    );
  }

  /// Kullanıcı çıkış yapmış
  factory AuthState.unauthenticated({String? errorMessage}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
      errorMessage: errorMessage,
    );
  }

  /// Hata durumu
  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      isLoading: false,
    );
  }

  /// Yükleniyor durumu
  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading, isLoading: true);
  }

  /// Mevcut durumu kopyalayarak yeni durum oluşturur
  @override
  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? isLoading,
    bool clearUser = false,
    bool clearError = false,
    bool? showRetryButton,
    String? successMessage,
    String? pendingOperationMessage,
    String? retryOperation,
    bool clearSuccessMessage = false,
    bool clearPendingOperation = false,
    bool clearRetryOperation = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
      showRetryButton: showRetryButton ?? this.showRetryButton,
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      pendingOperationMessage: clearPendingOperation
          ? null
          : (pendingOperationMessage ?? this.pendingOperationMessage),
      retryOperation:
          clearRetryOperation ? null : (retryOperation ?? this.retryOperation),
    );
  }

  /// Kullanıcının giriş yapıp yapmadığını kontrol eder
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  /// Kullanıcının premium olup olmadığını kontrol eder
  bool get isPremium => user?.isPremium ?? false;

  /// Kullanıcının admin olup olmadığını kontrol eder
  bool get isAdmin => user?.isAdmin ?? false;

  /// Kullanıcının yeterli analiz kredisine sahip olup olmadığını kontrol eder
  bool get hasAnalysisCredits => user?.hasAnalysisCredits ?? false;

  /// Bağlantı yeniden kurulduğunda yeniden deneme gösterilip gösterilmeyeceğini kontrol eder
  bool get canRetry => showRetryButton || pendingOperationMessage != null;

  /// Başarılı bir işlem sonucu mesaj varsa kontrol eder
  bool get hasSuccessMessage =>
      successMessage != null && successMessage!.isNotEmpty;

  /// Bekleyen bir işlem mesajı varsa kontrol eder
  bool get hasPendingOperationMessage =>
      pendingOperationMessage != null && pendingOperationMessage!.isNotEmpty;

  @override
  List<Object?> get props => [
        ...super.props,
        status,
        user,
        showRetryButton,
        successMessage,
        pendingOperationMessage,
        retryOperation
      ];

  /// State'in durumunu kontrol eden kolaylık metodları
  bool get isInitial => status == AuthStatus.initial;
  bool get isLoggingIn => isLoading && status != AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

/// Kimlik doğrulama durumları
enum AuthStatus {
  /// Başlangıç durumu
  initial,

  /// Kullanıcı giriş yapmış
  authenticated,

  /// Kullanıcı giriş yapmamış
  unauthenticated,

  /// Yükleniyor
  loading,

  /// Hata
  error,
}
