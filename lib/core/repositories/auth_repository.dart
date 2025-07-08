import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import '../services/firestore/firestore_service_interface.dart';
import '../services/firestore/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/device_identification_service.dart';
import '../services/device_credit_service.dart';

/// Firebase Authentication ve Firestore entegrasyonu için repository
///
/// Bu sınıf authentication işlemlerini ve kullanıcı verilerinin
/// Firestore'da saklanmasını yönetir.
///
/// Özellikler:
/// - Firebase Auth entegrasyonu
/// - Firestore Service ile veri yönetimi
/// - Anonim authentication
/// - Hata yönetimi ve loglama
/// - Stream-based authentication state tracking
/// - Clean Architecture pattern
class AuthRepository {
  /// Firebase Auth instance
  final FirebaseAuth _firebaseAuth;

  /// Firestore service instance
  final FirestoreServiceInterface _firestoreService;

  /// Device credit service instance
  final DeviceCreditService _deviceCreditService;

  /// Kullanıcı koleksiyon adı
  static const String _usersCollection = 'users';

  /// Constructor
  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirestoreServiceInterface? firestoreService,
    DeviceIdentificationService? deviceService,
    DeviceCreditService? deviceCreditService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? _getFirestoreService(),
        _deviceCreditService = deviceCreditService ?? 
            DeviceCreditService(
              firestoreService: firestoreService ?? _getFirestoreService(),
              deviceService: deviceService ?? DeviceIdentificationService.instance,
            );

  /// ServiceLocator'dan FirestoreService'i al (lazy loading)
  static FirestoreServiceInterface _getFirestoreService() {
    try {
      // Önce ServiceLocator'dan almaya çalış
      return ServiceLocator.get<FirestoreServiceInterface>();
    } catch (e) {
      // ServiceLocator henüz hazır değilse manuel oluştur
      AppLogger.warnWithContext('AuthRepository',
          'ServiceLocator hazır değil, manuel FirestoreService oluşturuluyor');
      return FirestoreService();
    }
  }

  /// Şu anki kullanıcının stream'i
  Stream<User?> get userStream => _firebaseAuth.authStateChanges();

  /// Şu anki kullanıcı
  User? get currentUser => _firebaseAuth.currentUser;

  /// Kullanıcının giriş yapıp yapmadığını kontrol eder
  bool get isSignedIn => currentUser != null;

