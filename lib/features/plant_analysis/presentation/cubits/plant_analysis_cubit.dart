import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/utils/validation_util.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_state.dart';

/// Plant Analysis Cubit
///
/// Manages plant analysis workflow with Clean Architecture principles.
/// Handles state management for plant analysis operations including
/// image analysis, result storage, and historical data management.
///
/// Features:
/// - Görsel analiz yapma ve kaydetme
/// - Geçmiş analizleri listeleme
/// - Progress tracking ve error handling
/// - Input validation ve logging
/// - Clean separation of concerns
class PlantAnalysisCubit extends Cubit<PlantAnalysisState> {
  // ============================================================================
  // DEPENDENCIES
  // ============================================================================

  /// Plant analysis repository dependency (domain interface)
  final PlantAnalysisRepository _repository;

  /// Service name for logging context
  static const String _serviceName = 'PlantAnalysisCubit';

  // ============================================================================
  // CONSTRUCTOR
  // ============================================================================

  /// Constructor - Dependency injection
  ///
  /// @param repository - Plant analysis repository interface
  PlantAnalysisCubit({
    required PlantAnalysisRepository repository,
  })  : _repository = repository,
        super(PlantAnalysisInitial()) {
    AppLogger.logWithContext(_serviceName, 'Cubit başlatıldı');
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  /// Görüntüyü analiz eder ve kaydeder
  ///
  /// Complete analysis workflow:
  /// 1. Input validation
  /// 2. Image preprocessing
  /// 3. AI analysis request
  /// 4. Result processing
  /// 5. Data persistence
  ///
  /// @param imageFile - Analiz edilecek görüntü dosyası
  /// @param user - Analizi yapan kullanıcı
  Future<void> analyzeAndSave(File imageFile, UserModel user) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Analiz ve kaydetme işlemi başlatılıyor',
        'User: ${user.id}',
      );

      // === INPUT VALIDATION ===
      final validationError = _validateAnalysisInput(imageFile, user);
      if (validationError != null) {
        emit(PlantAnalysisError(
          message: validationError,
          errorType: ErrorType.validation,
        ));
        return;
      }

