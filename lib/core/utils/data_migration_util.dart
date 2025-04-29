import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Eski 'tatar' veritabanından yeni 'tatarai' veritabanına veri taşımak için yardımcı sınıf
class DataMigrationUtil {
  /// Veritabanları arasında veri taşıma işlemlerini gerçekleştirir
  static Future<int> migrateAnalysesData() async {
    AppLogger.i('Veri taşıma işlemi başlatılıyor...');

    try {
      // Eski veritabanına erişim
      final oldFirestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'tatar',
      );

      // Yeni veritabanına erişim
      final newFirestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'tatarai',
      );

      // Eski veritabanından verileri çek
      final oldCollectionSnapshot =
          await oldFirestore.collection('analyses').get();

      if (oldCollectionSnapshot.docs.isEmpty) {
        AppLogger.i('Eski veritabanında analiz verisi bulunamadı');
        return 0;
      }

      int migratedCount = 0;

      // Eski verileri yeni veritabanına taşı
      for (var doc in oldCollectionSnapshot.docs) {
        final data = doc.data();

        // Yeni veritabanına yaz
        try {
          await newFirestore.collection('analyses').doc(doc.id).set(data);

          migratedCount++;
          AppLogger.i('Taşınan veri: ${doc.id}');
        } catch (e) {
          AppLogger.e('Veri taşıma hatası (${doc.id})', e);
        }
      }

      AppLogger.i(
          'Veri taşıma tamamlandı. Toplam taşınan veri: $migratedCount');
      return migratedCount;
    } catch (e) {
      AppLogger.e('Veri taşıma genel hatası', e);
      return 0;
    }
  }
}
