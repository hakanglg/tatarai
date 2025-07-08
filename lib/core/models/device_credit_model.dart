import 'package:equatable/equatable.dart';

/// Cihaz kredi takip modeli
///
/// Her cihaz için kredi durumunu takip eder.
/// Kullanıcı hesabından bağımsız olarak cihaz bazlı kredi kontrolü sağlar.
class DeviceCreditModel extends Equatable {
  /// Cihazın benzersiz fingerprint'i
  final String deviceId;

  /// Bu cihazda daha önce kredi verildi mi?
  final bool hasCreditBeenGranted;

  /// İlk kredi verilme tarihi
  final DateTime? firstCreditDate;

  /// Son güncelleme tarihi
  final DateTime updatedAt;

  /// Son kredi verilen kullanıcı ID'si (opsiyonel, debug için)
  final String? lastUserId;

  /// Toplam kaç kez bu cihazda hesap açılmaya çalışıldı
  final int attemptCount;

  /// Son kaydedilen kredi sayısı (hesap silme öncesi)
  final int lastKnownCredits;

  /// Constructor
  const DeviceCreditModel({
    required this.deviceId,
    required this.hasCreditBeenGranted,
    this.firstCreditDate,
    required this.updatedAt,
    this.lastUserId,
    this.attemptCount = 1,
    this.lastKnownCredits = 5, // Default olarak 5 kredi
  });

  /// İlk kez kredi verilen cihaz için factory
  factory DeviceCreditModel.firstTime({
    required String deviceId,
    required String userId,
  }) {
    final now = DateTime.now();
    return DeviceCreditModel(
      deviceId: deviceId,
      hasCreditBeenGranted: true,
      firstCreditDate: now,
      updatedAt: now,
      lastUserId: userId,
      attemptCount: 1,
    );
  }

  /// Sonraki girişler için factory (kredi restore edilir)
  factory DeviceCreditModel.subsequent({
    required String deviceId,
    required String userId,
    required DeviceCreditModel existing,
    int? newCredits, // Yeni kredi sayısı (opsiyonel)
  }) {
    return existing.copyWith(
      lastUserId: userId,
      updatedAt: DateTime.now(),
      attemptCount: existing.attemptCount + 1,
      lastKnownCredits: newCredits ?? existing.lastKnownCredits,
    );
  }

  /// JSON'dan DeviceCreditModel oluşturur
  factory DeviceCreditModel.fromJson(Map<String, dynamic> json) {
    return DeviceCreditModel(
      deviceId: json['deviceId'] as String,
      hasCreditBeenGranted: json['hasCreditBeenGranted'] as bool? ?? false,
      firstCreditDate: _parseDateTime(json['firstCreditDate']),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      lastUserId: json['lastUserId'] as String?,
      attemptCount: json['attemptCount'] as int? ?? 1,
      lastKnownCredits: json['lastKnownCredits'] as int? ?? 5,
    );
  }

  /// DeviceCreditModel'i JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'hasCreditBeenGranted': hasCreditBeenGranted,
      'firstCreditDate': firstCreditDate?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUserId': lastUserId,
      'attemptCount': attemptCount,
      'lastKnownCredits': lastKnownCredits,
    };
  }

  /// DateTime parsing helper
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// DeviceCreditModel kopyalama metodu
  DeviceCreditModel copyWith({
    String? deviceId,
    bool? hasCreditBeenGranted,
    DateTime? firstCreditDate,
    DateTime? updatedAt,
    String? lastUserId,
    int? attemptCount,
    int? lastKnownCredits,
  }) {
    return DeviceCreditModel(
      deviceId: deviceId ?? this.deviceId,
      hasCreditBeenGranted: hasCreditBeenGranted ?? this.hasCreditBeenGranted,
      firstCreditDate: firstCreditDate ?? this.firstCreditDate,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUserId: lastUserId ?? this.lastUserId,
      attemptCount: attemptCount ?? this.attemptCount,
      lastKnownCredits: lastKnownCredits ?? this.lastKnownCredits,
    );
  }

  /// Equatable props
  @override
  List<Object?> get props => [
        deviceId,
        hasCreditBeenGranted,
        firstCreditDate,
        updatedAt,
        lastUserId,
        attemptCount,
        lastKnownCredits,
      ];

  /// Debug için string representation
  @override
  String toString() {
    return 'DeviceCreditModel{deviceId: ${deviceId.substring(0, 8)}..., '
        'hasCreditBeenGranted: $hasCreditBeenGranted, '
        'attemptCount: $attemptCount, '
        'lastKnownCredits: $lastKnownCredits}';
  }

  /// Bu cihaza yeni kullanıcı için kredi verilmeli mi?
  bool get shouldGrantCredit => !hasCreditBeenGranted;

  /// Cihazın kullanım geçmişi var mı?
  bool get hasHistory => firstCreditDate != null;
}