      // === START ANALYSIS PROCESS ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Görüntü işleniyor...',
        progress: 0.1,
      ));

      // Progress: Image upload
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Görüntü yükleniyor...',
        progress: 0.3,
      ));

      // Progress: AI analysis
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'AI analizi yapılıyor...',
        progress: 0.6,
      ));

      // === PERFORM ANALYSIS ===
      final result = await _repository.analyzeAndSave(imageFile, user);

      // === HANDLE RESULT ===
      if (result != null) {
        // Progress: Complete
        emit(PlantAnalysisAnalyzing(
          progressMessage: 'Analiz tamamlanıyor...',
          progress: 0.9,
        ));

        // Success state
        emit(PlantAnalysisSuccess(
          currentAnalysis: result,
          message: 'Analiz başarıyla tamamlandı!',
        ));

        AppLogger.successWithContext(
          _serviceName,
          'Analiz ve kaydetme başarılı',
          'ID: ${result.id}',
        );
      } else {
        // Analysis failed
        emit(PlantAnalysisError(
          message: 'Analiz işlemi başarısız oldu',
          errorType: ErrorType.analysisFailure,
        ));

        AppLogger.warnWithContext(
          _serviceName,
          'Analiz sonucu null döndü',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Analiz ve kaydetme hatası',
        e,
        stackTrace,
      );

      final errorType = _categorizeError(e);
      emit(PlantAnalysisError(
        message: _getUserFriendlyErrorMessage(e),
        errorType: errorType,
        technicalDetails: e.toString(),
      ));
    }
  }

  /// Sadece analiz yapar (kaydetmez)
  ///
  /// Quick analysis için - preview mode
  ///
  /// @param imageFile - Analiz edilecek görüntü
  Future<void> analyzeOnly(File imageFile) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Sadece analiz işlemi başlatılıyor',
      );

      // === INPUT VALIDATION ===
      if (!ValidationUtil.isValidFile(imageFile)) {
        emit(PlantAnalysisError(
          message: 'Geçersiz görüntü dosyası',
          errorType: ErrorType.validation,
        ));
        return;
      }

      // === START ANALYSIS ===
      emit(PlantAnalysisAnalyzing(
        progressMessage: 'Görüntü analiz ediliyor...',
        progress: 0.2,
      ));

      // === PERFORM ANALYSIS ===
      final result = await _repository.analyzeOnly(imageFile);

      // === HANDLE RESULT ===
      if (result != null) {
        emit(PlantAnalysisSuccess(
          currentAnalysis: result,
          message: 'Hızlı analiz tamamlandı',
        ));

        AppLogger.successWithContext(
          _serviceName,
          'Sadece analiz başarılı',
          'Plant: ${result.plantName}',
        );
      } else {
        emit(PlantAnalysisError(
          message: 'Analiz işlemi başarısız',
          errorType: ErrorType.analysisFailure,
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Sadece analiz hatası',
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

  /// Kullanıcının geçmiş analizlerini yükler
  ///
  /// @param userId - Kullanıcı ID (opsiyonel)
  /// @param limit - Yüklenecek analiz sayısı
  Future<void> loadPastAnalyses({String? userId, int limit = 20}) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Geçmiş analizler yükleniyor',
        'Limit: $limit',
      );

      emit(PlantAnalysisLoading());

      final analyses = await _repository.getPastAnalyses(
        userId: userId,
        limit: limit,
      );

      if (analyses.isNotEmpty) {
        // Show the latest analysis as primary result
        emit(PlantAnalysisSuccess(
          currentAnalysis: analyses.first,
          pastAnalyses: analyses,
          message: 'Geçmiş analizler yüklendi',
        ));
      } else {
        emit(PlantAnalysisInitial());
      }

      AppLogger.successWithContext(
        _serviceName,
        'Geçmiş analizler yüklendi',
        'Count: ${analyses.length}',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Geçmiş analizler yükleme hatası',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message: 'Geçmiş analizler yüklenemedi',
        errorType: ErrorType.networkError,
        technicalDetails: e.toString(),
      ));
    }
  }

  /// Belirli analizi yükler
  ///
  /// @param analysisId - Analiz ID
  Future<void> loadAnalysisById(String analysisId) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Belirli analiz yükleniyor',
        analysisId,
      );

      emit(PlantAnalysisLoading());

      final analysis = await _repository.getAnalysisResult(analysisId);

      if (analysis != null) {
        emit(PlantAnalysisSuccess(
          currentAnalysis: analysis,
          message: 'Analiz yüklendi',
        ));
      } else {
        emit(PlantAnalysisError(
          message: 'Analiz bulunamadı',
          errorType: ErrorType.notFound,
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Belirli analiz yükleme hatası',
        e,
        stackTrace,
      );

      emit(PlantAnalysisError(
        message: 'Analiz yüklenemedi',
        errorType: ErrorType.networkError,
        technicalDetails: e.toString(),
      ));
    }
  }

  /// State'i sıfırlar
  void resetState() {
    AppLogger.logWithContext(_serviceName, 'State sıfırlanıyor');
    emit(PlantAnalysisInitial());
  }

  /// Loading state'ine geçer
  void setLoading() {
    emit(PlantAnalysisLoading());
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Input validation for analysis
  ///
  /// @param imageFile - Görüntü dosyası
  /// @param user - Kullanıcı modeli
  /// @return Hata mesajı veya null (geçerli ise)
  String? _validateAnalysisInput(File imageFile, UserModel user) {
    // File validation
    if (!ValidationUtil.isValidFile(imageFile)) {
      return 'Geçersiz görüntü dosyası';
    }

    // User validation
    if (!ValidationUtil.isValidUserId(user.id)) {
      return 'Geçersiz kullanıcı bilgisi';
    }

    // File size check (max 10MB)
    final fileSizeInBytes = imageFile.lengthSync();
    const maxSizeInBytes = 10 * 1024 * 1024; // 10MB
    if (fileSizeInBytes > maxSizeInBytes) {
      return 'Görüntü dosyası çok büyük (max 10MB)';
    }

    // File format check
    final fileName = imageFile.path.toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    final hasValidExtension =
        validExtensions.any((ext) => fileName.endsWith(ext));
    if (!hasValidExtension) {
      return 'Desteklenmeyen dosya formatı';
    }

    return null; // Validation passed
  }

  /// Error categorization for better UX
  ///
  /// @param error - Hata objesi
  /// @return ErrorType enum değeri
  ErrorType _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return ErrorType.networkError;
    } else if (errorString.contains('timeout')) {
      return ErrorType.timeout;
    } else if (errorString.contains('unauthorized') ||
        errorString.contains('permission')) {
      return ErrorType.unauthorized;
    } else if (errorString.contains('storage') ||
        errorString.contains('space')) {
      return ErrorType.storageError;
    } else if (errorString.contains('file') || errorString.contains('image')) {
      return ErrorType.fileError;
    } else if (errorString.contains('analysis') || errorString.contains('ai')) {
      return ErrorType.analysisFailure;
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return ErrorType.serverError;
    }

    return ErrorType.unknown;
  }

  /// User-friendly error messages
  ///
  /// @param error - Hata objesi
  /// @return Kullanıcı dostu hata mesajı
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorType = _categorizeError(error);

    switch (errorType) {
      case ErrorType.networkError:
        return 'İnternet bağlantısı sorunu. Lütfen bağlantınızı kontrol edin.';
      case ErrorType.timeout:
        return 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
      case ErrorType.unauthorized:
        return 'Bu işlem için yetkiniz bulunmuyor.';
      case ErrorType.storageError:
        return 'Depolama alanı sorunu. Lütfen cihazınızda yer açın.';
      case ErrorType.fileError:
        return 'Dosya işleme hatası. Başka bir görüntü deneyin.';
      case ErrorType.analysisFailure:
        return 'Analiz işlemi başarısız. Farklı bir görüntü deneyin.';
      case ErrorType.serverError:
        return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
      case ErrorType.validation:
        return 'Geçersiz veri girişi.';
      case ErrorType.notFound:
        return 'İstenen veri bulunamadı.';
      case ErrorType.unknown:
      default:
        return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  // ============================================================================
  // OVERRIDES
  // ============================================================================

  @override
  void onChange(Change<PlantAnalysisState> change) {
    super.onChange(change);
    AppLogger.logWithContext(
      _serviceName,
      'State değişimi',
      '${change.currentState.runtimeType} -> ${change.nextState.runtimeType}',
    );
  }

  @override
  Future<void> close() {
    AppLogger.logWithContext(_serviceName, 'Cubit kapatılıyor');
    return super.close();
  }
}
