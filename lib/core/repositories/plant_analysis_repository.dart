import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../../features/plant_analysis/domain/entities/plant_analysis_entity.dart';
import '../../features/plant_analysis/data/models/plant_analysis_model.dart';
import '../../features/plant_analysis/data/models/plant_analysis_result.dart';
import '../../features/plant_analysis/data/models/disease_model.dart'
    as new_disease;
import '../../features/plant_analysis/services/plant_analysis_service.dart';
import '../services/firestore/firestore_service_interface.dart';
import '../utils/logger.dart';
import '../utils/validation_util.dart';

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
        'Analiz ve kaydetme işlemi başlatılıyor',
        'User: ${user.id}',
      );

      // Input validation
      if (!ValidationUtil.isValidFile(imageFile)) {
        throw ArgumentError('Geçersiz görüntü dosyası');
      }

      if (!ValidationUtil.isValidUserId(user.id)) {
        throw ArgumentError('Geçersiz kullanıcı kimliği');
      }

      // Upload image to storage
      final imageUrl = await _analysisService.uploadImage(imageFile);
      AppLogger.logWithContext(_serviceName, 'Görüntü yüklendi', imageUrl);

      // Analyze image (returns PlantAnalysisResult - old model)
      final analysisResult = await _analysisService.analyzeImage(
        imageUrl: imageUrl,
        location: '',
        fieldName: null,
      );

      // Convert old model to new model with proper disease conversion
      final analysisModel = PlantAnalysisModel(
        id: '',
        plantName: analysisResult.plantName,
        probability: analysisResult.probability,
        isHealthy: analysisResult.isHealthy,
        diseases: _convertDiseases(analysisResult.diseases),
        description: analysisResult.description,
        suggestions: analysisResult.suggestions,
        imageUrl: analysisResult.imageUrl,
        similarImages: analysisResult.similarImages,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Save analysis to Firestore
      final savedModel = await _saveAnalysisToFirestore(
        analysisModel,
        user.id,
      );

      AppLogger.successWithContext(
        _serviceName,
        'Analiz başarıyla tamamlandı ve kaydedildi',
        savedModel.id,
      );

      // Convert model to entity and return
      return savedModel.toEntity();
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Analiz ve kaydetme hatası',
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

      // Convert to model then entity with proper disease conversion
      final analysisModel = PlantAnalysisModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: analysisResult.plantName,
        probability: analysisResult.probability,
        isHealthy: analysisResult.isHealthy,
        diseases: _convertDiseases(analysisResult.diseases),
        description: analysisResult.description,
        suggestions: analysisResult.suggestions,
        imageUrl: analysisResult.imageUrl,
        similarImages: analysisResult.similarImages,
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
    // TODO: Implement disease-specific search using array-contains
    // For now, return unhealthy analyses
    return getUnhealthyAnalyses(userId: userId, limit: limit);
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
    // TODO: Implement aggregation query
    // For now return empty map
    return {};
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  @override
  Future<bool> isConnected() async {
    return true; // TODO: Implement connectivity check
  }

  @override
  Future<bool> clearCache() async {
    try {
      // TODO: Implement cache clearing
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> syncOfflineAnalyses() async {
    try {
      // TODO: Implement offline sync
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Eski Disease modellerini yeni Disease modellerine dönüştürür
  List<new_disease.Disease> _convertDiseases(List<Disease> oldDiseases) {
    return oldDiseases.map((oldDisease) {
      return new_disease.Disease(
        name: oldDisease.name,
        probability: oldDisease.probability ?? 0.0,
        description: oldDisease.description ?? '',
        treatments: oldDisease.treatments ?? [],
        severity: new_disease.DiseaseSeverity.fromString(oldDisease.severity),
      );
    }).toList();
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
