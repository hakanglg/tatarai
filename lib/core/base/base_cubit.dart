import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/utils/logger.dart';

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

/// Temel Cubit sınıfı - tüm Cubit'ler için temel yapı
abstract class BaseCubit<T extends BaseState> extends Cubit<T> {
  BaseCubit(super.initialState);

  /// Hata durumunu işleme
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.e('$runtimeType - $operation hatası: $error', error, stackTrace);

    final errorMessage =
        error is Exception ? error.toString() : 'Bir hata oluştu';
    emitErrorState(errorMessage);
  }

  /// Hata durumunu emit etme (implementasyonu alt sınıflar yapacak)
  void emitErrorState(String errorMessage);

  /// Yükleme durumunu emit etme (implementasyonu alt sınıflar yapacak)
  void emitLoadingState();

  /// Başarılı işlemleri loglama
  void logSuccess(String operation, [String? details]) {
    AppLogger.i(
      '$runtimeType - $operation başarılı${details != null ? ': $details' : ''}',
    );
  }

  /// Bilgi loglama
  void logInfo(String message) {
    AppLogger.i('$runtimeType - $message');
  }
}
