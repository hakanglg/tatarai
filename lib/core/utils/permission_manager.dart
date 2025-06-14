/// İzin Yöneticisi (Permission Manager)
///
/// Bu modül, uygulama genelinde izin isteklerini merkezi olarak yönetir.
/// Kullanıcı deneyimini iyileştirmek için profesyonel ve açıklayıcı izin
/// diyalogları sunar ve tüm izin işlemlerini standart bir şekilde ele alır.
///
/// Özellikleri:
/// - Tek izin veya birden fazla izin isteme
/// - Özelleştirilmiş ve kullanıcı dostu bilgi mesajları
/// - İzinlerin reddedilmesi veya kalıcı olarak reddedilmesi durumlarını yönetme
/// - iOS ve Android platformları için optimize edilmiş ayar açma yöntemleri
///
/// Kullanım Örnekleri:
/// ```dart
/// // Tek izin isteme
/// bool hasPermission = await PermissionManager.requestPermission(
///   AppPermissionType.camera,
///   context: context,
/// );
///
/// // Çoklu izin isteme
/// Map<AppPermissionType, bool> results = await PermissionManager.requestMultiplePermissions(
///   [AppPermissionType.camera, AppPermissionType.location],
///   context: context,
/// );
/// ```
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';

/// Uygulama içinde kullanılabilecek izin türlerini tanımlayan enum
enum AppPermissionType {
  camera,
  photos,
  microphone,
  location,
  storage,
  notification,
}

/// Uygulama genelinde izin yönetimini merkezileştiren sınıf.
///
/// Bu sınıf, tüm izin işlemlerini yönetir ve kullanıcı deneyimini iyileştirmek
/// için tutarlı bir arayüz sağlar. Kamera, mikrofon, konum gibi hassas izinleri
/// profesyonel bir şekilde ele alır ve kullanıcıları yönlendirir.
class PermissionManager {
  PermissionManager._(); // Singleton için private constructor

  /// İstenilen izni kontrol eder ve gerekiyorsa ister
  static Future<bool> requestPermission(
    AppPermissionType type, {
    BuildContext? context,
  }) async {
    try {
      // İzin türüne göre permission_handler tipini belirle
      final Permission permission = _getPermissionFromType(type);

      // İzin durumunu kontrol et
      final status = await permission.status;

      AppLogger.i('${_getPermissionName(type)} izin durumu: $status');

      // İzin zaten verilmiş
      if (status.isGranted) {
        return true;
      }

      // İzin daha önce kalıcı olarak reddedilmiş
      if (status.isPermanentlyDenied) {
        if (context != null) {
          _showPermissionPermanentlyDeniedDialog(context, type);
        }
        return false;
      }

      // İlk defa veya daha önce reddedilmiş, izin iste
      final result = await permission.request();

      AppLogger.i('${_getPermissionName(type)} izin isteği sonucu: $result');

      // Kullanıcı izin vermedi ve context varsa bilgilendirme göster
      if (!result.isGranted && context != null) {
        _showPermissionDeniedDialog(context, type);
      }

      return result.isGranted;
    } catch (e) {
      AppLogger.e('İzin isteği sırasında hata', e);
      return false;
    }
  }

  /// İzin durumunu kontrol et
  static Future<bool> hasPermission(AppPermissionType type) async {
    try {
      final Permission permission = _getPermissionFromType(type);
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.e('İzin kontrolü sırasında hata', e);
      return false;
    }
  }

