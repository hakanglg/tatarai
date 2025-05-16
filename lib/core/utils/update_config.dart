/// Sürüm kontrolü sonucu
enum VersionStatus {
  /// Güncel sürüm kullanılıyor
  upToDate,

  /// Güncelleme mevcut ama zorunlu değil
  updateAvailable,

  /// Zorunlu güncelleme gerekiyor
  forceUpdateRequired,

  /// Hata oluştu
  error,
}

class UpdateConfig {
  final String latestVersion;
  final String minVersion;
  final String storeUrl;
  final String forceUpdateMessage;
  final String optionalUpdateMessage;

  UpdateConfig({
    required this.latestVersion,
    required this.minVersion,
    required this.storeUrl,
    required this.forceUpdateMessage,
    required this.optionalUpdateMessage,
  });
}
