// lib/features/home/cubits/home_cubit.dart
import 'dart:async';

import '../../../core/base/base_cubit.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/logger.dart';
import '../../../core/repositories/plant_analysis_repository.dart';
import '../../auth/cubits/auth_cubit.dart';
import '../../auth/cubits/auth_state.dart';
import '../../../core/models/user_model.dart';
import '../../plant_analysis/data/models/plant_analysis_model.dart';
import '../constants/home_constants.dart';
import 'home_state.dart';

/// Home screen business logic yönetimi
///
/// Bu cubit home screen'in tüm business logic'ini yönetir.
/// Clean Architecture prensiplerine uygun olarak ServiceLocator
/// ile dependency injection kullanır.
///
/// Sorumluluklar:
/// - Kullanıcı bilgilerini yükleme ve güncelleme
/// - Son analizleri getirme (şimdilik mock data)
/// - Refresh işlemleri
/// - Error handling ve logging
/// - Auth state değişikliklerini dinleme
///
/// ServiceLocator ile dependency injection kullanır.
class HomeCubit extends BaseCubit<HomeState> {
  // ============================================================================
  // DEPENDENCIES
  // ============================================================================

  /// Auth cubit - kullanıcı durumunu takip eder (nullable - lazy initialization)
  AuthCubit? _authCubit;

  // ============================================================================
  // STREAM SUBSCRIPTIONS
  // ============================================================================

  /// Auth state değişikliklerini dinleyen subscription
  StreamSubscription<AuthState>? _authSubscription;

  /// Retry timer - network hatalarında kullanılır
  Timer? _retryTimer;

  /// Retry attempt counter
  int _retryAttempts = 0;

  // ============================================================================
  // CONSTRUCTOR
  // ============================================================================

  /// Constructor - ServiceLocator kullanarak dependency injection
  HomeCubit() : super(HomeState.initial()) {
    logInfo('HomeCubit constructor başlatılıyor');

    // Dependencies'i lazy initialize et
    _initializeDependenciesLazy();

    logInfo('HomeCubit initialized');
  }

  /// Dependencies'i lazy olarak initialize eder
  void _initializeDependenciesLazy() {
    try {
      logInfo('HomeCubit lazy dependencies initialization başlıyor');

      // AuthCubit'i almaya çalış, yoksa null bırak
      if (ServiceLocator.isRegistered<AuthCubit>()) {
        _authCubit = ServiceLocator.get<AuthCubit>();
        _startAuthListener();
        logInfo('AuthCubit başarıyla alındı ve listener başlatıldı');
      } else {
        logWarning('AuthCubit henüz register olmamış, listener atlanıyor');
      }

      logInfo('HomeCubit lazy dependencies initialization tamamlandı');
    } catch (e, stackTrace) {
      AppLogger.e(
          'HomeCubit lazy dependency initialization failed', e, stackTrace);
      // Hata durumunda da devam et, AuthCubit null kalacak
    }
  }

  /// AuthCubit'i manuel olarak set eder (dışarıdan çağrılabilir)
  void setAuthCubit(AuthCubit authCubit) {
    try {
      logInfo('AuthCubit manuel olarak set ediliyor');

      // Önceki listener'ı iptal et
      _authSubscription?.cancel();

      // Yeni AuthCubit'i set et
      _authCubit = authCubit;
      _startAuthListener();

      logInfo('AuthCubit başarıyla set edildi');
    } catch (e, stackTrace) {
      AppLogger.e('AuthCubit manual set failed', e, stackTrace);
    }
  }

  /// Auth state değişikliklerini dinlemeye başlar
  void _startAuthListener() {
    if (_authCubit == null) {
      logWarning('AuthCubit null, listener başlatılamıyor');
      return;
    }

    try {
      _authSubscription = _authCubit!.stream.listen(
        _handleAuthStateChange,
        onError: (error, stackTrace) {
          AppLogger.e('Auth state listen error', error, stackTrace);
          handleError('Auth monitoring failed', error, stackTrace);
        },
      );

      // İlk durumu da kontrol et
      _handleAuthStateChange(_authCubit!.state);
      logInfo('Auth listener başarıyla başlatıldı');
    } catch (e, stackTrace) {
      AppLogger.e('Auth listener start failed', e, stackTrace);
    }
  }

