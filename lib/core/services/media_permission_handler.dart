import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tatarai/core/services/permission_service.dart';
import 'package:tatarai/core/widgets/permission_dialog_manager.dart';
import 'package:tatarai/core/utils/logger.dart';

/// 📸 Medya izin ve seçim işlemlerini merkezi yöneten servis
///
/// Kamera ve galeri işlemlerini tek yerden yönetir.
/// Permission handling, dialog gösterme ve image picking işlemlerini
/// koordine eder.
class MediaPermissionHandler {
  MediaPermissionHandler._();

  static final MediaPermissionHandler _instance = MediaPermissionHandler._();
  static MediaPermissionHandler get instance => _instance;

  final ImagePicker _imagePicker = ImagePicker();

  /// Ana medya seçim metodu
  ///
  /// Kullanıcıya kaynak seçim dialog'u gösterir ve seçilen kaynağa göre
  /// izin kontrolü yaparak resim seçer. İzinler on-demand olarak istenir.
  Future<XFile?> selectMedia(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('📸 Medya seçim işlemi başlatılıyor');

    try {
      // Direkt kaynak seçim dialog'unu göster
      final choice =
          await PermissionDialogManager.showPhotoSourceDialog(context);

      if (choice == null || !context.mounted) {
        AppLogger.i('Kullanıcı fotoğraf kaynağı seçimini iptal etti');
        return null;
      }

      // Seçilen kaynağa göre izin kontrol et ve işlem yap
      switch (choice) {
        case PhotoSourceChoice.camera:
          return await _handleCameraSelection(context);
        case PhotoSourceChoice.gallery:
          return await _handleGallerySelection(context);
      }
    } catch (e) {
      AppLogger.e('Medya seçim hatası', e);
      if (context.mounted) {
        await PermissionDialogManager.showPermissionErrorDialog(
          context,
          'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
        );
      }
      return null;
    }
  }

  /// Kamera seçimi handling
  Future<XFile?> _handleCameraSelection(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('📷 Kamera izni kontrol ediliyor ve gerekirse isteniyor');

    // Kamera iznini kontrol et ve gerekirse iste
    final cameraResult =
        await PermissionService().requestCameraPermission(context: context);

    if (!context.mounted) return null;

    // İzin sonucunu handle et
    if (cameraResult != PermissionRequestResult.granted) {
      AppLogger.w('📷 Kamera izni alınamadı: $cameraResult');
      await PermissionDialogManager.handlePermissionResult(
        context: context,
        result: cameraResult,
        permission: Permission.camera,
        onRetry: () => _handleCameraSelection(context),
      );
      return null;
    }

    // İzin alındı, kamera ile fotoğraf çek
    AppLogger.i('📷 Kamera izni verildi, fotoğraf çekiliyor');
    return await _pickImageFromCamera();
  }

  /// Galeri seçimi handling
  Future<XFile?> _handleGallerySelection(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('📸 Galeri izni kontrol ediliyor ve gerekirse isteniyor');

    // Galeri iznini kontrol et ve gerekirse iste
    final photosResult =
        await PermissionService().requestPhotosPermission(context: context);

    if (!context.mounted) return null;

    // İzin sonucunu handle et
    if (photosResult != PermissionRequestResult.granted) {
      AppLogger.w('📸 Galeri izni alınamadı: $photosResult');
      await PermissionDialogManager.handlePermissionResult(
        context: context,
        result: photosResult,
        permission: Permission.photos,
        onRetry: () => _handleGallerySelection(context),
      );
      return null;
    }

    // İzin alındı, galeriden fotoğraf seç
    AppLogger.i('📸 Galeri izni verildi, fotoğraf seçiliyor');
    return await _pickImageFromGallery();
  }

  /// Kameradan fotoğraf çekme
  Future<XFile?> _pickImageFromCamera() async {
    try {
      AppLogger.i('📷 Kameradan fotoğraf çekiliyor');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        AppLogger.i('✅ Kameradan fotoğraf başarıyla alındı: ${image.path}');

        // Dosya boyutunu kontrol et
        final fileSize = await _getFileSize(image.path);
        if (fileSize > 10 * 1024 * 1024) {
          // 10MB
          AppLogger.w('⚠️ Dosya boyutu çok büyük: ${fileSize}B');
          return null;
        }
      } else {
        AppLogger.i('ℹ️ Kullanıcı kamera işlemini iptal etti');
      }

      return image;
    } catch (e) {
      AppLogger.e('❌ Kameradan fotoğraf çekme hatası', e);
      return null;
    }
  }

  /// Galeriden fotoğraf seçme
  Future<XFile?> _pickImageFromGallery() async {
    try {
      AppLogger.i('🖼️ Galeriden fotoğraf seçiliyor');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        AppLogger.i('✅ Galeriden fotoğraf başarıyla alındı: ${image.path}');

        // Dosya boyutunu kontrol et
        final fileSize = await _getFileSize(image.path);
        if (fileSize > 10 * 1024 * 1024) {
          // 10MB
          AppLogger.w('⚠️ Dosya boyutu çok büyük: ${fileSize}B');
          return null;
        }
      } else {
        AppLogger.i('ℹ️ Kullanıcı galeri seçimini iptal etti');
      }

      return image;
    } catch (e) {
      AppLogger.e('❌ Galeriden fotoğraf seçme hatası', e);
      return null;
    }
  }

  /// Hızlı kamera erişimi (permission check olmadan)
  ///
  /// Bu metot sadece izin zaten verilmişse kullanılmalı.
  /// Izin kontrolü yapmaz, sadece kamerayı açar.
  Future<XFile?> quickCameraCapture() async {
    AppLogger.i('⚡ Hızlı kamera çekimi');
    return await _pickImageFromCamera();
  }

  /// Hızlı galeri erişimi (permission check olmadan)
  ///
  /// Bu metot sadece izin zaten verilmişse kullanılmalı.
  /// Izin kontrolü yapmaz, sadece galeriyi açar.
  Future<XFile?> quickGalleryPick() async {
    AppLogger.i('⚡ Hızlı galeri seçimi');
    return await _pickImageFromGallery();
  }

  /// Sadece kamera ile fotoğraf çek (dialog olmadan)
  ///
  /// İzin kontrolü yapar, gerekirse dialog gösterir.
  /// Galeri seçeneği sunmaz.
  Future<XFile?> captureFromCameraOnly(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('📷 Sadece kamera ile çekim');
    return await _handleCameraSelection(context);
  }

  /// Sadece galeriden seç (dialog olmadan)
  ///
  /// İzin kontrolü yapar, gerekirse dialog gösterir.
  /// Kamera seçeneği sunmaz.
  Future<XFile?> pickFromGalleryOnly(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('🖼️ Sadece galeriden seçim');
    return await _handleGallerySelection(context);
  }

  /// Dosya boyutunu byte cinsinden döndürür
  Future<int> _getFileSize(String filePath) async {
    try {
      final file = XFile(filePath);
      final length = await file.length();
      return length;
    } catch (e) {
      AppLogger.e('Dosya boyutu alınamadı', e);
      return 0;
    }
  }

  /// Permission durumlarını kontrol et ve debug için log'la
  Future<void> debugPermissionStatus() async {
    final cameraStatus =
        PermissionService().getCachedPermissionStatus(Permission.camera);
    final photosStatus =
        PermissionService().getCachedPermissionStatus(Permission.photos);

    AppLogger.i('🔍 Debug - Kamera izni: $cameraStatus');
    AppLogger.i('🔍 Debug - Galeri izni: $photosStatus');
  }
}
