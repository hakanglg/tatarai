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

  /// Varsayılan güncelleme yapılandırması
  static UpdateConfig defaultConfig() {
    return UpdateConfig(
      latestVersion: '1.0.0',
      minVersion: '1.0.0',
      storeUrl: 'https://apps.apple.com/app/id1234567890',
      forceUpdateMessage:
          'Yeni bir güncelleme mevcut. Uygulamayı kullanmaya devam etmek için lütfen güncelleyin.',
      optionalUpdateMessage:
          'Yeni bir güncelleme mevcut. Güncellemek ister misiniz?',
    );
  }
}
