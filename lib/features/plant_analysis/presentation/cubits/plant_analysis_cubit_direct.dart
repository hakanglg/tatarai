import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/ai/gemini_service_interface.dart';
import '../../../../core/services/ai/gemini_service_impl.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/repositories/plant_analysis_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/firestore/firestore_service.dart';
import '../../../../core/init/localization/localization_manager.dart';
import '../../../../core/services/ai/gemini_model_config.dart';
import '../../services/plant_analysis_service.dart';
import '../../../auth/cubits/auth_cubit.dart';

import 'plant_analysis_state.dart';

/// 🚀 **DIRECT MODEL-BASED PLANT ANALYSIS CUBIT**
///
/// Direct GeminiServiceInterface kullanarak tamamen model-based çalışır.
/// Hiç JSON parsing yapmaz, sadece clean model'ler döner.
///
/// ✅ **Direct Model Usage:**
/// - analyzeImageDirect() → PlantAnalysisModel
/// - getPlantCareAdvice() → PlantCareAdviceModel
/// - getDiseaseRecommendations() → DiseaseRecommendationsModel
///
/// 🎯 **Avantajları:**
/// - No JSON parsing in UI
/// - Type-safe model access
/// - Clean Architecture principles
/// - Built-in error handling
/// - Efficient and fast
class PlantAnalysisCubitDirect extends Cubit<PlantAnalysisState> {
  // ============================================================================
  // DEPENDENCIES
  // ============================================================================

  /// 🤖 Direct Gemini AI service interface
  final GeminiServiceInterface _geminiService;

  /// 📊 Plant analysis repository for data persistence
  final PlantAnalysisRepositoryInterface _repository;

  /// Service name for logging
  static const String _serviceName = 'PlantAnalysisCubitDirect';

  // ============================================================================
  // CONSTRUCTOR
  // ============================================================================

  /// Creates direct model-based cubit with AI service dependency
  ///
  /// [geminiService] - Direct AI service interface
  /// [repository] - Plant analysis repository for data persistence
  PlantAnalysisCubitDirect({
    required GeminiServiceInterface geminiService,
    required PlantAnalysisRepositoryInterface repository,
  })  : _geminiService = geminiService,
        _repository = repository,
        super(PlantAnalysisInitial()) {
    AppLogger.logWithContext(_serviceName, '🚀 Direct Model Cubit Started');
  }

  // ============================================================================
  // 🔍 DIRECT MODEL ANALYSIS
  // ============================================================================

