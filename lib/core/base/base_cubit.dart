import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/base/base_state.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Temel Cubit sınıfı - tüm Cubit'ler için temel yapı
abstract class BaseCubit<T extends BaseState> extends Cubit<T> {
  BaseCubit(super.initialState);

  /// Sınıf adını döndürür
  String get _cubitName => runtimeType.toString();

  /// Hata durumunu işleme
  void handleError(String operation, dynamic error, [StackTrace? stackTrace]) {
    // Hata mesajını loglara yazdır
    AppLogger.errorWithContext(_cubitName, operation, error, stackTrace);

    // Firebase ve diğer hatalar için teknik detayları loglara yazdırıp,
    // kullanıcıya gösterilmemesini sağla
    emitErrorState(_sanitizeErrorMessage(error));
  }

  /// Hata mesajını kullanıcı dostu hale getirir
  String _sanitizeErrorMessage(dynamic error) {
    if (error == null) {
      return 'Bilinmeyen bir hata oluştu';
    }

    String errorString = error.toString();

    // Hata mesajı içinde teknik detaylar içeriyorsa bunları filtrele
    if (errorString.contains('Exception:') ||
        errorString.contains('Error:') ||
        errorString.contains('firebase_auth') ||
        errorString.contains('FirebaseAuth')) {
      return 'Bir sorun oluştu, lütfen daha sonra tekrar deneyin';
    }

    return errorString;
  }

  /// Hata durumunu emit etme (implementasyonu alt sınıflar yapacak)
  void emitErrorState(String errorMessage);

  /// Yükleme durumunu emit etme (implementasyonu alt sınıflar yapacak)
  void emitLoadingState();

  /// Başarılı işlemleri loglama
  void logSuccess(String operation, [String? details]) {
    AppLogger.successWithContext(_cubitName, operation, details);
  }

  /// Bilgi loglama
  void logInfo(String message, [dynamic details]) {
    AppLogger.logWithContext(_cubitName, message, details);
  }

  /// Uyarı loglama
  void logWarning(String message, [dynamic details]) {
    AppLogger.warnWithContext(_cubitName, message, details);
  }
}
