import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user_model.dart';
import '../../features/plant_analysis/domain/entities/plant_analysis_entity.dart';
import '../../features/plant_analysis/data/models/plant_analysis_model.dart';

import '../../features/plant_analysis/services/plant_analysis_service.dart';
import '../services/firestore/firestore_service_interface.dart';
import '../utils/logger.dart';
import '../utils/validation_util.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_response_parser.dart';
import 'package:tatarai/core/utils/cache_manager.dart';

/// Bitki analizi repository interface'i (Domain katmanı)
///
/// Clean Architecture prensiplerine uygun olarak domain katmanı
/// ile data katmanı arasında soyutlama sağlar.
///
/// Bu interface domain layer'da tanımlı olmalıydı ama mevcut yapı gereği
/// core'da tanımlıyoruz. Entity'ler kullanır, implementation detaylarını gizler.
abstract class PlantAnalysisRepository {
  // ============================================================================
  // ANALYSIS OPERATIONS
  // ============================================================================

  /// Görüntüyü analiz eder ve sonucu kaydeder
  ///
  /// @param imageFile - Analiz edilecek görüntü dosyası
  /// @param user - Analizi yapan kullanıcı
  /// @return PlantAnalysisEntity veya null (hata durumunda)
  Future<PlantAnalysisEntity?> analyzeAndSave(File imageFile, UserModel user);

  /// Görüntüyü sadece analiz eder (kaydetmez)
  ///
  /// @param imageFile - Analiz edilecek görüntü dosyası
  /// @return PlantAnalysisEntity veya null (hata durumunda)
  Future<PlantAnalysisEntity?> analyzeOnly(File imageFile);

  // ============================================================================
  // DATA RETRIEVAL
  // ============================================================================

  /// Analiz sonucunu ID ile getirir
  ///
  /// @param analysisId - Analiz benzersiz tanımlayıcısı
  /// @return PlantAnalysisEntity veya null (bulunamadığında)
  Future<PlantAnalysisEntity?> getAnalysisResult(String analysisId);

  /// Kullanıcının geçmiş analizlerini getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @param limit - Getirilen analiz sayısı limiti
  /// @return PlantAnalysisEntity listesi
  Future<List<PlantAnalysisEntity>> getPastAnalyses({
    String? userId,
    int limit = 20,
  });

  /// Kullanıcının son analizini getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @return PlantAnalysisEntity veya null (analiz yoksa)
  Future<PlantAnalysisEntity?> getLatestAnalysis({String? userId});