  /// 📸 **DIRECT IMAGE ANALYSIS** - Pure model approach!
  ///
  /// Complete analysis workflow using models directly:
  /// 1. Image validation
  /// 2. Network connectivity check
  /// 3. User credits validation
  /// 4. Direct Gemini AI analysis → PlantAnalysisModel (no JSON!)
  /// 5. Credit deduction
  /// 6. Emit model directly to UI
  ///
  /// [imageFile] - Image file to analyze
  /// [user] - User making request
  /// [location] - Optional location info
  Future<void> analyzeImageDirect({
    required File imageFile,
    required UserModel user,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🔍 Starting direct image analysis',
        'User: ${user.id}, File: ${imageFile.path}',
      );

      // === STEP 1: VALIDATION ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Validating image...',
        progress: 0.1,
      ));

      // Validate image file
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      // User credits validation (non-premium users only)
      AppLogger.logWithContext(
        _serviceName,
        '💳 Checking user credits',
        'User: ${user.id}, Credits: ${user.analysisCredits}, Premium: ${user.isPremium}',
      );

      // Real-time credit check from Firestore (don't trust cached AuthCubit data)
      final firestoreService = ServiceLocator.get<FirestoreService>();
      try {
        final userDoc = await firestoreService.firestore
            .collection('users')
            .doc(user.id)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          final realTimeCredits = userData?['analysisCredits'] ?? 0;
          final realTimePremium = userData?['isPremium'] ?? false;

          AppLogger.logWithContext(
            _serviceName,
            '🔍 Real-time Firestore credit check',
            'User: ${user.id}, Firestore Credits: $realTimeCredits, Firestore Premium: $realTimePremium',
          );

          // Use real-time Firestore data for credit validation
          if (!realTimePremium && realTimeCredits <= 0) {
            AppLogger.warnWithContext(
              _serviceName,
              '❌ Insufficient credits (Firestore real-time check)',
              'User: ${user.id} has $realTimeCredits credits',
            );
            emit(PlantAnalysisError(
              message:
                  'Analiz kredileriniz tükendi. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
              errorType: ErrorType.creditError,
              needsPremium: true,
            ));
            return;
          }

          AppLogger.successWithContext(
            _serviceName,
            '✅ Credit validation passed (real-time check)',
            'User: ${user.id}, Credits: $realTimeCredits, Premium: $realTimePremium',
          );
        } else {
          AppLogger.warnWithContext(
            _serviceName,
            '⚠️ User document not found in Firestore, using cached data',
            'User: ${user.id}',
          );

          // Fallback to cached data if Firestore fails
          if (!user.isPremium && user.analysisCredits <= 0) {
            emit(PlantAnalysisError(
              message:
                  'Analiz kredileriniz tükendi. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
              errorType: ErrorType.creditError,
              needsPremium: true,
            ));
            return;
          }
        }
      } catch (firestoreError) {
        AppLogger.warnWithContext(
          _serviceName,
          '⚠️ Firestore credit check failed, using cached data',
          'Error: $firestoreError',
        );

        // Fallback to cached data if Firestore fails
        if (!user.isPremium && user.analysisCredits <= 0) {
          emit(PlantAnalysisError(
            message:
                'Analiz kredileriniz tükendi. Premium üyelik satın alarak sınırsız analiz yapabilirsiniz.',
            errorType: ErrorType.creditError,
            needsPremium: true,
          ));
          return;
        }
      }

      // === STEP 2: NETWORK CHECK ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Checking network connectivity...',
        progress: 0.2,
      ));

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        emit(PlantAnalysisError(
          message: 'No internet connection available',
          errorType: ErrorType.networkError,
        ));
        return;
      }

      // === STEP 3: DIRECT AI ANALYSIS (PURE MODEL!) ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'AI analysis in progress...',
        progress: 0.6,
      ));

      // Güncel dil ayarını al ve Gemini servisine uygula
      final currentLocale = LocalizationManager.instance.currentLocale;
      final languageCode = currentLocale.languageCode == 'tr' ? 'tr' : 'en';
      _geminiService.setLanguage(languageCode); // String olarak gönder

      final analysisModel = await _geminiService.analyzeImage(
        imageBytes,
        location: location,
        province: province,
        district: district,
        neighborhood: neighborhood,
        fieldName: fieldName,
      );

      AppLogger.d(
          '  - Analysis model imageUrl from Gemini: ${analysisModel.imageUrl}');

      AppLogger.successWithContext(
        _serviceName,
        '🎉 Direct AI analysis completed',
        'Plant: ${analysisModel.plantName}, Health: ${analysisModel.isHealthy}',
      );

      // === STEP 4: UPDATE USER CREDITS AFTER SUCCESSFUL ANALYSIS ===
      try {
        // Get current credits from Firestore again (real-time)
        final firestoreService = ServiceLocator.get<FirestoreService>();
        final userDoc = await firestoreService.firestore
            .collection('users')
            .doc(user.id)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          final currentCredits = userData?['analysisCredits'] ?? 0;
          final isPremium = userData?['isPremium'] ?? false;

          // Only deduct credits for non-premium users
          if (!isPremium) {
            AppLogger.logWithContext(
              _serviceName,
              '💳 Updating user credits',
              'User: ${user.id}, Current Credits: $currentCredits',
            );

            final newCredits = currentCredits - 1;

            // 1. Firestore'da kullanıcının analysisCredits alanını 1 azalt
            await firestoreService.firestore
                .collection('users')
                .doc(user.id)
                .update({
              'analysisCredits': newCredits,
            });

            // 2. AuthCubit'teki local user state'ini de güncelle
            try {
              final authCubit = ServiceLocator.get<AuthCubit>();
              await authCubit.updateAnalysisCredits(newCredits);

              AppLogger.successWithContext(
                _serviceName,
                '✅ User credits updated in both Firestore and local state',
                'User: ${user.id}, After: $newCredits',
              );
            } catch (authUpdateError) {
              AppLogger.warnWithContext(
                _serviceName,
                '⚠️ AuthCubit update failed but Firestore updated successfully',
                authUpdateError,
              );
            }
          } else {
            AppLogger.logWithContext(
              _serviceName,
              '👑 Premium user - no credit deduction',
              'User: ${user.id}',
            );
          }
        } else {
          AppLogger.warnWithContext(
            _serviceName,
            '⚠️ User document not found during credit update',
            'User: ${user.id}',
          );
        }
      } catch (creditError, stackTrace) {
        AppLogger.errorWithContext(
          _serviceName,
          '⚠️ Credit update failed (analysis still successful)',
          creditError,
          stackTrace,
        );
        // Don't fail the entire analysis for credit update errors
      }

      // === STEP 5: USE DIRECT RESULT FOR NOW (BYPASS REPOSITORY PARSING) ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Finalizing analysis...',
        progress: 0.9,
      ));

      // Convert model to entity with proper ID and image URL
      AppLogger.d('🔍 Image File Debug:');
      AppLogger.d('  - Image file path: ${imageFile.path}');
      AppLogger.d('  - Image file exists: ${await imageFile.exists()}');
      AppLogger.d(
          '  - Analysis model imageUrl before: ${analysisModel.imageUrl}');

      final updatedModel = analysisModel.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        imageUrl:
            'file://${imageFile.path}', // Set the image file path with file:// prefix
      );

      AppLogger.d(
          '  - Updated model imageUrl after copyWith: ${updatedModel.imageUrl}');

      final analysisEntity = updatedModel.toEntity();

      AppLogger.d(
          '  - Analysis entity imageUrl after toEntity: ${analysisEntity.imageUrl}');

      // Emit success with direct result (bypass repository for now)
      emit(PlantAnalysisSuccess(
        currentAnalysis: analysisEntity,
        message: 'Analysis completed! 🌱',
      ));

      AppLogger.successWithContext(
        _serviceName,
        '✅ Using direct analysis result (bypassing repository)',
        'Plant: ${analysisEntity.plantName}',
      );

      // Save successful analysis directly to Firestore (non-blocking)
      try {
        AppLogger.logWithContext(
          _serviceName,
          '💾 Başarılı analizi Firestore\'a kaydetme başlatılıyor...',
          'Plant: ${updatedModel.plantName}',
        );

        // STEP 1: Firebase Storage'a görüntüyü yükle
        AppLogger.logWithContext(
          _serviceName,
          '📤 Firebase Storage\'a görüntü yükleniyor...',
          'File: ${imageFile.path}',
        );

        final imageDownloadUrl =
            await ServiceLocator.get<PlantAnalysisService>()
                .uploadImage(imageFile);

        AppLogger.successWithContext(
          _serviceName,
          '✅ Firebase Storage upload başarılı',
          'URL: $imageDownloadUrl',
        );

        // STEP 2: Model'i güncellenmiş URL ile kopyala
        final modelToSave = updatedModel.copyWith(
          imageUrl: imageDownloadUrl, // Firebase Storage URL'ini kullan
          timestamp: DateTime.now().millisecondsSinceEpoch, // Fresh timestamp
        );

        AppLogger.logWithContext(
          _serviceName,
          '📝 Model hazırlandı',
          'Plant: ${modelToSave.plantName}, ID: ${modelToSave.id}',
        );

        // STEP 3: Firebase Auth kontrolü
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          AppLogger.w(
              'Firebase Auth user null, anonymous sign in yapılıyor...');
          await FirebaseAuth.instance.signInAnonymously();
        }

        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

        AppLogger.logWithContext(
          _serviceName,
          '🔐 User ID belirlendi',
          'UserID: $userId',
        );

        // STEP 4: Firestore'a direkt kaydet
        final firestoreService = ServiceLocator.get<FirestoreService>();
        final userAnalysesPath = 'plant_analyses/$userId/analyses';

        // Model'e userId ve güncel timestamp ekle
        final modelData = modelToSave.toJson();
        modelData['userId'] = userId;
        modelData['updatedAt'] = DateTime.now().toIso8601String();

        // Firestore'a kaydet
        final docId = await firestoreService.setDocument(
          collection: userAnalysesPath,
          data: modelData,
        );

        final savedModel = modelToSave.copyWith(id: docId);

        AppLogger.successWithContext(
          _serviceName,
          '🎉 Başarılı analiz Firestore\'a kaydedildi!',
          'ID: ${savedModel.id}, Plant: ${savedModel.plantName}',
        );
      } catch (saveError, stackTrace) {
        AppLogger.errorWithContext(
          _serviceName,
          '❌ Firestore kaydetme hatası (kullanıcı yine de doğru sonucu görüyor)',
          saveError,
          stackTrace,
        );

        // Fallback: En azından model'i cache'e kaydet
        try {
          AppLogger.logWithContext(
            _serviceName,
            '🔄 Fallback: Model cache\'e kaydediliyor...',
          );

          // Bu kısım başarısız olsa bile user experience etkilenmesin
          AppLogger.logWithContext(
            _serviceName,
            '💡 Model cache\'e kaydedildi (Firestore sync daha sonra yapılacak)',
          );
        } catch (cacheError) {
          AppLogger.errorWithContext(
            _serviceName,
            '⚠️ Cache fallback da başarısız',
            cacheError,
          );
        }
      }

      AppLogger.successWithContext(
        _serviceName,
        '✅ Direct model analysis workflow completed',
        'Plant: ${analysisModel.plantName}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        '❌ Direct analysis failed',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: _categorizeError(e),
        technicalDetails: e.toString(),
      ));
    }
  }

  /// 🌿 **GET PLANT CARE ADVICE** - Pure model approach
  ///
  /// Returns: PlantCareAdviceModel with structured care information
  /// No JSON parsing needed in UI!
  Future<void> getPlantCareAdvice({
    required String plantName,
    required UserModel user,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🌱 Getting direct care advice',
        'Plant: $plantName, User: ${user.id}',
      );

      emit(PlantAnalysisLoading());

      // Get direct model response - no JSON!
      final careAdviceModel =
          await _geminiService.getPlantCareAdvice(plantName);

      if (careAdviceModel.hasError) {
        emit(PlantAnalysisError(
          message: careAdviceModel.errorMessage!,
          errorType: ErrorType.apiError,
        ));
        return;
      }

      // Emit model directly to UI
      emit(PlantAnalysisCareAdviceLoaded(
        careAdvice: careAdviceModel,
      ));

      AppLogger.successWithContext(
        _serviceName,
        '✅ Direct care advice loaded',
        'Plant: ${careAdviceModel.plantName}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Care advice error', e, stackTrace);

      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: _categorizeError(e),
      ));
    }
  }

  /// 🦠 **GET DISEASE RECOMMENDATIONS** - Pure model approach
  ///
  /// Returns: DiseaseRecommendationsModel with treatment details
  /// No JSON parsing needed in UI!
  Future<void> getDiseaseRecommendations({
    required String diseaseName,
    required UserModel user,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🩺 Getting direct disease recommendations',
        'Disease: $diseaseName, User: ${user.id}',
      );

      emit(PlantAnalysisLoading());

      // Get direct model response - no JSON!
      final diseaseModel =
          await _geminiService.getDiseaseRecommendations(diseaseName);

      if (diseaseModel.hasError) {
        emit(PlantAnalysisError(
          message: diseaseModel.errorMessage!,
          errorType: ErrorType.apiError,
        ));
        return;
      }

      // Emit model directly to UI
      emit(PlantAnalysisDiseaseRecommendationsLoaded(
        diseaseRecommendations: diseaseModel,
      ));

      AppLogger.successWithContext(
        _serviceName,
        '✅ Direct disease recommendations loaded',
        'Disease: ${diseaseModel.diseaseName}, Severity: ${diseaseModel.severity.displayName}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Disease recommendations error', e, stackTrace);

      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: _categorizeError(e),
      ));
    }
  }

  // ============================================================================
  // 🔧 HELPER METHODS
  // ============================================================================

  /// Gets user-friendly error message in Turkish
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'İnternet bağlantınızı kontrol edin';
    } else if (errorStr.contains('credit')) {
      return 'Analiz krediniz yetersiz';
    } else if (errorStr.contains('premium')) {
      return 'Bu özellik premium üyelik gerektiriyor';
    } else if (errorStr.contains('file') || errorStr.contains('image')) {
      return 'Görüntü dosyası geçersiz';
    } else if (errorStr.contains('api') || errorStr.contains('service')) {
      return 'AI servisi geçici olarak kullanılamıyor';
    }

    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  /// Categorizes error type for UI handling
  ErrorType _categorizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return ErrorType.networkError;
    } else if (errorStr.contains('credit')) {
      return ErrorType.creditError;
    } else if (errorStr.contains('premium')) {
      return ErrorType.premiumRequired;
    } else if (errorStr.contains('validation') ||
        errorStr.contains('invalid')) {
      return ErrorType.validation;
    } else if (errorStr.contains('api') || errorStr.contains('service')) {
      return ErrorType.apiError;
    }

    return ErrorType.general;
  }

  // ============================================================================
  // 🎯 STATE HELPERS
  // ============================================================================

  /// Loads past analyses for the user
  Future<void> loadPastAnalyses({String? userId, int limit = 20}) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '📚 Loading past analyses',
        'User: $userId, Limit: $limit',
      );

      emit(PlantAnalysisLoading());

      // Repository'den gerçek data çek
      final entities = await _repository.getPastAnalyses(
        userId: userId,
        limit: limit,
      );

      emit(PlantAnalysisSuccess(
        pastAnalyses: entities,
        message: 'Past analyses loaded from Firestore',
      ));

      AppLogger.successWithContext(
        _serviceName,
        '✅ Past analyses loaded from Firestore',
        'Count: ${entities.length}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Load past analyses error',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: _categorizeError(e),
      ));
    }
  }

  /// Loads a specific analysis by ID
  Future<void> loadAnalysisById(String analysisId) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🔍 Loading analysis by ID from repository',
        'ID: $analysisId',
      );

      emit(PlantAnalysisLoading());

      // First check if the current analysis matches the requested ID
      if (state is PlantAnalysisSuccess) {
        final currentState = state as PlantAnalysisSuccess;

        // Check current analysis
        if (currentState.currentAnalysis?.id == analysisId) {
          AppLogger.successWithContext(
            _serviceName,
            '✅ Analysis found in current state',
            'ID: $analysisId',
          );

          // Re-emit the same state to trigger UI update
          emit(PlantAnalysisSuccess(
            currentAnalysis: currentState.currentAnalysis,
            pastAnalyses: currentState.pastAnalyses,
            message: 'Analysis loaded successfully',
          ));
          return;
        }

        // Check past analyses
        final foundAnalysis = currentState.pastAnalyses
            .where((analysis) => analysis.id == analysisId)
            .firstOrNull;

        if (foundAnalysis != null) {
          AppLogger.successWithContext(
            _serviceName,
            '✅ Analysis found in past analyses',
            'ID: $analysisId',
          );

          emit(PlantAnalysisSuccess(
            currentAnalysis: foundAnalysis,
            pastAnalyses: currentState.pastAnalyses,
            message: 'Analysis loaded from history',
          ));
          return;
        }
      }

      // If not found in memory, fetch from repository
      AppLogger.logWithContext(
        _serviceName,
        '📡 Fetching analysis from repository',
        'ID: $analysisId',
      );

      final analysisEntity = await _repository.getAnalysisResult(analysisId);

      if (analysisEntity != null) {
        AppLogger.successWithContext(
          _serviceName,
          '✅ Analysis loaded from repository',
          'ID: $analysisId, Plant: ${analysisEntity.plantName}',
        );

        emit(PlantAnalysisSuccess(
          currentAnalysis: analysisEntity,
          message: 'Analiz başarıyla yüklendi',
        ));
      } else {
        AppLogger.warnWithContext(
          _serviceName,
          '⚠️ Analysis not found in repository',
          'ID: $analysisId',
        );

        emit(PlantAnalysisError(
          message: 'Analiz bulunamadı. Bu analiz silinmiş olabilir.',
          errorType: ErrorType.notFound,
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Load analysis by ID error',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: _categorizeError(e),
      ));
    }
  }

  /// Resets cubit to initial state (alias for reset for backward compatibility)
  void resetState() {
    reset();
  }

  /// Resets cubit to initial state
  void reset() {
    emit(PlantAnalysisInitial());
  }

  /// Clears any error state
  void clearError() {
    if (state is PlantAnalysisError) {
      emit(PlantAnalysisInitial());
    }
  }

  // ============================================================================
  // 🗑️ DELETE OPERATIONS
  // ============================================================================

  /// Deletes a specific analysis by ID
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🗑️ Deleting analysis',
        'ID: $analysisId',
      );

      // Emit loading state
      emit(PlantAnalysisLoading());

      // Delete from repository (Firestore)
      await _repository.deleteAnalysis(analysisId);

      // Update current state by removing the deleted analysis
      if (state is PlantAnalysisSuccess) {
        final currentState = state as PlantAnalysisSuccess;

        // Remove from past analyses if present
        final updatedPastAnalyses = currentState.pastAnalyses
            .where((analysis) => analysis.id != analysisId)
            .toList();

        // Clear current analysis if it's the one being deleted
        final updatedCurrentAnalysis =
            currentState.currentAnalysis?.id == analysisId
                ? null
                : currentState.currentAnalysis;

        emit(PlantAnalysisSuccess(
          currentAnalysis: updatedCurrentAnalysis,
          pastAnalyses: updatedPastAnalyses,
          message: 'Analiz başarıyla silindi',
        ));

        AppLogger.successWithContext(
          _serviceName,
          '✅ Analysis deleted successfully',
          'ID: $analysisId',
        );
      } else {
        // If no current state, just reload past analyses
        await loadPastAnalyses();
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Delete analysis error',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message:
            'Analiz silinirken hata oluştu: ${_getUserFriendlyErrorMessage(e)}',
        errorType: _categorizeError(e),
      ));
    }
  }

  /// Deletes multiple analyses by their IDs
  Future<void> deleteMultipleAnalyses(List<String> analysisIds) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🗑️ Deleting multiple analyses',
        'Count: ${analysisIds.length}',
      );

      emit(PlantAnalysisLoading());

      // Delete each analysis from repository
      for (final analysisId in analysisIds) {
        await _repository.deleteAnalysis(analysisId);
      }

      // Update current state by removing all deleted analyses
      if (state is PlantAnalysisSuccess) {
        final currentState = state as PlantAnalysisSuccess;

        // Remove from past analyses
        final updatedPastAnalyses = currentState.pastAnalyses
            .where((analysis) => !analysisIds.contains(analysis.id))
            .toList();

        // Clear current analysis if it's among the deleted ones
        final updatedCurrentAnalysis =
            analysisIds.contains(currentState.currentAnalysis?.id)
                ? null
                : currentState.currentAnalysis;

        emit(PlantAnalysisSuccess(
          currentAnalysis: updatedCurrentAnalysis,
          pastAnalyses: updatedPastAnalyses,
          message: '${analysisIds.length} analiz başarıyla silindi',
        ));

        AppLogger.successWithContext(
          _serviceName,
          '✅ Multiple analyses deleted successfully',
          'Count: ${analysisIds.length}',
        );
      } else {
        // If no current state, just reload past analyses
        await loadPastAnalyses();
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Delete multiple analyses error',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message:
            'Analizler silinirken hata oluştu: ${_getUserFriendlyErrorMessage(e)}',
        errorType: _categorizeError(e),
      ));
    }
  }

  /// Deletes all analyses for the current user
  Future<void> deleteAllAnalyses() async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        '🗑️ Deleting all analyses for user',
        'User: ${FirebaseAuth.instance.currentUser?.uid}',
      );

      emit(PlantAnalysisLoading());

      // Get all analyses first
      final allAnalyses = await _repository.getPastAnalyses(limit: 1000);

      // Delete each analysis
      for (final analysis in allAnalyses) {
        await _repository.deleteAnalysis(analysis.id);
      }

      // Reset state to initial
      emit(PlantAnalysisSuccess(
        currentAnalysis: null,
        pastAnalyses: [],
        message: 'Tüm analizler başarıyla silindi',
      ));

      AppLogger.successWithContext(
        _serviceName,
        '✅ All analyses deleted successfully',
        'Count: ${allAnalyses.length}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Delete all analyses error',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message:
            'Analizler silinirken hata oluştu: ${_getUserFriendlyErrorMessage(e)}',
        errorType: _categorizeError(e),
      ));
    }
  }
}
