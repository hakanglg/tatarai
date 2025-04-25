import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/features/auth/models/user_model.dart';

/// Kimlik doğrulama durumunu temsil eden sınıf
class AuthState extends BaseState {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    super.isLoading = false,
    super.errorMessage,
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
  factory AuthState.unauthenticated() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
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
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Kullanıcının giriş yapıp yapmadığını kontrol eder
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  /// Kullanıcının premium olup olmadığını kontrol eder
  bool get isPremium => user?.role == 'premium';

  /// Kullanıcının admin olup olmadığını kontrol eder
  bool get isAdmin => user?.role == 'admin';

  /// Kullanıcının yeterli analiz kredisine sahip olup olmadığını kontrol eder
  bool get hasAnalysisCredits => (user?.analysisCredits ?? 0) > 0;

  @override
  List<Object?> get props => [...super.props, status, user];
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
