import 'package:equatable/equatable.dart';
import 'package:tatarai/core/models/user_model.dart';

/// Ayarlar sayfası state sınıfı
/// Kullanıcı bilgileri ve durum bilgilerini yönetir
class SettingsState extends Equatable {
  /// Kullanıcı bilgileri
  final UserModel? user;

  /// Yükleniyor durumu
  final bool isLoading;

  /// Hata mesajı
  final String? errorMessage;

  /// Başarı mesajı
  final String? successMessage;

  /// Constructor
  const SettingsState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  /// State kopyalama metodu
  SettingsState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return SettingsState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  /// Equatable props
  @override
  List<Object?> get props => [
        user,
        isLoading,
        errorMessage,
        successMessage,
      ];

  /// Debug için string representation
  @override
  String toString() {
    return 'SettingsState{'
        'user: $user, '
        'isLoading: $isLoading, '
        'errorMessage: $errorMessage, '
        'successMessage: $successMessage'
        '}';
  }

  /// Hata durumunda mı?
  bool get hasError => errorMessage != null;

  /// Başarı durumunda mı?
  bool get hasSuccess => successMessage != null;

  /// Kullanıcı var mı?
  bool get hasUser => user != null;
}
