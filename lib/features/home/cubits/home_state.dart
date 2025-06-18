import '../../../core/base/base_state.dart';
import '../../../core/models/user_model.dart';
import '../../plant_analysis/data/models/plant_analysis_model.dart';
import 'package:equatable/equatable.dart';

/// Home screen state yönetimi
///
/// Bu state sınıfı home screen'in tüm state bilgilerini tutar.
/// BaseState'den türetilmiş olarak ortak loading ve error
/// handling özelliklerini devralır.
///
/// State özellikleri:
/// - Kullanıcı bilgileri (UserModel)
/// - Son analizler listesi (PlantAnalysisModel)
/// - Loading durumu (inherited)
/// - Error mesajları (inherited)
///
/// Immutable design pattern kullanılarak state güvenliği sağlanır.
class HomeState extends BaseState {
  /// Mevcut kullanıcı bilgileri
  ///
  /// Null olabilir çünkü:
  /// - İlk yüklemede henüz kullanıcı bilgisi gelmemiş olabilir
  /// - Çıkış yapmış kullanıcı için null olur
  /// - Network hatası durumunda null kalabilir
  final UserModel? user;

  /// Son yapılan bitki analizleri listesi
  ///
  /// Maksimum 3 analiz gösterilir. Liste boş olabilir:
  /// - Kullanıcı hiç analiz yapmamışsa
  /// - Analizler henüz yüklenmemişse
  /// - Network hatası durumunda
  final List<PlantAnalysisModel> recentAnalyses;

  /// Home screen data refresh durumu
  ///
  /// Pull-to-refresh veya manuel refresh sırasında true olur.
  /// Ana loading durumundan ayrı tutulur.
  final bool isRefreshing;

  /// Son refresh zamanı
  ///
  /// Cache validation ve kullanıcı deneyimi için kullanılır.
  /// Null ise henüz hiç refresh yapılmamış demektir.
  final DateTime? lastRefreshTime;

  /// Constructor - immutable state oluşturur
  const HomeState({
    this.user,
    this.recentAnalyses = const [],
    this.isRefreshing = false,
    this.lastRefreshTime,
    super.isLoading = false,
    super.errorMessage,
    super.error,
  });

  /// Initial state factory constructor
  ///
  /// Uygulama açılışında kullanılan temiz state.
  /// Tüm değerler default/boş değerlerde başlar.
  factory HomeState.initial() => const HomeState();

  /// Loading state factory constructor
  ///
  /// İlk data loading sırasında gösterilecek state.
  factory HomeState.loading() => const HomeState(isLoading: true);

  /// State kopyalama metodu
  ///
  /// Immutable pattern gereği state güncellemek için
  /// yeni bir instance oluşturur. Sadece değişen alanlar
  /// güncellenir, diğerleri mevcut değerlerini korur.
  ///
  /// [clearUser] - kullanıcı bilgisini temizlemek için
  /// [clearError] - hata mesajını temizlemek için
  /// [clearAnalyses] - analiz listesini temizlemek için
  HomeState copyWith({
    UserModel? user,
    List<PlantAnalysisModel>? recentAnalyses,
    bool? isLoading,
    bool? isRefreshing,
    DateTime? lastRefreshTime,
    String? errorMessage,
    dynamic error,
    bool clearUser = false,
    bool clearError = false,
    bool clearAnalyses = false,
  }) {
    return HomeState(
      user: clearUser ? null : (user ?? this.user),
      recentAnalyses:
          clearAnalyses ? const [] : (recentAnalyses ?? this.recentAnalyses),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Equatable props - state karşılaştırması için
  @override
  List<Object?> get props => [
        ...super.props,
        user,
        recentAnalyses,
        isRefreshing,
        lastRefreshTime,
      ];

  /// String representation - debugging için
  @override
  String toString() {
    return 'HomeState{'
        'user: ${user?.id ?? "null"}, '
        'recentAnalysesCount: ${recentAnalyses.length}, '
        'isLoading: $isLoading, '
        'isRefreshing: $isRefreshing, '
        'hasError: ${errorMessage != null}, '
        'lastRefresh: $lastRefreshTime'
        '}';
  }

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /// Kullanıcının mevcut olup olmadığını kontrol eder
  bool get hasUser => user != null;

  /// Authenticated kullanıcı olup olmadığını kontrol eder
  /// Tüm kullanıcılar anonim olduğu için sadece user varlığını kontrol eder
  bool get isAuthenticated => user != null;

  /// Premium kullanıcı olup olmadığını kontrol eder
  bool get isPremiumUser => user?.isPremium ?? false;

  /// Son analizlerin mevcut olup olmadığını kontrol eder
  bool get hasRecentAnalyses => recentAnalyses.isNotEmpty;

  /// Herhangi bir loading durumu var mı kontrol eder
  bool get isAnyLoading => isLoading || isRefreshing;

  /// Data'nın güncel olup olmadığını kontrol eder (son 5 dakika)
  bool get isDataFresh {
    if (lastRefreshTime == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastRefreshTime!);
    return difference.inMinutes < 5;
  }

  /// Error state olup olmadığını kontrol eder
  bool get hasError => errorMessage != null;

  /// Kullanıcı analiz yapabilir mi kontrol eder
  bool get canUserAnalyze {
    if (user == null) return false;
    return user!.canAnalyze;
  }

  /// Kullanıcının kalan analiz hakkı sayısı
  int get remainingAnalysisCount {
    if (user == null) return 0;
    return user!.analysisCredits;
  }

  /// Welcome mesajı için kullanıcı adı
  String get displayName {
    if (user == null) return '';
    return user!.name;
  }
}