  /// Anonim giriş yapar
  ///
  /// Kullanıcıyı anonim olarak giriş yapar ve Firestore'da kaydeder.
  /// Cihaz bazlı kredi kontrolü yaparak ilk kez kullanılan cihazlara 5 kredi verir.
  /// Daha önce kullanılmış cihazlarda 0 kredi ile hesap açılır.
  Future<UserModel> signInAnonymously() async {
    try {
      AppLogger.logWithContext('AuthRepository', 'Anonim giriş başlatılıyor');

      // Firebase Auth durumunu kontrol et
      AppLogger.logWithContext('AuthRepository', 
          'Firebase Auth instance: ${_firebaseAuth.app.name}');
      AppLogger.logWithContext('AuthRepository', 
          'Current user before sign in: ${_firebaseAuth.currentUser?.uid ?? "null"}');

      // Firebase'de anonim giriş yap
      AppLogger.logWithContext('AuthRepository', 'signInAnonymously() çağrısı yapılıyor...');
      final UserCredential userCredential =
          await _firebaseAuth.signInAnonymously();
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Anonim giriş yapılamadı');
      }

      AppLogger.logWithContext(
          'AuthRepository', 'Firebase anonim giriş başarılı', firebaseUser.uid);

      // Cihaz bazlı kredi kontrolü yap ve uygun kredi sayısını al
      final int initialCredits = await _deviceCreditService
          .getCreditsForNewUser(firebaseUser.uid);
      
      UserModel newUser = UserModel.anonymous(
        id: firebaseUser.uid,
        name: 'Misafir Kullanıcı ${firebaseUser.uid.substring(0, 8)}',
      ).copyWith(analysisCredits: initialCredits);

      AppLogger.logWithContext('AuthRepository', 
          'Yeni kullanıcı oluşturuluyor', 
          '${firebaseUser.uid} - Kredi: $initialCredits');

      try {
        // Kullanıcının daha önce kaydedilip kaydedilmediğini kontrol et
        final UserModel? existingUser =
            await _getUserFromFirestore(firebaseUser.uid);

        if (existingUser != null) {
          // Mevcut kullanıcıyı güncelle ve döndür
          AppLogger.logWithContext('AuthRepository',
              'Mevcut anonim kullanıcı bulundu', firebaseUser.uid);

          newUser = existingUser.copyWith(
            updatedAt: DateTime.now(),
          );

          // Firestore'a güncellemeyi dene
          await _saveUserToFirestore(newUser);
          return newUser;
        }

        // Yeni kullanıcı - Firestore'a kaydetmeyi dene
        await _saveUserToFirestore(newUser);

        AppLogger.successWithContext(
            'AuthRepository',
            'Yeni anonim kullanıcı oluşturuldu ve Firestore\'a kaydedildi',
            firebaseUser.uid);
      } catch (firestoreError) {
        // Firestore hatası durumunda memory'deki user'ı döndür
        AppLogger.warnWithContext(
            'AuthRepository',
            'Firestore kaydetme hatası, memory user döndürülüyor',
            '${firebaseUser.uid}: $firestoreError');
      }

      return newUser;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 
          'Firebase Auth hatası: ${e.code} - ${e.message}', 
          e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 'Anonim giriş genel hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Çıkış yapar
  Future<void> signOut() async {
    try {
      AppLogger.logWithContext('AuthRepository', 'Çıkış işlemi başlatılıyor');
      await _firebaseAuth.signOut();
      AppLogger.successWithContext('AuthRepository', 'Çıkış işlemi başarılı');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 'Çıkış işlemi hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Kullanıcı verilerini günceller
  Future<UserModel> updateUser(UserModel updatedUser) async {
    try {
      AppLogger.logWithContext(
          'AuthRepository', 'Kullanıcı verisi güncelleniyor', updatedUser.id);

      final userWithUpdatedTime = updatedUser.copyWith(
        updatedAt: DateTime.now(),
      );

      await _saveUserToFirestore(userWithUpdatedTime);

      AppLogger.successWithContext(
          'AuthRepository', 'Kullanıcı verisi güncellendi', updatedUser.id);
      return userWithUpdatedTime;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext('AuthRepository',
          'Kullanıcı verisi güncelleme hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Kullanıcının analiz kredisini günceller
  Future<UserModel> updateAnalysisCredits(String userId, int newCredits) async {
    try {
      AppLogger.logWithContext('AuthRepository', 'Analiz kredisi güncelleniyor',
          '$userId: $newCredits');

      final user = await _getUserFromFirestore(userId);
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      final updatedUser = user.copyWith(
        analysisCredits: newCredits,
        updatedAt: DateTime.now(),
      );

      await _saveUserToFirestore(updatedUser);

      AppLogger.successWithContext('AuthRepository',
          'Analiz kredisi güncellendi', '$userId: $newCredits');
      return updatedUser;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 'Analiz kredisi güncelleme hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Kullanıcıyı Firestore'dan alır
  Future<UserModel?> _getUserFromFirestore(String userId) async {
    try {
      // Firestore service her zaman non-null olacak (constructor guarantee)
      // Bu kontrol artık gereksiz ama backward compatibility için bırakıyoruz

      AppLogger.logWithContext(
          'AuthRepository', '🔍 Firestore\'dan kullanıcı alınıyor', userId);

      final user = await _firestoreService.getDocument<UserModel>(
        collection: _usersCollection,
        documentId: userId,
        fromJson: UserModel.fromJson,
      );

      if (user != null) {
        AppLogger.successWithContext('AuthRepository',
            '✅ Kullanıcı Firestore\'dan başarıyla alındı', userId);
      } else {
        AppLogger.logWithContext('AuthRepository',
            '📭 Kullanıcı Firestore\'da bulunamadı (yeni kullanıcı)', userId);
      }

      return user;
    } on FirebaseException catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository',
          '⛔ Firestore kullanıcı alma hatası (${e.code}): ${e.message}',
          e,
          stackTrace);

      // Firestore bağlantı hatası durumunda null döndür (yeni kullanıcı olarak işle)
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'resource-exhausted' ||
          e.code == 'aborted' ||
          e.code == 'internal') {
        AppLogger.warnWithContext('AuthRepository',
            '🔄 Firestore geçici hata, null döndürülüyor (retry FirestoreService\'de yapılacak)');
        return null;
      }

      // Permission denied gibi kalıcı hatalar için de null döndür
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        AppLogger.warnWithContext(
            'AuthRepository', '🚫 Firestore erişim hatası, null döndürülüyor');
        return null;
      }

      rethrow;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', '❌ Beklenmeyen Firestore hatası', e, stackTrace);

      // Beklenmeyen hatalar için de null döndür (graceful degradation)
      return null;
    }
  }

  /// Kullanıcıyı Firestore'a kaydeder
  Future<void> _saveUserToFirestore(UserModel user) async {
    try {
      AppLogger.logWithContext('AuthRepository',
          '📝 Kullanıcı Firestore\'a kaydediliyor başlatıldı', user.id);

      // Firestore service her zaman non-null olacak (constructor guarantee)

      // Firebase Auth durumunu kontrol et
      final currentUser = _firebaseAuth.currentUser;
      AppLogger.logWithContext('AuthRepository',
          '🔐 Firebase Auth durumu: ${currentUser?.uid ?? "null"} (anonim: ${currentUser?.isAnonymous ?? false})');

      // UserModel'den JSON oluştur
      final Map<String, dynamic> userData = user.toJson();

      AppLogger.logWithContext('AuthRepository',
          '🔍 Kullanıcı data\'sı oluşturuldu', userData.toString());

      AppLogger.logWithContext(
          'AuthRepository', '⏳ Firestore setDocument işlemi başlatılıyor...');

      // Firestore'a kaydet
      final documentId = await _firestoreService.setDocument(
        collection: _usersCollection,
        documentId: user.id,
        data: userData,
        merge: true,
      );

      AppLogger.successWithContext(
          'AuthRepository',
          '✅ Kullanıcı başarıyla Firestore\'a kaydedildi',
          'DocID: $documentId');

      // Kaydedilen veriyi doğrula (optional verification)
      AppLogger.logWithContext(
          'AuthRepository', '🔍 Firestore verification başlatılıyor...');

      try {
        // Kısa bir bekleme ekle (Firestore eventual consistency için)
        await Future.delayed(const Duration(milliseconds: 500));

        final savedUser = await _getUserFromFirestore(user.id);
        if (savedUser != null) {
          AppLogger.logWithContext(
              'AuthRepository',
              '✓ Firestore verification: Kullanıcı başarıyla kaydedildi ve doğrulandı',
              user.id);
        } else {
          AppLogger.warnWithContext(
              'AuthRepository',
              '⚠️ Firestore verification: Kullanıcı kaydedildi ama doğrulanamadı (eventual consistency?)',
              user.id);
        }
      } catch (verificationError) {
        AppLogger.warnWithContext(
            'AuthRepository',
            '⚠️ Firestore verification hatası: ${verificationError.toString()}',
            user.id);
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext('AuthRepository',
          '❌ Firestore kullanıcı kaydetme hatası', e, stackTrace);

      // Firestore hatası durumunda özel error mesajları
      String errorContext = 'Unknown Firestore error';
      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission-denied')) {
        errorContext = 'Firestore permission denied - Security rules hatası';
      } else if (e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('unavailable')) {
        errorContext = 'Firestore service unavailable - Network hatası';
      } else if (e.toString().contains('DEADLINE_EXCEEDED') ||
          e.toString().contains('deadline-exceeded')) {
        errorContext = 'Firestore operation timeout - Bağlantı yavaş';
      } else if (e.toString().contains('UNAUTHENTICATED') ||
          e.toString().contains('unauthenticated')) {
        errorContext = 'Firestore authentication required - Auth hatası';
      }

      AppLogger.errorWithContext('AuthRepository',
          '🔍 Firestore error context: $errorContext', e, stackTrace);

      rethrow;
    }
  }

  /// Kullanıcıyı ID ile alır (public metod)
  Future<UserModel?> getUserById(String userId) async {
    return await _getUserFromFirestore(userId);
  }

  /// Şu anki kullanıcının verilerini alır
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    return await _getUserFromFirestore(user.uid);
  }

  /// Kullanıcının ilk kez giriş yapıp yapmadığını kontrol eder
  Future<bool> isFirstTimeUser(String userId) async {
    try {
      final user = await _getUserFromFirestore(userId);
      if (user == null) return true;

      // Eğer kullanıcı anonim ve createdAt ile updatedAt aynıysa ilk giriş

      final timeDiff = user.updatedAt.difference(user.createdAt);
      return timeDiff.inMinutes < 1; // 1 dakikadan az fark varsa ilk giriş
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 'İlk giriş kontrolü hatası', e, stackTrace);
      return false;
    }
  }

  /// Hesabı tamamen siler
  /// 
  /// NOT: Cihaz kredi kaydı silinmez - bu sayede aynı cihazdan
  /// yeni hesap açıldığında önceki kredi miktarı restore edilir
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        AppLogger.warnWithContext('AuthRepository', 
            'Silinecek kullanıcı bulunamadı - zaten çıkış yapılmış olabilir');
        return; // Kullanıcı zaten yoksa işlem tamamlanmış sayılır
      }

      AppLogger.logWithContext(
          'AuthRepository', 'Hesap silme işlemi başlatılıyor', user.uid);

      // Önce kullanıcının mevcut kredi sayısını al ve cihaz kaydında sakla
      try {
        final UserModel? currentUserData = await _getUserFromFirestore(user.uid);
        if (currentUserData != null) {
          await _deviceCreditService.updateUserCredits(
            user.uid, 
            currentUserData.analysisCredits,
          );
          AppLogger.logWithContext('AuthRepository', 
              'Kullanıcı kredisi cihaz kaydında saklandı', 
              '${user.uid} - ${currentUserData.analysisCredits} kredi');
        }
      } catch (creditUpdateError) {
        AppLogger.warnWithContext('AuthRepository', 
            'Kredi güncelleme hatası (devam ediliyor)', creditUpdateError);
        // Kredi güncelleme hatası olsa da hesap silme işlemine devam et
      }
      
      // Firestore'dan kullanıcı verisini sil
      await _firestoreService.deleteDocument(
        collection: _usersCollection,
        documentId: user.uid,
      );

      // Firebase Auth'dan kullanıcıyı sil
      try {
        await user.delete();
        AppLogger.logWithContext('AuthRepository', 
            'Firebase Auth kullanıcısı silindi', user.uid);
      } on FirebaseAuthException catch (authError) {
        if (authError.code == 'user-not-found') {
          AppLogger.warnWithContext('AuthRepository', 
              'Firebase Auth kullanıcısı zaten mevcut değil', user.uid);
          // Kullanıcı zaten yoksa devam et, hata verme
        } else {
          AppLogger.errorWithContext('AuthRepository', 
              'Firebase Auth kullanıcı silme hatası', authError);
          rethrow;
        }
      }

      AppLogger.successWithContext(
          'AuthRepository', 'Hesap başarıyla silindi (cihaz kaydı ve kredi korundu)', user.uid);
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          'AuthRepository', 'Hesap silme hatası', e, stackTrace);
      rethrow;
    }
  }

  /// Device credit service'ine erişim sağlar (debug/admin için)
  DeviceCreditService get deviceCreditService => _deviceCreditService;
}