  /// Belirli bir tarih aralığındaki analizleri getirir
  ///
  /// @param startDate - Başlangıç tarihi
  /// @param endDate - Bitiş tarihi
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @return PlantAnalysisEntity listesi
  Future<List<PlantAnalysisEntity>> getAnalysesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  });

  /// Hastalıklı bitkilerin analizlerini getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @param limit - Getirilen analiz sayısı limiti
  /// @return PlantAnalysisEntity listesi
  Future<List<PlantAnalysisEntity>> getUnhealthyAnalyses({
    String? userId,
    int limit = 20,
  });

  // ============================================================================
  // DATA MODIFICATION
  // ============================================================================

  /// Analizi günceller
  ///
  /// @param analysisId - Güncellenecek analiz ID'si
  /// @param updatedEntity - Güncellenmiş entity
  /// @return Başarılı olup olmadığı
  Future<bool> updateAnalysis(
      String analysisId, PlantAnalysisEntity updatedEntity);

  /// Analizi siler
  ///
  /// @param analysisId - Silinecek analiz ID'si
  /// @return Başarılı olup olmadığı
  Future<bool> deleteAnalysis(String analysisId);

  /// Kullanıcının tüm analizlerini siler
  ///
  /// @param userId - Kullanıcı ID'si
  /// @return Başarılı olup olmadığı
  Future<bool> deleteAllUserAnalyses(String userId);

  // ============================================================================
  // SEARCH & FILTERING
  // ============================================================================

  /// Bitki adına göre arama yapar
  ///
  /// @param plantName - Aranacak bitki adı
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @param limit - Sonuç limiti
  /// @return PlantAnalysisEntity listesi
  Future<List<PlantAnalysisEntity>> searchByPlantName({
    required String plantName,
    String? userId,
    int limit = 20,
  });

  /// Belirli hastalığa sahip bitkileri getirir
  ///
  /// @param diseaseName - Hastalık adı
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @param limit - Sonuç limiti
  /// @return PlantAnalysisEntity listesi
  Future<List<PlantAnalysisEntity>> getAnalysesByDisease({
    required String diseaseName,
    String? userId,
    int limit = 20,
  });

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Kullanıcının toplam analiz sayısını getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @return Toplam analiz sayısı
  Future<int> getTotalAnalysesCount({String? userId});

  /// Kullanıcının sağlıklı/hastalıklı bitki oranlarını getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @return {healthy: int, unhealthy: int} Map'i
  Future<Map<String, int>> getHealthStatistics({String? userId});

  /// En çok analiz edilen bitki türlerini getirir
  ///
  /// @param userId - Kullanıcı ID'si (opsiyonel, null ise current user)
  /// @param limit - Sonuç limiti
  /// @return {plantName: count} Map'i
  Future<Map<String, int>> getMostAnalyzedPlants({
    String? userId,
    int limit = 10,
  });

  // ============================================================================
  // UTILITY
  // ============================================================================

  /// Repository'nin bağlantı durumunu kontrol eder
  ///
  /// @return Bağlantı durumu
  Future<bool> isConnected();

  /// Cache'i temizler
  ///
  /// @return Başarılı olup olmadığı
  Future<bool> clearCache();

  /// Offline analizleri sync eder
  ///
  /// @return Sync edilen analiz sayısı
  Future<int> syncOfflineAnalyses();
}

/// Bitki analizi repository concrete implementation
///
/// PlantAnalysisRepository interface'ini implement eder ve
/// Firebase Firestore ile analiz işlemlerini gerçekleştirir.
///
/// Data layer implementation'ı - Entity'leri Model'lere dönüştürür.
class PlantAnalysisRepositoryImpl implements PlantAnalysisRepository {
  // ============================================================================
  // DEPENDENCIES
  // ============================================================================

  /// Firestore service dependency
  final FirestoreServiceInterface _firestoreService;

  /// Plant analysis service dependency
  final PlantAnalysisService _analysisService;

  // ============================================================================
  // CONSTANTS
  // ============================================================================

  /// Analizler koleksiyon adı
  static const String _analysesCollection = 'plant_analyses';

  /// Service name for logging
  static const String _serviceName = 'PlantAnalysisRepositoryImpl';

  // ============================================================================
  // CONSTRUCTOR
  // ============================================================================

  /// Constructor
  PlantAnalysisRepositoryImpl({
    required FirestoreServiceInterface firestoreService,
    required PlantAnalysisService analysisService,
  })  : _firestoreService = firestoreService,
        _analysisService = analysisService {
    AppLogger.logWithContext(_serviceName, 'Repository başlatıldı');
  }

  // ============================================================================
  // ANALYSIS OPERATIONS
  // ============================================================================

