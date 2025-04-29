import 'package:equatable/equatable.dart';

/// Temel durum sınıfı - tüm state sınıfları için temel yapı
abstract class BaseState extends Equatable {
  /// Yükleniyor durumu
  final bool isLoading;

  /// Hata mesajı
  final String? errorMessage;

  /// Default constructor
  const BaseState({this.isLoading = false, this.errorMessage});

  @override
  List<Object?> get props => [isLoading, errorMessage];
}
