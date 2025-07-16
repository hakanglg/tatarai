import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/services/permission_service.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Simple media selection handler with native permission flow
class MediaPermissionHandler {
  MediaPermissionHandler._();
  static final MediaPermissionHandler _instance = MediaPermissionHandler._();
  static MediaPermissionHandler get instance => _instance;

  final ImagePicker _imagePicker = ImagePicker();
  final PermissionService _permissionService = PermissionService();

  /// Show photo source selection and handle the entire flow
  Future<XFile?> selectMedia(BuildContext context) async {
    if (!context.mounted) return null;

    AppLogger.i('📸 Starting media selection');

    try {
      // Show source selection dialog
      final source = await _showSourceDialog(context);
      if (source == null || !context.mounted) {
        AppLogger.i('User cancelled source selection');
        return null;
      }

      // Handle the selected source
      switch (source) {
        case ImageSource.camera:
          return await _handleCamera(context);
        case ImageSource.gallery:
          return await _handleGallery(context);
      }
    } catch (e) {
      AppLogger.e('❌ Media selection error', e);
      return null;
    }
  }

  /// Show source selection dialog
  Future<ImageSource?> _showSourceDialog(BuildContext context) async {
    return await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('photo_source_description'.locale(context)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: Text('camera'.locale(context)),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
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

  /// Handle camera selection with native permission flow
  Future<XFile?> _handleCamera(BuildContext context) async {
    AppLogger.i('📷 Handling camera selection');

    try {
      AppLogger.i('📷 Camera: Starting ImagePicker.pickImage with camera source');
      
      // Directly try to capture - ImagePicker will trigger native permission
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      AppLogger.i('📷 Camera: ImagePicker returned: ${image?.path ?? 'null'}');

      if (image != null) {
        AppLogger.i('✅ Camera capture successful: ${image.path}');
        AppLogger.i('📷 Camera: Image size: ${await image.length()} bytes');
        AppLogger.i('📷 Camera: File exists: ${File(image.path).existsSync()}');
        AppLogger.i('📷 Camera: Returning XFile to caller');
        return image;
      } else {
        AppLogger.i('❌ Camera: ImagePicker returned null - user cancelled or permission denied');
        // Check if it was permission denial and redirect to settings
        if (context.mounted) {
          await _handlePermissionDenied(context, 'camera');
        }
        return null;
      }
    } catch (e) {
      AppLogger.e('❌ Camera capture failed with exception', e);
      // Handle permission error - redirect to settings
      if (context.mounted) {
        await _handlePermissionDenied(context, 'camera');
      }
      return null;
    }
  }

  /// Handle gallery selection with native permission flow
  Future<XFile?> _handleGallery(BuildContext context) async {
    AppLogger.i('📸 Handling gallery selection');

    try {
      // Directly try to select - ImagePicker will trigger native permission
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        AppLogger.i('✅ Gallery selection successful: ${image.path}');
        AppLogger.i('📸 Gallery: Image size: ${await image.length()} bytes');
        return image;
      } else {
        AppLogger.i('User cancelled gallery selection or permission denied');
        // Check if it was permission denial and redirect to settings
        if (context.mounted) {
          await _handlePermissionDenied(context, 'gallery');
        }
        return null;
      }
    } catch (e) {
      AppLogger.e('❌ Gallery selection failed', e);
      // Handle permission error - redirect to settings
      if (context.mounted) {
        await _handlePermissionDenied(context, 'gallery');
      }
      return null;
    }
  }

  /// Handle permission denied case - only open settings if actually denied
  Future<void> _handlePermissionDenied(BuildContext context, String type) async {
    if (!context.mounted) return;

    try {
      bool isPermanentlyDenied = false;
      
      if (type == 'camera') {
        isPermanentlyDenied = await _permissionService.isCameraPermissionPermanentlyDenied();
      } else {
        isPermanentlyDenied = await _permissionService.isPhotosPermissionPermanentlyDenied();
      }

      // Only open settings if permission is permanently denied
      if (isPermanentlyDenied) {
        AppLogger.i('🔧 Permission permanently denied, opening settings');
        await _permissionService.openSettings();
      }
    } catch (e) {
      AppLogger.e('❌ Permission check failed', e);
    }
  }
}