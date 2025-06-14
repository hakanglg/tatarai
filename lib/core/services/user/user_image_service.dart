import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class UserImageService {
  final FirebaseStorage storage;

  UserImageService(this.storage);

  /// Profil fotoğrafını sıkıştırarak Firebase Storage’a yükler ve URL döner
  Future<String?> uploadProfilePhoto(File image, String userId) async {
    final compressedImage = await _compressImage(image);
    final fileName =
        'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';

    final ref = storage.ref().child('profile_images/$fileName');
    final uploadTask = await ref.putFile(compressedImage);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Fotoğrafı sıkıştırır (kalite %80, max boyut 1024px)
  Future<File> _compressImage(File file) async {
    final targetPath = '${file.parent.path}/temp_${path.basename(file.path)}';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 512,
      minHeight: 512,
    );
    if (result == null) return file;
    return File(result.path);
  }
}
