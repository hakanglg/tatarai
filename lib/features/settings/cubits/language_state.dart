import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:tatarai/core/constants/locale_constants.dart';

/// Dil seçimi durumunu yöneten State sınıfı
/// Immutable yapı ile güvenli state yönetimi sağlar
class LanguageState extends Equatable {
  /// Mevcut seçili dil
  final Locale currentLocale;

  /// Yükleniyor durumu
  final bool isLoading;

  /// Hata mesajı
  final String? errorMessage;

  /// Başarı mesajı
  final String? successMessage;

  /// Constructor
  const LanguageState({
    this.currentLocale = LocaleConstants.fallbackLocale,
    this.isLoading = true,
    this.errorMessage,
    this.successMessage,
  });

  /// State kopyalama metodu
  /// İmmutable state güncellemeleri için kullanılır
  LanguageState copyWith({
    Locale? currentLocale,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return LanguageState(
      currentLocale: currentLocale ?? this.currentLocale,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // null geçebilir
      successMessage: successMessage, // null geçebilir
    );
  }

  /// Equatable için props
  @override
  List<Object?> get props => [
        currentLocale,
        isLoading,
        errorMessage,
        successMessage,
      ];

  /// Debug için string representation
  @override
  String toString() {
    return 'LanguageState{'
        'currentLocale: $currentLocale, '
        'isLoading: $isLoading, '
        'errorMessage: $errorMessage, '
        'successMessage: $successMessage'
        '}';
  }

  /// Mevcut dilin kodu
  String get currentLanguageCode => currentLocale.languageCode;

  /// Mevcut dilin ülke kodu
  String? get currentCountryCode => currentLocale.countryCode;

  /// Mevcut dilin tam kodu (tr_TR formatında)
  String get currentFullCode {
    if (currentCountryCode != null) {
      return '${currentLanguageCode}_$currentCountryCode';
    }
    return currentLanguageCode;
  }

  /// Herhangi bir mesaj var mı?
  bool get hasMessage => errorMessage != null || successMessage != null;

  /// Hata durumunda mı?
  bool get hasError => errorMessage != null;

  /// Başarı durumunda mı?
  bool get hasSuccess => successMessage != null;
}
