import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Firebase bağlantılarını ve işlemlerini test etmek için yardımcı sınıf
class FirebaseTestUtils {
  /// Tüm Firebase bağlantılarını test eder ve detaylı sonuç döndürür
  static Future<Map<String, dynamic>> testAllFirebaseConnections() async {
    final result = <String, dynamic>{
      'success': false,
      'firebase_core': false,
      'firebase_auth': false,
      'firestore_default': false,
      'firestore_tatarai': false,
      'errors': <String, String>{},
    };

    try {
      AppLogger.i('Firebase Core durumu kontrol ediliyor...');
      final FirebaseApp app = Firebase.app();
      result['firebase_core'] = true;
      result['firebase_app_name'] = app.name;
      result['firebase_project_id'] = app.options.projectId;
      AppLogger.i('Firebase Core başarıyla başlatılmış: ${app.name}');

      // Firebase Auth testi
      try {
        AppLogger.i('Firebase Auth testi yapılıyor...');
        final auth = FirebaseAuth.instance;
        // Basit bir işlem dene
        await auth.tenantId; // Exception fırlatmıyorsa bağlantı var demektir
        result['firebase_auth'] = true;
        AppLogger.i('Firebase Auth bağlantısı başarılı');
      } catch (e) {
        AppLogger.e('Firebase Auth bağlantı hatası', e);
        result['errors']['auth'] = e.toString();
      }

      // Varsayılan Firestore bağlantı testi
      try {
        AppLogger.i('Varsayılan Firestore testi yapılıyor...');
        final firestore = FirebaseFirestore.instance;

        // Ayarları logla
        AppLogger.i('Firestore ayarları: ${firestore.settings}');

        // Test koleksiyonuna erişmeyi dene
        await firestore
            .collection('test')
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));

        result['firestore_default'] = true;
        AppLogger.i('Varsayılan Firestore bağlantısı başarılı');
      } catch (e) {
        AppLogger.e('Varsayılan Firestore bağlantı hatası', e);
        result['errors']['firestore_default'] = e.toString();
      }

      // 'tatarai' veritabanı bağlantı testi
      try {
        AppLogger.i("'tatarai' veritabanı testi yapılıyor...");
        final firestoreTatar = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'tatarai',
        );

        // Ayarları logla
        AppLogger.i(
            "'tatarai' veritabanı ayarları: ${firestoreTatar.settings}");