  // ============================================================================
  // DISPOSAL
  // ============================================================================

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    _retryTimer?.cancel();
    logInfo('HomeCubit disposed');
    return super.close();
  }

  // ============================================================================
  // BASE CUBIT OVERRIDES
  // ============================================================================

  @override
  void emitLoadingState() {
    emit(state.copyWith(isLoading: true, clearError: true));
    logInfo('Home loading state emitted');
  }

  @override
  void emitErrorState(String errorMessage) {
    emit(state.copyWith(
      isLoading: false,
      isRefreshing: false,
      errorMessage: errorMessage,
    ));
    AppLogger.e('Home error state emitted', errorMessage);
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  /// Tüm home data'sını yeniler
  ///
  /// Kullanıcı bilgileri ve son analizleri paralel olarak yükler.
  /// Pull-to-refresh gesture'ı tarafından çağrılır.
  Future<void> refresh() async {
    try {
      logInfo('Home refresh started');
      emit(state.copyWith(isRefreshing: true, clearError: true));

      // Paralel yükleme için Future.wait kullan
      await Future.wait([
        _loadUserData(),
        _loadRecentAnalyses(),
      ]);

      emit(state.copyWith(
        isRefreshing: false,
        lastRefreshTime: DateTime.now(),
      ));

      logSuccess('Home refresh completed');
      _resetRetryAttempts();
    } catch (e, stackTrace) {
      AppLogger.e('Home refresh failed', e, stackTrace);
      emit(state.copyWith(isRefreshing: false));
      _handleRefreshError(e, stackTrace);
    }
  }

  /// İlk data yükleme işlemi
  ///
  /// Uygulama açılışında veya auth durumu değiştiğinde çağrılır.
  Future<void> loadInitialData() async {
    try {
      logInfo('Home initial data loading started');
      emitLoadingState();

      await Future.wait([
        _loadUserData(),
        _loadRecentAnalyses(),
      ]);

      emit(state.copyWith(
        isLoading: false,
        lastRefreshTime: DateTime.now(),
      ));

      logSuccess('Home initial data loaded');
      _resetRetryAttempts();
    } catch (e, stackTrace) {
      AppLogger.e('Home initial data loading failed', e, stackTrace);
      _handleLoadingError(e, stackTrace);
    }
  }

  /// User verilerini manuel olarak günceller
  ///
  /// Auth cubitteki user update'leri sonrası çağrılır.
  Future<void> updateUserData(UserModel updatedUser) async {
    try {
      logInfo('Home user data updated', updatedUser.id);
      emit(state.copyWith(user: updatedUser));
    } catch (e, stackTrace) {
      AppLogger.e('Home user data update failed', e, stackTrace);
      handleError('User data update failed', e, stackTrace);
    }
  }

  /// Analiz listesini yeniler
  ///
  /// Yeni analiz eklendikten sonra çağrılır.
  Future<void> refreshAnalyses() async {
    try {
      logInfo('Home analyses refresh started');
      await _loadRecentAnalyses();
      logSuccess('Home analyses refreshed');
    } catch (e, stackTrace) {
      AppLogger.e('Home analyses refresh failed', e, stackTrace);
      handleError('Analyses refresh failed', e, stackTrace);
    }
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Auth state değişikliklerini işler
  void _handleAuthStateChange(AuthState authState) {
    if (authState is AuthAuthenticated) {
      logInfo('Auth authenticated - updating home user data');
      updateUserData(authState.user);

      // İlk kez giriş yapıyorsa data'yı yükle
      if (!state.isDataFresh) {
        loadInitialData();
      }
    } else if (authState is AuthUnauthenticated) {
      logInfo('Auth unauthenticated - clearing home data');
      emit(state.copyWith(clearUser: true, clearAnalyses: true));
    } else if (authState is AuthError) {
      logWarning('Auth error detected in home');
      emitErrorState('Authentication error occurred');
    }
  }

  /// Kullanıcı verilerini yükler
  Future<void> _loadUserData() async {
    try {
      final currentAuthState = _authCubit?.state;
      if (currentAuthState is AuthAuthenticated) {
        emit(state.copyWith(user: currentAuthState.user));
        logInfo('User data loaded from auth state');
      } else {
        logWarning('Cannot load user data - not authenticated');
      }
    } catch (e, stackTrace) {
      AppLogger.e('User data loading failed', e, stackTrace);
      rethrow;
    }
  }

  /// Son analizleri yükler (gerçek data)
  Future<void> _loadRecentAnalyses() async {
    try {
      logInfo('Loading recent analyses');

      // Repository'den gerçek data çek
      if (ServiceLocator.isRegistered<PlantAnalysisRepository>()) {
        final repository = ServiceLocator.get<PlantAnalysisRepository>();

        // Son 10 analizi al (başarısız olanları filtreleyeceğiz)
        final entities = await repository.getPastAnalyses(limit: 10);

        // Entity'leri model'e dönüştür ve başarısız olanları filtrele
        final validModels = <PlantAnalysisModel>[];

        for (final entity in entities) {
          AppLogger.i('🔍 HomeCubit Entity debug - Plant: ${entity.plantName}');
          AppLogger.i('🔍 HomeCubit Entity ID: ${entity.id}');
          AppLogger.i(
              '🔍 HomeCubit Entity diseases: ${entity.diseases.length}');
          AppLogger.i('🔍 HomeCubit Entity isHealthy: ${entity.isHealthy}');
          AppLogger.i('🔍 HomeCubit Entity description: ${entity.description}');

          // Başarısız analiz kontrolü - Firestore seviyesinde
          final isFailedAnalysis = entity.plantName == null &&
              entity.isHealthy == null &&
              entity.diseases.isEmpty &&
              (entity.description?.contains('yapılamadı') ?? false);

          if (isFailedAnalysis) {
            AppLogger.w(
                '⚠️ Başarısız analiz tespit edildi, filtreleniyor - ID: ${entity.id}');
            continue; // Bu analizi atla
          }

          final model = PlantAnalysisModel.fromEntity(entity);

          // Model seviyesinde de kontrol et
          final isFailedModel = model.plantName == 'Analiz Edilemedi' &&
              model.isHealthy == false &&
              model.diseases.isEmpty &&
              model.description.contains('yapılamadı');

          if (isFailedModel) {
            AppLogger.w(
                '⚠️ Başarısız model tespit edildi, filtreleniyor - ID: ${model.id}');
            continue; // Bu modeli atla
          }

          AppLogger.i('🔍 HomeCubit Model debug - Plant: ${model.plantName}');
          AppLogger.i('🔍 HomeCubit Model diseases: ${model.diseases.length}');
          AppLogger.i('🔍 HomeCubit Model isHealthy: ${model.isHealthy}');
          AppLogger.i('🔍 HomeCubit Model description: ${model.description}');

          validModels.add(model);

          // Maksimum 5 geçerli analiz alsın
          if (validModels.length >= 5) break;
        }

        emit(state.copyWith(recentAnalyses: validModels));
        logInfo(
            'Recent analyses loaded: ${validModels.length} valid items from Firestore (${entities.length} total fetched)');
      } else {
        logWarning('PlantAnalysisRepository not registered');
        emit(state.copyWith(recentAnalyses: []));
      }
    } catch (e, stackTrace) {
      AppLogger.e('Recent analyses loading failed', e, stackTrace);

      // Hata durumunda boş liste emit et
      emit(state.copyWith(recentAnalyses: []));
      rethrow;
    }
  }

  /// Refresh hatalarını işler
  void _handleRefreshError(dynamic error, StackTrace stackTrace) {
    _retryAttempts++;

    if (_retryAttempts < HomeConstants.maxRetryAttempts) {
      logWarning(
          'Refresh failed, scheduling retry ${_retryAttempts}/${HomeConstants.maxRetryAttempts}');
      _scheduleRetry();
    } else {
      AppLogger.e(
          'Refresh failed after ${HomeConstants.maxRetryAttempts} attempts');
      handleError('Data refresh failed. Please try again.', error, stackTrace);
    }
  }

  /// Loading hatalarını işler
  void _handleLoadingError(dynamic error, StackTrace stackTrace) {
    _retryAttempts++;

    if (_retryAttempts < HomeConstants.maxRetryAttempts) {
      logWarning(
          'Loading failed, scheduling retry ${_retryAttempts}/${HomeConstants.maxRetryAttempts}');
      _scheduleRetry();
    } else {
      AppLogger.e(
          'Loading failed after ${HomeConstants.maxRetryAttempts} attempts');
      handleError('Data loading failed. Please check your connection.', error,
          stackTrace);
    }
  }

  /// Retry işlemini zamanlar
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(HomeConstants.retryDelay, () {
      if (!isClosed) {
        logInfo('Executing scheduled retry');
        refresh();
      }
    });
  }

  /// Retry sayacını sıfırlar
  void _resetRetryAttempts() {
    _retryAttempts = 0;
    _retryTimer?.cancel();
  }
}
