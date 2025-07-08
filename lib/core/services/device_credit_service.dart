import '../models/device_credit_model.dart';
import '../utils/logger.dart';
import 'firestore/firestore_service_interface.dart';
import 'device_identification_service.dart';

/// Cihaz bazlı kredi yönetim servisi
///
/// Bu servis cihaz fingerprint'leri ile kredi durumunu takip eder.
/// Kullanıcı hesaplarından bağımsız olarak çalışır ve hesap silinse bile
/// cihaz bilgisini korur.
///
/// Özellikler:
/// - Cihaz bazlı kredi takibi
/// - Kullanıcı hesabından bağımsız çalışma
/// - Kalıcı veri saklama (hesap silme sonrası da kalır)
/// - Abuse prevention (kötüye kullanım önleme)
class DeviceCreditService {
  /// Firestore service instance
  final FirestoreServiceInterface _firestoreService;

  /// Device identification service instance
  final DeviceIdentificationService _deviceService;

  /// Device credits koleksiyon adı
  static const String _deviceCreditsCollection = 'device_credits';

  /// Service adı (logging için)
  static const String _serviceName = 'DeviceCreditService';

  /// Constructor
  DeviceCreditService({
    required FirestoreServiceInterface firestoreService,
    required DeviceIdentificationService deviceService,
  })  : _firestoreService = firestoreService,
        _deviceService = deviceService;

