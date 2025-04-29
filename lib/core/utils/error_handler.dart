import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Firebase ve genel hataları daha kullanıcı dostu mesajlara dönüştüren yardımcı sınıf
class ErrorHandler {
  /// Firestore hatalarını işle
  static String handleFirestoreError(dynamic error) {
    String errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          errorMessage = 'Bu işlem için yetkiniz bulunmuyor.';
          break;
        case 'unavailable':
          errorMessage =
              'Veritabanına şu anda ulaşılamıyor. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.';
          break;
        case 'not-found':
          errorMessage = 'İstenen belge bulunamadı.';
          break;
        case 'already-exists':
          errorMessage = 'Bu belge zaten mevcut.';
          break;
        case 'failed-precondition':
          errorMessage =
              'İşlem şu anda gerçekleştirilemiyor. Lütfen daha sonra tekrar deneyin.';
          break;
        case 'resource-exhausted':
          errorMessage =
              'İstek limiti aşıldı. Lütfen daha sonra tekrar deneyin.';
          break;
        case 'cancelled':
          errorMessage = 'İşlem iptal edildi.';
          break;
        case 'data-loss':
          errorMessage = 'Veri kaybı oluştu. Lütfen tekrar deneyin.';
          break;
        case 'unauthenticated':
          errorMessage = 'Oturum açmanız gerekiyor.';
          break;
        case 'invalid-argument':
          errorMessage = 'Geçersiz veri formatı.';
          break;
        default:
          errorMessage = 'Firestore hatası: ${error.code} - ${error.message}';
          break;
      }
    } else if (error is SocketException) {
      errorMessage = 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (error is TimeoutException) {
      errorMessage =
          'İşlem zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin.';
    }

    // Hata logunu kaydet
    AppLogger.e('Firestore hatası: $errorMessage', error);

    return errorMessage;
  }

  /// Firebase Auth hatalarını işle
  static String handleAuthError(dynamic error) {
    String errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanılıyor.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        case 'user-disabled':
          errorMessage = 'Bu kullanıcı devre dışı bırakılmış.';
          break;
        case 'user-not-found':
          errorMessage =
              'Bu e-posta adresine kayıtlı bir kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
          errorMessage = 'Hatalı şifre girdiniz.';
          break;
        case 'weak-password':
          errorMessage =
              'Şifreniz çok zayıf. Lütfen daha güçlü bir şifre seçin.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Bu işlem şu anda izin verilmiyor.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage =
              'Bu e-posta adresi farklı bir giriş yöntemiyle zaten kullanılıyor.';
          break;
        case 'requires-recent-login':
          errorMessage = 'Bu işlem için yeniden giriş yapmanız gerekiyor.';
          break;
        case 'network-request-failed':
          errorMessage =
              'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Çok fazla başarısız istek. Lütfen daha sonra tekrar deneyin.';
          break;
        default:
          errorMessage =
              'Kimlik doğrulama hatası: ${error.code} - ${error.message}';
          break;
      }
    }

    // Hata logunu kaydet
    AppLogger.e('Firebase Auth hatası: $errorMessage', error);

    return errorMessage;
  }

  /// Firebase Storage hatalarını işle
  static String handleStorageError(dynamic error) {
    String errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';

    if (error is FirebaseException) {
      switch (error.code) {
        case 'storage/object-not-found':
          errorMessage = 'Dosya bulunamadı.';
          break;
        case 'storage/unauthorized':
          errorMessage = 'Bu işlem için yetkiniz bulunmuyor.';
          break;
        case 'storage/canceled':
          errorMessage = 'İşlem iptal edildi.';
          break;
        case 'storage/unknown':
          errorMessage = 'Bilinmeyen bir hata oluştu. Lütfen tekrar deneyin.';
          break;
        case 'storage/retry-limit-exceeded':
          errorMessage =
              'Yeniden deneme limiti aşıldı. Lütfen daha sonra tekrar deneyin.';
          break;
        case 'storage/invalid-checksum':
          errorMessage = 'Dosya yükleme hatası. Lütfen tekrar deneyin.';
          break;
        case 'storage/quota-exceeded':
          errorMessage = 'Depolama kotası aşıldı.';
          break;
        default:
          errorMessage = 'Storage hatası: ${error.code} - ${error.message}';
          break;
      }
    }

    // Hata logunu kaydet
    AppLogger.e('Firebase Storage hatası: $errorMessage', error);

    return errorMessage;
  }

  /// Genel hataları işle
  static String handleGeneralError(dynamic error) {
    String errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';

    if (error is FirebaseException) {
      if (error.plugin == 'cloud_firestore') {
        return handleFirestoreError(error);
      } else if (error.plugin == 'firebase_auth') {
        return handleAuthError(error);
      } else if (error.plugin == 'firebase_storage') {
        return handleStorageError(error);
      }
    } else if (error is SocketException) {
      errorMessage = 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (error is TimeoutException) {
      errorMessage =
          'İşlem zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin.';
    } else if (error is FormatException) {
      errorMessage = 'Verilerde biçim hatası.';
    } else if (error is StateError) {
      errorMessage = 'Uygulama durumu hatası.';
    }

    // Hata logunu kaydet
    AppLogger.e('Genel hata: $errorMessage', error);

    return errorMessage;
  }
}
