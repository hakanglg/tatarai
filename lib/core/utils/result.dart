import 'package:equatable/equatable.dart';

/// Fonksiyon sonuçlarını temsil eden jenerik sınıf
/// Başarılı ve başarısız durumları işlemek için kullanılır
class FunctionResult<T> extends Equatable {
  /// Başarı durumu
  final bool isSuccess;

  /// Hata mesajı (eğer başarısız ise)
  final String? errorMessage;

  /// Veri (eğer başarılı ise)
  final T? data;

  /// Özel constructor - doğrudan çağrılmamalı
  const FunctionResult._({
    required this.isSuccess,
    this.errorMessage,
    this.data,
  });

  /// Başarılı sonuç oluşturur
  factory FunctionResult.success(T data) {
    return FunctionResult._(isSuccess: true, data: data);
  }

  /// Başarısız sonuç oluşturur
  factory FunctionResult.failure(String message) {
    return FunctionResult._(isSuccess: false, errorMessage: message);
  }

  /// İşlemin başarılı olup olmadığını kontrol eder
  bool get isFailure => !isSuccess;

  /// Verinin güvenli bir şekilde alınması
  /// Eğer veri null ise defaultValue döner
  T getDataOrDefault(T defaultValue) {
    if (data == null) {
      return defaultValue;
    }
    return data as T;
  }

  /// Durumu farklı veri türüne dönüştürür
  FunctionResult<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      final T nonNullData = data as T;
      return FunctionResult.success(mapper(nonNullData));
    }
    return FunctionResult.failure(errorMessage ?? 'Dönüştürme hatası');
  }

  /// Durumu işleme
  /// İşlem başarılı ise onSuccess, başarısız ise onFailure çağrılır
  R fold<R>({
    required R Function(T? data) onSuccess,
    required R Function(String errorMessage) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(data);
    } else {
      return onFailure(errorMessage ?? 'Bilinmeyen hata');
    }
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'FunctionResult.success(data: $data)';
    } else {
      return 'FunctionResult.failure(error: $errorMessage)';
    }
  }

  @override
  List<Object?> get props => [isSuccess, errorMessage, data];
}