  @override
  Future<PlantAnalysisEntity?> analyzeAndSave(
    File imageFile,
    UserModel user,
  ) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🚀 Analiz ve kaydetme işlemi başlatılıyor',
        'User: ${user.id}',
      );

      // === STEP 1: Firebase Auth kontrolü ===
      try {
        User? currentUser = FirebaseAuth.instance.currentUser;
        AppLogger.logWithContext(
          _serviceName,
          '🔐 Firebase Auth User: ${currentUser?.uid ?? "null"} (anonim: ${currentUser?.isAnonymous ?? false})',
        );

        // Eğer kullanıcı giriş yapmamışsa, anonymous sign in yap
        if (currentUser == null) {
          AppLogger.logWithContext(
            _serviceName,
            '⚠️ Firebase Auth user null, anonymous sign in yapılıyor...',
          );

          try {
            final userCredential =
                await FirebaseAuth.instance.signInAnonymously();
            currentUser = userCredential.user;

            if (currentUser != null) {
              AppLogger.successWithContext(
                _serviceName,
                '✅ Anonymous sign in başarılı',
                currentUser.uid,
              );
            } else {
              throw Exception('Anonymous sign in başarısız - user null');
            }
          } catch (authError) {
            AppLogger.errorWithContext(
              _serviceName,
              '❌ Anonymous sign in hatası',
              authError,
            );
            throw Exception(
                'Firebase Auth: Anonymous giriş yapılamadı - $authError');
          }
        }
      } catch (authError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 1 - Firebase Auth hatası',
          authError,
        );
        rethrow;
      }

      // === STEP 2: Input validation ===
      try {
        if (!ValidationUtil.isValidFile(imageFile)) {
          throw ArgumentError('Geçersiz görüntü dosyası');
        }

        if (!ValidationUtil.isValidUserId(user.id)) {
          throw ArgumentError('Geçersiz kullanıcı kimliği');
        }

        AppLogger.logWithContext(
          _serviceName,
          '✅ STEP 2 - Input validation başarılı',
        );
      } catch (validationError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 2 - Input validation hatası',
          validationError,
        );
        rethrow;
      }

      // === STEP 3: Convert image to bytes for comprehensive analysis ===
      Uint8List imageBytes;
      try {
        AppLogger.logWithContext(
          _serviceName,
          '🔄 STEP 3 - Image bytes dönüştürme başlatılıyor...',
        );

        imageBytes = await _analysisService.fileToBytes(imageFile);

        AppLogger.successWithContext(
          _serviceName,
          '✅ STEP 3 - Image bytes dönüştürme başarılı',
          'Size: ${imageBytes.length} bytes',
        );
      } catch (conversionError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 3 - Image bytes dönüştürme hatası',
          conversionError,
        );
        rethrow;
      }

      // === STEP 4: Upload image to Firebase Storage ===
      String imageDownloadUrl;
      try {
        AppLogger.logWithContext(
          _serviceName,
          '📤 STEP 4 - Firebase Storage a gorsel yukleniyor...',
        );

        imageDownloadUrl = await _analysisService.uploadImage(imageFile);

        AppLogger.successWithContext(
          _serviceName,
          '✅ STEP 4 - Görsel yükleme başarılı',
          'URL: $imageDownloadUrl',
        );
      } catch (uploadError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 4 - Görsel yükleme hatası',
          uploadError,
        );
        rethrow;
      }

      // === STEP 5: Comprehensive plant analysis with validations ===
      AnalysisResponse analysisResponse;
      try {
        AppLogger.logWithContext(
          _serviceName,
          '🤖 STEP 5 - Comprehensive plant analysis başlatılıyor...',
        );

        analysisResponse = await _analysisService.analyzePlant(
          imageBytes,
          user,
          location: '',
          fieldName: null,
        );

        if (!analysisResponse.success) {
          throw Exception('Analysis failed: ${analysisResponse.message}');
        }

        AppLogger.successWithContext(
          _serviceName,
          '✅ STEP 5 - Comprehensive plant analysis başarılı',
          'Response: ${analysisResponse.message}',
        );
      } catch (analysisError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 5 - Comprehensive plant analysis hatası',
          analysisError,
        );
        rethrow;
      }

      // === STEP 5: Parse Gemini response and create analysis model ===
      PlantAnalysisModel analysisModel;
      try {
        AppLogger.logWithContext(
          _serviceName,
          '🔄 STEP 5 - Gemini yanıtını parse ediyoruz...',
        );

        // DEBUG: Gemini response'ını logla
        AppLogger.logWithContext(
          _serviceName,
          '🔹 Gemini Service yanıtı:',
          analysisResponse.result?.substring(
                  0,
                  analysisResponse.result!.length > 500
                      ? 500
                      : analysisResponse.result!.length) ??
              'null',
        );

        // Gemini yanıtını PlantAnalysisResult'a parse et
        final plantAnalysisResult = await _parseGeminiResponse(
          analysisResponse.result ?? '{}',
          imageDownloadUrl, // Yüklenen görüntü URL'i
          analysisResponse.location ?? '',
          analysisResponse.fieldName,
        );

        // PlantAnalysisModel'den PlantAnalysisModel'e dönüştür (artık aynı model)
        analysisModel = plantAnalysisResult;

        AppLogger.logWithContext(
          _serviceName,
          '✅ STEP 5 - Model oluşturma başarılı',
        );
      } catch (modelError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 5 - Model oluşturma hatası',
          modelError,
        );
        rethrow;
      }

      // === STEP 6: Save to Firestore ===
      PlantAnalysisModel savedModel;
      try {
        AppLogger.logWithContext(
          _serviceName,
          '💾 STEP 6 - Firestore kaydetme başlatılıyor...',
        );

        savedModel = await _saveAnalysisToFirestore(
          analysisModel,
          user.id,
        );

        AppLogger.successWithContext(
          _serviceName,
          '✅ STEP 6 - Firestore kaydetme başarılı',
          savedModel.id,
        );
      } catch (firestoreError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 6 - Firestore kaydetme hatası',
          firestoreError,
        );
        rethrow;
      }

      // === STEP 7: Convert to entity and return ===
      try {
        final entity = savedModel.toEntity();

        AppLogger.successWithContext(
          _serviceName,
          '🎉 Analiz başarıyla tamamlandı ve kaydedildi',
          'ID: ${savedModel.id}, Plant: ${savedModel.plantName}',
        );

        return entity;
      } catch (entityError) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ STEP 7 - Entity dönüştürme hatası',
          entityError,
        );
        rethrow;
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        '💥 Analiz ve kaydetme GENEL hatası',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<PlantAnalysisEntity?> analyzeOnly(File imageFile) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Sadece analiz işlemi başlatılıyor',
      );

      // Upload image to storage
      final imageUrl = await _analysisService.uploadImage(imageFile);

      // Analyze image
      final analysisResult = await _analysisService.analyzeImage(
        imageUrl: imageUrl,
        location: '',
        fieldName: null,
      );

      // analysisResult zaten PlantAnalysisModel, ID'sini güncelle
      final analysisModel = analysisResult.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      return analysisModel.toEntity();
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Sadece analiz hatası',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<PlantAnalysisEntity?> getAnalysisResult(String analysisId) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Analiz sonucu getiriliyor',
        analysisId,
      );

      if (!ValidationUtil.isValidId(analysisId)) {
        throw ArgumentError('Geçersiz analiz kimliği');
      }

      final model = await _firestoreService.getDocument<PlantAnalysisModel>(
        collection: _analysesCollection,
        documentId: analysisId,
        fromJson: PlantAnalysisModel.fromJson,
      );

      if (model != null) {
        AppLogger.successWithContext(
          _serviceName,
          'Analiz sonucu başarıyla getirildi',
          analysisId,
        );
        return model.toEntity();
      } else {
        AppLogger.warnWithContext(
          _serviceName,
          'Analiz sonucu bulunamadı',
          analysisId,
        );
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Analiz sonucu getirme hatası',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<List<PlantAnalysisEntity>> getPastAnalyses({
    String? userId,
    int limit = 20,
  }) async {
    try {
      // Get current user if userId is null
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      AppLogger.logWithContext(
        _serviceName,
        'Geçmiş analizler getiriliyor',
        'UserId: $targetUserId, Limit: $limit',
      );

      final models =
          await _firestoreService.getDocumentsWithQuery<PlantAnalysisModel>(
        collection: _analysesCollection,
        fromJson: PlantAnalysisModel.fromJson,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .orderBy('timestamp', descending: true)
            .limit(limit),
      );

      final entities = models.map((model) => model.toEntity()).toList();

      AppLogger.successWithContext(
        _serviceName,
        'Geçmiş analizler başarıyla getirildi',
        'Count: ${entities.length}',
      );

      return entities;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Geçmiş analizler getirme hatası',
        e,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<PlantAnalysisEntity?> getLatestAnalysis({String? userId}) async {
    final analyses = await getPastAnalyses(userId: userId, limit: 1);
    return analyses.isNotEmpty ? analyses.first : null;
  }

  @override
  Future<List<PlantAnalysisEntity>> getAnalysesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final models =
          await _firestoreService.getDocumentsWithQuery<PlantAnalysisModel>(
        collection: _analysesCollection,
        fromJson: PlantAnalysisModel.fromJson,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .where('timestamp',
                isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
            .orderBy('timestamp', descending: true),
      );

      return models.map((model) => model.toEntity()).toList();
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Tarih aralığı analiz getirme hatası',
        e,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<List<PlantAnalysisEntity>> getUnhealthyAnalyses({
    String? userId,
    int limit = 20,
  }) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final models =
          await _firestoreService.getDocumentsWithQuery<PlantAnalysisModel>(
        collection: _analysesCollection,
        fromJson: PlantAnalysisModel.fromJson,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .where('isHealthy', isEqualTo: false)
            .orderBy('timestamp', descending: true)
            .limit(limit),
      );

      return models.map((model) => model.toEntity()).toList();
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Hastalıklı analizler getirme hatası',
        e,
        stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // DATA MODIFICATION
  // ============================================================================

  @override
  Future<bool> updateAnalysis(
      String analysisId, PlantAnalysisEntity updatedEntity) async {
    try {
      final model = PlantAnalysisModel.fromEntity(updatedEntity);

      await _firestoreService.updateDocument(
        collection: _analysesCollection,
        documentId: analysisId,
        data: model.toJson(),
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Analiz güncelleme hatası',
        e,
        stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> deleteAnalysis(String analysisId) async {
    try {
      await _firestoreService.deleteDocument(
        collection: _analysesCollection,
        documentId: analysisId,
      );

      AppLogger.successWithContext(
        _serviceName,
        'Analiz başarıyla silindi',
        analysisId,
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Analiz silme hatası',
        e,
        stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> deleteAllUserAnalyses(String userId) async {
    try {
      final deletedCount = await _firestoreService.deleteDocumentsWithQuery(
        collection: _analysesCollection,
        queryBuilder: (collection) =>
            collection.where('userId', isEqualTo: userId),
      );

      AppLogger.successWithContext(
        _serviceName,
        'Kullanıcının tüm analizleri silindi',
        'Silinen: $deletedCount',
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Tüm analiz silme hatası',
        e,
        stackTrace,
      );
      return false;
    }
  }

  // ============================================================================
  // SEARCH & FILTERING
  // ============================================================================

  @override
  Future<List<PlantAnalysisEntity>> searchByPlantName({
    required String plantName,
    String? userId,
    int limit = 20,
  }) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final models =
          await _firestoreService.getDocumentsWithQuery<PlantAnalysisModel>(
        collection: _analysesCollection,
        fromJson: PlantAnalysisModel.fromJson,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .where('plantName', isGreaterThanOrEqualTo: plantName)
            .where('plantName', isLessThan: plantName + '\uf8ff')
            .limit(limit),
      );

      return models.map((model) => model.toEntity()).toList();
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Bitki adı arama hatası',
        e,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<List<PlantAnalysisEntity>> getAnalysesByDisease({
    required String diseaseName,
    String? userId,
    int limit = 20,
  }) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      // Hastalık adına göre arama yap - diseases array'inde bu hastalığı içeren analizler
      final Query query = _firestoreService.firestore
          .collection(_analysesCollection)
          .where('userId', isEqualTo: targetUserId)
          .where('isHealthy', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final QuerySnapshot snapshot = await query.get();

      final List<PlantAnalysisEntity> analyses = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Hastalık listesini kontrol et
          final List<dynamic> diseases = data['diseases'] ?? [];
          bool hasDisease = diseases.any((disease) {
            if (disease is Map<String, dynamic>) {
              final String? name = disease['name'];
              return name?.toLowerCase().contains(diseaseName.toLowerCase()) ??
                  false;
            }
            return false;
          });

          if (hasDisease) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Document ID'yi data'ya ekle
            final model = PlantAnalysisModel.fromJson(data);
            analyses.add(model.toEntity());
          }
        } catch (e) {
          AppLogger.warnWithContext(
            _serviceName,
            'Hastalık bazlı analiz parse hatası',
            'Doc ID: ${doc.id}, Error: $e',
          );
        }
      }

      AppLogger.successWithContext(
        _serviceName,
        'Hastalık bazlı analizler alındı',
        'Disease: $diseaseName, Count: ${analyses.length}',
      );

      return analyses;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Hastalık bazlı analiz getirme hatası',
        e,
        stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  @override
  Future<int> getTotalAnalysesCount({String? userId}) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      return await _firestoreService.getDocumentCount(
        collection: _analysesCollection,
        queryBuilder: (collection) =>
            collection.where('userId', isEqualTo: targetUserId),
      );
    } catch (e) {
      AppLogger.errorWithContext(
          _serviceName, 'Toplam analiz sayısı getirme hatası', e);
      return 0;
    }
  }

  @override
  Future<Map<String, int>> getHealthStatistics({String? userId}) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final total = await getTotalAnalysesCount(userId: targetUserId);

      final healthy = await _firestoreService.getDocumentCount(
        collection: _analysesCollection,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .where('isHealthy', isEqualTo: true),
      );

      return {
        'healthy': healthy,
        'unhealthy': total - healthy,
      };
    } catch (e) {
      AppLogger.errorWithContext(
          _serviceName, 'Sağlık istatistikleri getirme hatası', e);
      return {'healthy': 0, 'unhealthy': 0};
    }
  }

  @override
  Future<Map<String, int>> getMostAnalyzedPlants({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final targetUserId =
          userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      AppLogger.logWithContext(
        _serviceName,
        'En çok analiz edilen bitkiler getiriliyor',
        'UserId: $targetUserId, Limit: $limit',
      );

      // Kullanıcının tüm analizlerini al
      final models =
          await _firestoreService.getDocumentsWithQuery<PlantAnalysisModel>(
        collection: _analysesCollection,
        fromJson: PlantAnalysisModel.fromJson,
        queryBuilder: (collection) => collection
            .where('userId', isEqualTo: targetUserId)
            .orderBy('timestamp', descending: true),
      );

      // Bitki adlarını say
      final Map<String, int> plantCounts = {};
      for (final model in models) {
        final plantName = model.plantName.trim();
        if (plantName.isNotEmpty && plantName != 'Bilinmeyen Bitki') {
          plantCounts[plantName] = (plantCounts[plantName] ?? 0) + 1;
        }
      }

      // En çok analizlenenleri sırala ve limit'le
      final sortedEntries = plantCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final result = Map<String, int>.fromEntries(
        sortedEntries.take(limit),
      );

      AppLogger.successWithContext(
        _serviceName,
        'En çok analiz edilen bitkiler alındı',
        'Plant count: ${result.length}',
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'En çok analiz edilen bitkiler getirme hatası',
        e,
        stackTrace,
      );
      return {};
    }
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  @override
  Future<bool> isConnected() async {
    try {
      // Connectivity kontrolü
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;

      if (!hasConnection) {
        return false;
      }

      // Firebase bağlantısı test et
      try {
        await _firestoreService.firestore
            .collection('_connection_test')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));
        return true;
      } catch (e) {
        AppLogger.warnWithContext(
          _serviceName,
          'Firebase bağlantı testi başarısız',
          e.toString(),
        );
        return false;
      }
    } catch (e) {
      AppLogger.errorWithContext(
        _serviceName,
        'Bağlantı kontrolü hatası',
        e,
      );
      return false;
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      // CacheManager kullanarak önbelleği temizle
      final cacheManager = CacheManager();
      await cacheManager.init();
      final success = await cacheManager.clearCache();

      AppLogger.logWithContext(
        _serviceName,
        'Önbellek temizleme sonucu',
        'Success: $success',
      );

      return success;
    } catch (e) {
      AppLogger.errorWithContext(
        _serviceName,
        'Önbellek temizleme hatası',
        e,
      );
      return false;
    }
  }

  @override
  Future<int> syncOfflineAnalyses() async {
    try {
      // Offline analizleri kontrol et ve senkronize et
      final cacheManager = CacheManager();
      await cacheManager.init();

      // Önbellekten offline analizleri al
      final cachedAnalyses = await cacheManager.getCachedAnalysisResults();

      int syncedCount = 0;

      for (final analysis in cachedAnalyses) {
        try {
          // Online olup olmadığını kontrol et
          final isOnline = await isConnected();
          if (!isOnline) {
            break;
          }

          // Firestore'da bu analiz var mı kontrol et
          final existingDoc = await _firestoreService.firestore
              .collection(_analysesCollection)
              .doc(analysis.id)
              .get();

          // Eğer yoksa, yükle
          if (!existingDoc.exists) {
            final model = PlantAnalysisModel(
              id: analysis.id,
              plantName: analysis.plantName,
              probability: analysis.probability,
              isHealthy: analysis.isHealthy,
              diseases: [], // Cached analizlerde disease detayları eksik olabilir
              description: analysis.description,
              suggestions: analysis.suggestions,
              imageUrl: analysis.imageUrl,
              similarImages: analysis.similarImages,
              timestamp: analysis.timestamp,
              location: analysis.location,
              fieldName: analysis.fieldName,
            );

            await _firestoreService.setDocument(
              collection: _analysesCollection,
              documentId: analysis.id,
              data: model.toJson(),
            );

            syncedCount++;
          }
        } catch (e) {
          AppLogger.warnWithContext(
            _serviceName,
            'Analiz senkronizasyon hatası',
            'ID: ${analysis.id}, Error: $e',
          );
        }
      }

      AppLogger.successWithContext(
        _serviceName,
        'Offline analiz senkronizasyonu tamamlandı',
        'Senkronize edilen: $syncedCount',
      );

      return syncedCount;
    } catch (e) {
      AppLogger.errorWithContext(
        _serviceName,
        'Offline senkronizasyon hatası',
        e,
      );
      return 0;
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Gemini servisinden dönen JSON yanıtını PlantAnalysisModel'a parse eder
  Future<PlantAnalysisModel> _parseGeminiResponse(
    String geminiJsonResponse,
    String imageUrl,
    String location,
    String? fieldName,
  ) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🔄 Gemini JSON parsing başlatılıyor...',
        'Response length: ${geminiJsonResponse.length}',
      );

      // Yeni GeminiResponseParser kullan
      final parsedResult = await GeminiResponseParser.parseAnalysisResponse(
        rawResponse: geminiJsonResponse,
        imageUrl: imageUrl,
        location: location,
        fieldName: fieldName,
      );

      AppLogger.successWithContext(
        _serviceName,
        '✅ Gemini JSON parsing başarılı',
        'Plant: ${parsedResult.plantName}, Diseases: ${parsedResult.diseases.length}',
      );

      return parsedResult;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        '❌ Gemini JSON parsing hatası',
        e,
        stackTrace,
      );

      // Parse hata durumunda fallback response döndür
      return PlantAnalysisModel.createEmpty(
        imageUrl: imageUrl,
        location: location,
        fieldName: fieldName,
        errorMessage: 'Gemini yanıtı parse edilemedi: ${e.toString()}',
        originalText: geminiJsonResponse,
      );
    }
  }

  /// Analizi Firestore'a kaydeder
  Future<PlantAnalysisModel> _saveAnalysisToFirestore(
    PlantAnalysisModel model,
    String userId,
  ) async {
    try {
      // Model'e userId ekle ve timestamp güncelle
      final modelData = model.toJson();
      modelData['userId'] = userId;
      modelData['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      final docId = await _firestoreService.setDocument(
        collection: _analysesCollection,
        data: modelData,
      );

      // ID'si güncellenen model'i döndür
      return model.copyWith(id: docId);
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Firestore kaydetme hatası',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