        // Test koleksiyonuna erişmeyi dene
        await firestoreTatar
            .collection('test')
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));

        result['firestore_tatarai'] = true;
        AppLogger.i("'tatarai' veritabanı bağlantısı başarılı");
      } catch (e) {
        AppLogger.e("'tatarai' veritabanı bağlantı hatası", e);
        result['errors']['firestore_tatarai'] = e.toString();
      }

      // Genel başarı durumu
      result['success'] = result['firebase_core'] &&
          (result['firestore_default'] || result['firestore_tatarai']);
    } catch (e) {
      AppLogger.e('Firebase genel bağlantı testi hatası', e);
      result['errors']['general'] = e.toString();
    }

    return result;
  }

  /// Belirli bir veritabanı ID'si ile Firestore bağlantısını test eder
  static Future<bool> testFirestoreConnection(String databaseId) async {
    try {
      AppLogger.i(
          'Firestore bağlantısı test ediliyor: "${databaseId.isEmpty ? 'varsayılan' : databaseId}"');

      final FirebaseFirestore firestore = databaseId.isEmpty
          ? FirebaseFirestore.instance
          : FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: databaseId,
            );

      // Test koleksiyonuna erişmeyi dene
      await firestore
          .collection('test')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));

      AppLogger.i(
          'Firestore bağlantısı başarılı: "${databaseId.isEmpty ? 'varsayılan' : databaseId}"');
      return true;
    } catch (e) {
      AppLogger.e(
          'Firestore bağlantı hatası: "${databaseId.isEmpty ? 'varsayılan' : databaseId}"',
          e);
      return false;
    }
  }

  /// Firestore'a test verisi yazar ve okur
  static Future<Map<String, dynamic>> testFirestoreReadWrite() async {
    // Sonuçları tutacak map
    Map<String, dynamic> result = {
      'allSuccess': false,
      'writeSuccess': false,
      'readSuccess': false,
      'updateSuccess': false,
      'deleteSuccess': false,
      'error': '',
    };

    try {
      AppLogger.i('Firestore okuma/yazma testi başlatılıyor...');
      final firestore = FirebaseManager().firestore;
      final testCollection = firestore.collection('test_collection');
      final testDocId = 'test_doc_${DateTime.now().millisecondsSinceEpoch}';

      // Test verisini oluştur
      final testData = {
        'test_field': 'test_value',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 1. Veri yazma testi
      try {
        await testCollection.doc(testDocId).set(testData);
        AppLogger.i('Firestore yazma testi başarılı');
        result['writeSuccess'] = true;
      } catch (e) {
        AppLogger.e('Firestore yazma testi başarısız', e);
        result['writeSuccess'] = false;
        result['error'] = e.toString();
        return result; // Yazma başarısız olursa diğer testleri yapma
      }

      // 2. Veri okuma testi
      try {
        final docSnapshot = await testCollection.doc(testDocId).get();
        if (docSnapshot.exists &&
            docSnapshot.data()?['test_field'] == 'test_value') {
          AppLogger.i('Firestore okuma testi başarılı');
          result['readSuccess'] = true;
        } else {
          AppLogger.w(
              'Firestore okuma testi başarısız: Veri bulunamadı veya eşleşmiyor');
          result['readSuccess'] = false;
        }
      } catch (e) {
        AppLogger.e('Firestore okuma testi başarısız', e);
        result['readSuccess'] = false;
        result['error'] = e.toString();
      }

      // 3. Veri güncelleme testi
      try {
        await testCollection
            .doc(testDocId)
            .update({'test_field': 'updated_value'});

        // Güncellemeyi doğrula
        final updatedDoc = await testCollection.doc(testDocId).get();
        if (updatedDoc.exists &&
            updatedDoc.data()?['test_field'] == 'updated_value') {
          AppLogger.i('Firestore güncelleme testi başarılı');
          result['updateSuccess'] = true;
        } else {
          AppLogger.w('Firestore güncelleme doğrulama başarısız');
          result['updateSuccess'] = false;
        }
      } catch (e) {
        AppLogger.e('Firestore güncelleme testi başarısız', e);
        result['updateSuccess'] = false;
        result['error'] = e.toString();
      }

      // 4. Veri silme testi
      try {
        await testCollection.doc(testDocId).delete();

        // Silmeyi doğrula
        final deletedDoc = await testCollection.doc(testDocId).get();
        if (!deletedDoc.exists) {
          AppLogger.i('Firestore silme testi başarılı');
          result['deleteSuccess'] = true;
        } else {
          AppLogger.w('Firestore silme doğrulama başarısız');
          result['deleteSuccess'] = false;
        }
      } catch (e) {
        AppLogger.e('Firestore silme testi başarısız', e);
        result['deleteSuccess'] = false;
        result['error'] = e.toString();
      }

      // Tüm testler başarılı mı?
      bool writeOk = result['writeSuccess'] as bool;
      bool readOk = result['readSuccess'] as bool;
      bool updateOk = result['updateSuccess'] as bool;
      bool deleteOk = result['deleteSuccess'] as bool;

      result['allSuccess'] = writeOk && readOk && updateOk && deleteOk;

      AppLogger.i(
          'Firestore okuma/yazma testi ${result['allSuccess'] ? 'başarılı' : 'başarısız'}');
      return result;
    } catch (e) {
      AppLogger.e('Firestore okuma/yazma testi sırasında beklenmeyen hata', e);
      result['error'] = e.toString();
      return result;
    }
  }

  /// FirebaseManager sınıfını baştan başlatır ve bağlantı durumunu test eder
  static Future<bool> reinitializeFirebaseManager() async {
    try {
      AppLogger.i('FirebaseManager yeniden başlatılıyor...');

      // Mevcut FirebaseManager nesnesini al
      final firebaseManager = FirebaseManager();

      // Önce sıfırla (varsa)
      if (firebaseManager.isInitialized) {
        await firebaseManager.reset();
      }

      // Yeniden başlat
      await firebaseManager.initialize();

      // Başarılı mı?
      final isConnected = firebaseManager.isConnected;
      AppLogger.i(
          'FirebaseManager yeniden başlatma ${isConnected ? 'başarılı' : 'başarısız'}');
      return isConnected;
    } catch (e) {
      AppLogger.e('FirebaseManager yeniden başlatma hatası', e);
      return false;
    }
  }
}
