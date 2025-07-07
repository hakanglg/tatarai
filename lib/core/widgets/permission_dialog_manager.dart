import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/services/permission_service.dart';
import 'package:tatarai/core/utils/logger.dart';

/// 🎭 Merkezi izin dialog yöneticisi
///
/// Tüm uygulamadaki izin dialog'larını tek yerden yönetir.
/// Localization desteği ile kullanıcı dostu mesajlar sağlar.
class PermissionDialogManager {
  PermissionDialogManager._();

  /// Kamera izni reddedildiğinde gösterilecek dialog
  static Future<void> showCameraPermissionDeniedDialog(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    AppLogger.i('📱 Kamera izni red dialog\'u gösteriliyor');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('camera_permission_needed_title'.locale(context)),
        content: Text('camera_permission_needed_message'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              onRetry?.call();
            },
            child: Text('try_again'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Galeri izni reddedildiğinde gösterilecek dialog
  static Future<void> showGalleryPermissionDeniedDialog(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    AppLogger.i('📱 Galeri izni red dialog\'u gösteriliyor');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('gallery_permission_needed_title'.locale(context)),
        content: Text('gallery_permission_needed_message'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              onRetry?.call();
            },
            child: Text('try_again'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Kamera izni kalıcı olarak reddedildiğinde gösterilecek dialog
  static Future<void> showCameraPermissionSettingsDialog(
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    AppLogger.i('⚙️ Kamera izni ayarlar dialog\'u gösteriliyor');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('camera_permission_required_title'.locale(context)),
        content: Text('camera_permission_settings_message'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService().openApplicationSettings();
            },
            child: Text('open_settings'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Galeri izni kalıcı olarak reddedildiğinde gösterilecek dialog
  static Future<void> showGalleryPermissionSettingsDialog(
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    AppLogger.i('⚙️ Galeri izni ayarlar dialog\'u gösteriliyor');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('gallery_permission_required_title'.locale(context)),
        content: Text('gallery_permission_settings_message'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService().openApplicationSettings();
            },
            child: Text('open_settings'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Hem kamera hem galeri izni kalıcı olarak reddedildiğinde gösterilecek dialog
  static Future<void> showBothPermissionsSettingsDialog(
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    AppLogger.i('⚙️ Tüm medya izinleri ayarlar dialog\'u gösteriliyor');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('permissions_required_title'.locale(context)),
        content:
            Text('camera_photos_permission_required_message'.locale(context)),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService().openApplicationSettings();
            },
            child: Text('open_settings'.locale(context)),
          ),
        ],
      ),
    );
  }

  /// Genel izin hatası için gösterilecek dialog
  static Future<void> showPermissionErrorDialog(
    BuildContext context,
    String errorMessage,
  ) async {
    if (!context.mounted) return;

    AppLogger.w('⚠️ İzin hatası dialog\'u gösteriliyor: $errorMessage');

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('permission_required'.locale(context)),
        content: Text(errorMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('ok'.locale(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Photo source seçim dialog'u
  static Future<PhotoSourceChoice?> showPhotoSourceDialog(
    BuildContext context,
  ) async {
    if (!context.mounted) return null;

    AppLogger.i('📸 Fotoğraf kaynak seçim dialog\'u gösteriliyor');

    return await showCupertinoModalPopup<PhotoSourceChoice>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('photo_source_description'.locale(context)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, PhotoSourceChoice.camera),
            child: Text('camera'.locale(context)),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, PhotoSourceChoice.gallery),
            child: Text('gallery'.locale(context)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Generic permission result handling
  ///
  /// İzin sonucuna göre uygun dialog'ları otomatik gösterir
  static Future<void> handlePermissionResult({
    required BuildContext context,
    required PermissionRequestResult result,
    required Permission permission,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    switch (result) {
      case PermissionRequestResult.granted:
        // İzin verildi, bir şey yapmaya gerek yok
        AppLogger.i('✅ İzin verildi: ${permission.toString()}');
        break;

      case PermissionRequestResult.denied:
        if (permission == Permission.camera) {
          await showCameraPermissionDeniedDialog(context, onRetry: onRetry);
        } else if (permission == Permission.photos) {
          await showGalleryPermissionDeniedDialog(context, onRetry: onRetry);
        }
        break;

      case PermissionRequestResult.permanentlyDenied:
        if (permission == Permission.camera) {
          await showCameraPermissionSettingsDialog(context);
        } else if (permission == Permission.photos) {
          await showGalleryPermissionSettingsDialog(context);
        }
        break;

      case PermissionRequestResult.error:
        if (permission == Permission.camera) {
          await showPermissionErrorDialog(
            context,
            'camera_permission_error'.locale(context),
          );
        } else if (permission == Permission.photos) {
          await showPermissionErrorDialog(
            context,
            'gallery_permission_error'.locale(context),
          );
        }
        break;

      case PermissionRequestResult.restricted:
        await showPermissionErrorDialog(
          context,
          'permission_restricted_error'.locale(context),
        );
        break;
    }
  }
}

/// Fotoğraf kaynak seçim enum'u
enum PhotoSourceChoice {
  camera,
  gallery,
}
