import 'package:flutter/material.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Tüm StatefulWidget State'leri için temel sınıf.
/// Bu sınıf, widget'ın hala ağaçta olup olmadığını kontrol eden yardımcı metodlar içerir.
abstract class BaseState<T extends StatefulWidget> extends State<T> {
  /// Widget hala ağaçta ise belirtilen işlevi çalıştırır.
  /// Eğer widget artık ağaçta değilse işlem yapılmaz.
  ///
  /// [action] - Çalıştırılacak işlev
  /// [logError] - Hata durumunda log'a kaydedilecek mesaj
  ///
  /// Widget'ın artık ağaçta olmadığı durumlarda hata fırlatmayı engeller.
  void runIfMounted(VoidCallback action, [String? logError]) {
    if (mounted) {
      try {
        action();
      } catch (e, stack) {
        if (logError != null) {
          AppLogger.e('$logError: $e', e, stack);
        }
      }
    }
  }

  /// Widget hala ağaçta ise setState çalıştırır.
  /// Eğer widget artık ağaçta değilse hiçbir şey yapmaz.
  ///
  /// [setStateAction] - setState içinde çalıştırılacak işlev
  ///
  /// "setState() called after dispose()" hatalarını engeller.
  void setStateIfMounted(VoidCallback setStateAction) {
    if (mounted) {
      try {
        setState(setStateAction);
      } catch (e, stack) {
        AppLogger.e('setState hatası: $e', e, stack);
      }
    }
  }

  /// Future işlemlerini güvenli bir şekilde çalıştırır.
  /// Future tamamlandığında widget hala ağaçta ise [onComplete] fonksiyonunu çalıştırır.
  ///
  /// [future] - Çalıştırılacak Future
  /// [onComplete] - Future tamamlandığında çalıştırılacak callback (eğer widget hala mounted ise)
  /// [onError] - Hata durumunda çalıştırılacak callback (eğer widget hala mounted ise)
  /// [errorMessage] - Hata durumunda log'a kaydedilecek mesaj
  ///
  /// Widget dispose olduktan sonra Future'ın sonucunu işlemeyi engeller.
  Future<void> runFutureSafe<R>(
    Future<R> future, {
    Function(R result)? onComplete,
    Function(Object error, StackTrace stackTrace)? onError,
    String? errorMessage,
  }) async {
    try {
      final result = await future;
      if (mounted && onComplete != null) {
        onComplete(result);
      }
    } catch (e, stack) {
      if (errorMessage != null) {
        AppLogger.e('$errorMessage: $e', e, stack);
      }
      if (mounted && onError != null) {
        onError(e, stack);
      }
    }
  }
}