  /// Bu cihaz için uygun kredi sayısını hesaplar
  ///
  /// Returns:
  /// - İlk kez kullanım: 5 kredi
  /// - Daha önce kullanılmış: Son kaydedilen kredi sayısı
  Future<int> getCreditsForNewUser(String userId) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          'Yeni kullanıcı için kredi kontrolü', userId);

      // Device fingerprint'i al
      final String deviceId = await _deviceService.getDeviceFingerprint();
      
      // Bu cihaz için kredi kaydı var mı kontrol et
      final DeviceCreditModel? existingRecord = 
          await _getDeviceCreditRecord(deviceId);

      if (existingRecord == null) {
        AppLogger.logWithContext(_serviceName, 
            '🆕 İlk kez kullanım tespit edildi - 5 kredi verilecek', 
            '${deviceId.substring(0, 8)} -> $userId');

        // İlk kez kullanım - 5 kredi ver
        await _createDeviceCreditRecord(deviceId, userId, 5);
        
        AppLogger.successWithContext(_serviceName, 
            '✅ İlk kez kullanım - 5 kredi verildi ve Firestore\'a kaydedildi', 
            '${deviceId.substring(0, 8)} -> $userId');
        
        return 5;
      } else {
        // Daha önce kullanılmış - son kredi sayısını restore et
        final restoredCredits = existingRecord.lastKnownCredits;
        await _updateDeviceCreditRecord(existingRecord, userId, restoredCredits);
        
        AppLogger.logWithContext(_serviceName, 
            'Cihaz kredi geçmişi restore edildi', 
            '${deviceId.substring(0, 8)} -> $userId (Kredi: $restoredCredits, Deneme: ${existingRecord.attemptCount + 1})');
        
        return restoredCredits;
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Kredi kontrol hatası', e, stackTrace);
      
      // Hata durumunda güvenli tarafta kal - 0 kredi ver
      return 0;
    }
  }

  /// Cihaz kredi kaydını alır
  Future<DeviceCreditModel?> _getDeviceCreditRecord(String deviceId) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          'Cihaz kredi kaydı sorgulanıyor', deviceId.substring(0, 8));

      final record = await _firestoreService.getDocument<DeviceCreditModel>(
        collection: _deviceCreditsCollection,
        documentId: deviceId, // Device ID'yi document ID olarak kullan
        fromJson: DeviceCreditModel.fromJson,
      );

      if (record != null) {
        AppLogger.logWithContext(_serviceName, 
            'Cihaz kredi kaydı bulundu', 
            '${deviceId.substring(0, 8)} - Kredi verilmiş: ${record.hasCreditBeenGranted}');
      } else {
        AppLogger.logWithContext(_serviceName, 
            'Cihaz kredi kaydı bulunamadı - yeni cihaz', deviceId.substring(0, 8));
      }

      return record;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Cihaz kredi kaydı alma hatası', e, stackTrace);
      return null;
    }
  }

  /// Yeni cihaz kredi kaydı oluşturur
  Future<void> _createDeviceCreditRecord(
    String deviceId, 
    String userId, 
    int initialCredits,
  ) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          '📝 Firestore\'a yeni cihaz kaydı yazılıyor', 
          'Collection: $_deviceCreditsCollection, DocID: ${deviceId.substring(0, 8)}..., User: $userId');

      final record = DeviceCreditModel(
        deviceId: deviceId,
        hasCreditBeenGranted: true,
        firstCreditDate: DateTime.now(),
        updatedAt: DateTime.now(),
        lastUserId: userId,
        attemptCount: 1,
        lastKnownCredits: initialCredits,
      );

      final recordJson = record.toJson();
      AppLogger.logWithContext(_serviceName, 
          '📊 Yazılacak data hazırlandı', 
          'Keys: ${recordJson.keys.join(", ")}');

      await _firestoreService.setDocument(
        collection: _deviceCreditsCollection,
        documentId: deviceId, // Device ID'yi document ID olarak kullan
        data: recordJson,
        merge: false, // Yeni kayıt, merge etme
      );

      AppLogger.successWithContext(_serviceName, 
          '✅ Firestore\'a cihaz kredi kaydı başarıyla yazıldı', 
          'Collection: $_deviceCreditsCollection/${deviceId.substring(0, 8)}...');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          '❌ Firestore cihaz kredi kaydı yazma hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Mevcut cihaz kredi kaydını günceller
  Future<void> _updateDeviceCreditRecord(
    DeviceCreditModel existing,
    String userId,
    int newCredits,
  ) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          'Cihaz kredi kaydı güncelleniyor', 
          '${existing.deviceId.substring(0, 8)} -> $userId');

      final updated = DeviceCreditModel.subsequent(
        deviceId: existing.deviceId,
        userId: userId,
        existing: existing,
        newCredits: newCredits,
      );

      await _firestoreService.setDocument(
        collection: _deviceCreditsCollection,
        documentId: existing.deviceId,
        data: updated.toJson(),
        merge: true,
      );

      AppLogger.successWithContext(_serviceName, 
          'Cihaz kredi kaydı güncellendi', 
          '${existing.deviceId.substring(0, 8)} - Deneme: ${updated.attemptCount}');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Cihaz kredi kaydı güncelleme hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Bu cihazın kredi geçmişini getirir (admin/debug için)
  Future<DeviceCreditModel?> getDeviceCreditHistory() async {
    try {
      final String deviceId = await _deviceService.getDeviceFingerprint();
      return await _getDeviceCreditRecord(deviceId);
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Cihaz kredi geçmişi alma hatası', e, stackTrace);
      return null;
    }
  }

  /// Kullanıcının kredisini cihaz kaydında günceller
  /// 
  /// Bu metot hesap silme öncesi çağrılarak son kredi sayısı kaydedilir
  Future<void> updateUserCredits(String userId, int currentCredits) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          'Kullanıcı kredisi cihaz kaydında güncelleniyor', 
          '$userId -> $currentCredits kredi');

      // Device fingerprint'i al
      final String deviceId = await _deviceService.getDeviceFingerprint();
      
      // Mevcut cihaz kaydını bul
      final DeviceCreditModel? existingRecord = 
          await _getDeviceCreditRecord(deviceId);

      if (existingRecord != null) {
        // Kredi sayısını güncelle
        await _updateDeviceCreditRecord(existingRecord, userId, currentCredits);
        
        AppLogger.successWithContext(_serviceName, 
            'Cihaz kaydında kredi güncellendi', 
            '${deviceId.substring(0, 8)} -> $currentCredits kredi');
      } else {
        AppLogger.warnWithContext(_serviceName, 
            'Cihaz kaydı bulunamadı - güncelleme yapılamadı', 
            '${deviceId.substring(0, 8)} -> $userId');
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Kullanıcı kredi güncelleme hatası', e, stackTrace);
      // Hata olsa da devam et - kritik değil
    }
  }

  /// Cihaz kredi verme durumunu sıfırlar (admin/debug için)
  /// 
  /// UYARI: Bu metot sadece test/debug amaçlı kullanılmalı!
  Future<void> resetDeviceCredit() async {
    try {
      final String deviceId = await _deviceService.getDeviceFingerprint();
      
      AppLogger.warnWithContext(_serviceName, 
          'Cihaz kredi durumu sıfırlanıyor', deviceId.substring(0, 8));

      await _firestoreService.deleteDocument(
        collection: _deviceCreditsCollection,
        documentId: deviceId,
      );

      AppLogger.successWithContext(_serviceName, 
          'Cihaz kredi durumu sıfırlandı', deviceId.substring(0, 8));
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Cihaz kredi sıfırlama hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Tüm cihaz kredi kayıtlarını sayar (admin için)
  Future<int> getTotalDeviceCount() async {
    try {
      AppLogger.logWithContext(_serviceName, 'Toplam cihaz sayısı sorgulanıyor');

      final count = await _firestoreService.getDocumentCount(
        collection: _deviceCreditsCollection,
      );

      AppLogger.logWithContext(_serviceName, 
          'Toplam kayıtlı cihaz sayısı', count.toString());

      return count;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Toplam cihaz sayısı alma hatası', e, stackTrace);
      return 0;
    }
  }

  /// Belirli bir tarih aralığındaki yeni cihaz sayısını getirir (admin için)
  Future<int> getNewDeviceCountInDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    try {
      AppLogger.logWithContext(_serviceName, 
          'Tarih aralığındaki yeni cihaz sayısı sorgulanıyor', 
          '${startDate.toIso8601String()} - ${endDate.toIso8601String()}');

      final devices = await _firestoreService.getDocumentsWithQuery<DeviceCreditModel>(
        collection: _deviceCreditsCollection,
        fromJson: DeviceCreditModel.fromJson,
        queryBuilder: (collection) => collection
            .where('firstCreditDate', isGreaterThanOrEqualTo: startDate.toIso8601String())
            .where('firstCreditDate', isLessThanOrEqualTo: endDate.toIso8601String()),
      );

      AppLogger.logWithContext(_serviceName, 
          'Tarih aralığındaki yeni cihaz sayısı', devices.length.toString());

      return devices.length;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(_serviceName, 
          'Tarih aralığındaki cihaz sayısı alma hatası', e, stackTrace);
      return 0;
    }
  }
}