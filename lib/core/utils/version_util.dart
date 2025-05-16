// lib/core/utils/version_util.dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tatarai/core/utils/semantic_version.dart';

class VersionUtil {
  /// Uygulamanın kurulu sürümünü SemanticVersion olarak döner
  static Future<SemanticVersion> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return SemanticVersion.fromString(info.version);
  }

  /// [current] < [minRequired] ise zorunlu güncelleme gerekli
  static bool isForceUpdateRequired({
    required SemanticVersion current,
    required SemanticVersion minRequired,
  }) {
    return current.compareTo(minRequired) < 0;
  }

  /// [current] < [latest] ise opsiyonel güncelleme gösterilebilir
  static bool isOptionalUpdateAvailable({
    required SemanticVersion current,
    required SemanticVersion latest,
  }) {
    var result = current.compareTo(latest) < 0;
    return result;
  }
}