  /// Enum tipinden Permission objesine dönüşüm
  static Permission _getPermissionFromType(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return Permission.camera;
      case AppPermissionType.photos:
        return Permission.photos;
      case AppPermissionType.microphone:
        return Permission.microphone;
      case AppPermissionType.location:
        return Permission.locationWhenInUse;
      case AppPermissionType.storage:
        return Permission.storage;
      case AppPermissionType.notification:
        return Permission.notification;
    }
  }

  /// İzin türünün okunabilir ismini döndürür
  static String _getPermissionName(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Kamera';
      case AppPermissionType.photos:
        return 'Fotoğraf Galerisi';
      case AppPermissionType.microphone:
        return 'Mikrofon';
      case AppPermissionType.location:
        return 'Konum Servisi';
      case AppPermissionType.storage:
        return 'Depolama Alanı';
      case AppPermissionType.notification:
        return 'Bildirim Servisi';
    }
  }

  /// İzin reddedildiğinde gösterilecek diyalog
  static void _showPermissionDeniedDialog(
    BuildContext context,
    AppPermissionType type,
  ) {
    // AppDialogManager kullanarak izin diyaloğunu göster
    AppDialogManager.showSettingsDialog(
        context: context,
        title: 'Özellik İzni Gerekiyor',
        message: _getPermissionDeniedMessage(type),
        settingsText: 'İzin Ver',
        cancelText: 'Daha Sonra',
        onSettingsPressed: () {
          Navigator.pop(context);
          _openAppSettings();
        });
  }

  /// İzin kalıcı olarak reddedildiğinde gösterilecek diyalog
  static void _showPermissionPermanentlyDeniedDialog(
    BuildContext context,
    AppPermissionType type,
  ) {
    // Hata ikonu ile ayarlar diyaloğunu göster
    AppDialogManager.showIconDialog(
      context: context,
      icon: CupertinoIcons.hand_raised,
      iconColor: AppColors.warning,
      title: 'İzin Ayarları',
      message: _getPermissionPermanentlyDeniedMessage(type),
      buttonText: 'Ayarları Aç',
      onPressed: () {
        Navigator.pop(context);
        _openAppSettings();
      },
    );
  }

  /// İzin için uygun ikonu döndürür
  static IconData _getPermissionIcon(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return CupertinoIcons.camera;
      case AppPermissionType.photos:
        return CupertinoIcons.photo;
      case AppPermissionType.microphone:
        return CupertinoIcons.mic;
      case AppPermissionType.location:
        return CupertinoIcons.location;
      case AppPermissionType.storage:
        return CupertinoIcons.folder;
      case AppPermissionType.notification:
        return CupertinoIcons.bell;
    }
  }

  /// İzin reddedilme mesajını döndürür
  static String _getPermissionDeniedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Daha iyi bir deneyim için kamera erişimine izin vermeniz gerekiyor. Bu izin sadece uygulama aktif olduğunda kullanılır.';
      case AppPermissionType.photos:
        return 'Fotoğraflarınızı analiz edebilmek için galerinize sınırlı erişim iznine ihtiyacımız var. Verileriniz güvende tutulur.';
      case AppPermissionType.microphone:
        return 'Sesli komutları kullanabilmek için mikrofon iznine ihtiyacımız var. Bu izin sadece gerektiğinde kullanılır.';
      case AppPermissionType.location:
        return 'Konuma özel hizmetler sunabilmek için konum izni gerekiyor. Bu, daha doğru tarımsal öneriler almanızı sağlar.';
      case AppPermissionType.storage:
        return 'Fotoğrafları kaydetmek ve görüntülemek için depolama iznine ihtiyacımız var. Verileriniz cihazınızda güvenle saklanır.';
      case AppPermissionType.notification:
        return 'Önemli tarımsal uyarılar ve yeniliklerden haberdar olmak için bildirim izni vermeniz gerekiyor.';
    }
  }

  /// İzin kalıcı olarak reddedilme mesajını döndürür
  static String _getPermissionPermanentlyDeniedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Kamera erişimi olmadan bu özellik kullanılamaz. Lütfen uygulama ayarlarından kamera iznini etkinleştirin.';
      case AppPermissionType.photos:
        return 'Galeri erişimi olmadan fotoğraf analizi yapılamaz. Lütfen uygulama ayarlarından galeri iznini etkinleştirin.';
      case AppPermissionType.microphone:
        return 'Sesli komutları kullanabilmek için ayarlardan mikrofon iznini etkinleştirmeniz gerekiyor.';
      case AppPermissionType.location:
        return 'Konum bazlı özellikler için ayarlardan konum izni vermeniz gerekiyor. Bu, tam anlamıyla hizmet alabilmeniz için önemlidir.';
      case AppPermissionType.storage:
        return 'Verileri kaydetmek ve görüntülemek için depolama izni gerekiyor. Lütfen ayarlardan bu izni etkinleştirin.';
      case AppPermissionType.notification:
        return 'Önemli tarımsal uyarıları kaçırmamak için bildirim iznini ayarlardan etkinleştirmenizi öneririz.';
    }
  }

  /// Sistem izin ayarları sayfasını açar
  static Future<void> _openAppSettings() async {
    try {
      AppLogger.i('İzin ayarları açılıyor...');

      if (Platform.isIOS) {
        try {
          AppLogger.i('iOS: Ayarlar uygulaması açılıyor...');

          // iOS için en güvenli yöntem: doğrudan ayarlar uygulamasını açma
          await AppSettings.openAppSettings();
          AppLogger.i('iOS: Ayarlar uygulaması açıldı');
          return;
        } catch (e) {
          AppLogger.e('iOS: Ayarlar uygulaması açılamadı', e);

          // Kullanıcıya manuel talimatlar verelim
          AppLogger.i('iOS: Kullanıcıya manuel yönergeler veriliyor');
        }
      } else {
        // Android platform için standart yaklaşım
        AppLogger.i('Android: İzin ayarları açılıyor');
        await AppSettings.openAppSettings();
        AppLogger.i('Android: İzin ayarları açıldı');
      }
    } catch (e) {
      AppLogger.e('Sistem izin ayarları açılamadı', e);
      AppLogger.i('Kullanıcıya manuel izin ayarları talimatları gösteriliyor');
    }
  }

  /// iOS için gallery/camera izin kontrolü (daha güvenilir)
  static Future<bool> checkIOSMediaPermission(AppPermissionType type) async {
    try {
      if (!Platform.isIOS) return true;

      AppLogger.i(
          'iOS: ${_getPermissionName(type)} izni doğrudan kontrol ediliyor');

      final Permission permission = _getPermissionFromType(type);
      final status = await permission.status;

      AppLogger.i('iOS: ${_getPermissionName(type)} izin durumu: $status');
      return status.isGranted;
    } catch (e) {
      AppLogger.e('iOS izin kontrolü hatası', e);
      return false;
    }
  }

  /// Çoklu izin isteme
  static Future<Map<AppPermissionType, bool>> requestMultiplePermissions(
    List<AppPermissionType> types, {
    BuildContext? context,
  }) async {
    final Map<AppPermissionType, bool> results = {};

    for (final type in types) {
      results[type] = await requestPermission(type, context: context);
    }

    return results;
  }
}
