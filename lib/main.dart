import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Core imports
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/init/app_initializer.dart';
import 'package:tatarai/core/init/localization/language_manager.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/routing/app_router.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
// Feature imports
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/payment/cubits/payment_cubit.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_cubit_direct.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';
import 'package:tatarai/core/services/ai/gemini_service_interface.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tatarai/features/home/cubits/home_cubit.dart';
import 'package:tatarai/features/settings/cubits/language_cubit.dart';
import 'package:tatarai/features/settings/cubits/settings_cubit.dart';
import 'package:tatarai/core/services/paywall_manager.dart';

/// TatarAI uygulamasının ana giriş noktası
///
/// ApplicationBootstrap kullanarak temiz bir başlatma süreci sağlar.
/// Clean Architecture prensiplerine uygun modüler yapı.
Future<void> main() async {
  // Global hata yakalama mekanizması
  runZonedGuarded(() async {
    // Flutter framework başlatma
    WidgetsFlutterBinding.ensureInitialized();

    AppLogger.i('🚀 TatarAI başlatılıyor...');
    AppLogger.i(
        '📱 Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

    // AppInitializer ile core servisleri başlat
    final initializer = AppInitializer.instance;

    try {
      // Ana initialize işlemi
      AppLogger.i('🔄 AppInitializer.initializeApplication çağrılıyor...');
      final bool success = await initializer.initializeApplication();

      AppLogger.i('📊 Initialization sonucu: $success');
      AppLogger.i('📊 IsInitialized: ${initializer.isInitialized}');
      AppLogger.i('📊 LastError: ${initializer.lastError}');

      if (success) {
        AppLogger.i('✅ Application başlatma başarılı');
      } else {
        AppLogger.w(
            '⚠️ Application kısmi başlatma - bazı servisler başarısız: ${initializer.lastError}');
      }

      // Sistem ayarları
      await initializer.configureSystemSettings();

      // Debug ayarları
      initializer.configureDebugSettings();

      // 🧪 DEVELOPMENT: RevenueCat sorunları için Mock Mode
      // RevenueCat yapılandırması düzgün çalışmıyorsa aşağıdaki satırları aç:
      // if (kDebugMode) {
      //   PaywallManager.enableMockMode();
      //   AppLogger.w('🧪 DEVELOPMENT: Mock Mode aktif - RevenueCat simülasyonu');
      // }

      AppLogger.i('📊 Final IsInitialized: ${initializer.isInitialized}');
    } catch (e, stackTrace) {
      AppLogger.e('❌ Application başlatma hatası', e, stackTrace);
      AppLogger.i(
          '📊 Exception sonrası IsInitialized: ${initializer.isInitialized}');
      // Hata olsa bile uygulamayı çalıştırmaya devam et
    }

    // Uygulamayı başlat
    AppLogger.i('🏁 TatarAI uygulaması çalıştırılıyor');
    runApp(const TatarAI());
  }, (error, stackTrace) {
    // Global hata işleme - AppInitializer'a delegate et
    AppInitializer.instance.handleGlobalError(error, stackTrace);
  });
}

/// TatarAI ana widget - temiz ve sadeleştirilmiş yapı
class TatarAI extends StatefulWidget {
  const TatarAI({super.key});

  @override
  State<TatarAI> createState() => _TatarAIState();
}

class _TatarAIState extends State<TatarAI> {
  bool _forceBypass = false; // Debug için zorla bypass flag'i

  @override
  void initState() {
    super.initState();
    _waitForInitialization();
  }

  /// AppInitializer'ın tamamlanmasını bekler ve UI'yi günceller
  void _waitForInitialization() async {
    AppLogger.i('🔄 AppInitializer tamamlanması bekleniyor...');

    // Eğer zaten initialize edilmişse direkt devam et
    if (AppInitializer.instance.isInitialized) {
      AppLogger.i('✅ AppInitializer zaten hazır');
      setState(() {});
      return;
    }

    // Timeout mekanizması - maksimum 30 saniye bekle
    const timeoutDuration = Duration(seconds: 30);
    const checkInterval = Duration(milliseconds: 500);
    final startTime = DateTime.now();

    // Initialize edilene kadar bekle (polling)
    while (!AppInitializer.instance.isInitialized && mounted) {
      await Future.delayed(checkInterval);
      final elapsed = DateTime.now().difference(startTime);
      AppLogger.d(
          '⏳ AppInitializer durumu kontrol ediliyor... (Geçen süre: ${elapsed.inSeconds}s)');
      AppLogger.d(
          '📊 Current isInitialized: ${AppInitializer.instance.isInitialized}');
      AppLogger.d('📊 Current lastError: ${AppInitializer.instance.lastError}');

      // Timeout kontrolü
      if (elapsed > timeoutDuration) {
        AppLogger.w(
            '⚠️ AppInitializer timeout oluştu, hata ile devam ediliyor');
        AppLogger.w(
            '📊 Timeout sonrası isInitialized: ${AppInitializer.instance.isInitialized}');
        AppLogger.w(
            '📊 Timeout sonrası lastError: ${AppInitializer.instance.lastError}');

        // Timeout durumunda hata mesajı ile UI'yi güncelle
        if (mounted) {
          setState(() {});
        }
        return;
      }
    }

    // Initialize tamamlandıysa UI'yi güncelle
    if (mounted) {
      if (AppInitializer.instance.isInitialized) {
        AppLogger.i('🎉 AppInitializer tamamlandı, UI güncelleniyor');
      } else {
        AppLogger.w('⚠️ AppInitializer tamamlanamadı');
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 TatarAI widget build başladı');
    AppLogger.i(
        '📊 Build sırasında isInitialized: ${AppInitializer.instance.isInitialized}');

    // AppInitializer henüz hazır değilse loading göster (bypass kontrolü dahil)
    if (!AppInitializer.instance.isInitialized && !_forceBypass) {
      return _buildLoadingApp();
    }

    // Ana uygulama yapısı
    return _buildMainApp();
  }

  /// Loading ekranı
  Widget _buildLoadingApp() {
    AppLogger.i('⏳ AppInitializer henüz hazır değil, loading gösteriliyor');

    // AppInitializer status kontrolü
    final initializerStatus = AppInitializer.instance.getStatus();
    final hasError = AppInitializer.instance.lastError != null;

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.materialTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo veya ikon ekleyebiliriz
                const CircularProgressIndicator(),
                const SizedBox(height: 24),

                // Ana başlık
                Text(
                  hasError ? 'İnit sorunu' : 'Başlatılıyor...',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Durum mesajı
                Text(
                  hasError
                      ? 'Başlatma sorunu oluştu.\nLütfen bekleyin.'
                      : 'Servisler yükleniyor...',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasError ? Colors.red[600] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),

                // Hata durumunda daha detaylı bilgi
                if (hasError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      'Hata: ${AppInitializer.instance.lastError}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // Debug için zorla devam etme butonu
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    AppLogger.w('🚨 ZORLA DEVAM EDİLİYOR - Debug amaçlı');
                    // Zorla bypass flag'ini aktif et
                    _forceBypass = true;
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasError ? Colors.orange : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    hasError ? 'Devam Et' : 'Ana Sayfa',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ana uygulama yapısı
  Widget _buildMainApp() {
    AppLogger.i('🏗️ Ana uygulama yapısı oluşturuluyor');

    // Kritik servislerin hazır olup olmadığını kontrol et
    if (!AppInitializer.instance.isInitialized) {
      AppLogger.w(
          '⚠️ AppInitializer henüz tamamlanmadı ama ana uygulama başlatılıyor');
    }

    return MultiBlocProvider(
      providers: _buildBlocProviders(),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          AppLogger.i(
              '📱 MaterialApp build - Auth State: ${authState.runtimeType}');

          return ValueListenableBuilder<Locale>(
            valueListenable: LocalizationManager.instance.currentLocaleNotifier,
            builder: (context, currentLocale, child) {
              AppLogger.d(
                  '🌐 Dil değişikliği algılandı: ${currentLocale.languageCode}');

              return MaterialApp.router(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,

                // Theme configuration
                theme: AppTheme.materialTheme,
                darkTheme: AppTheme.materialTheme.copyWith(
                  colorScheme: AppTheme.darkColorScheme,
                  brightness: Brightness.dark,
                ),
                themeMode: ThemeMode.light,

                // Router configuration
                routerConfig: AppRouter(
                  authCubit: BlocProvider.of<AuthCubit>(context),
                ).router,

                // Localization configuration - ValueListenable ile dinamik
                locale: currentLocale,
                supportedLocales: LocaleConstants.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// BlocProvider'ları oluştur - ServiceLocator tabanlı
  List<BlocProvider> _buildBlocProviders() {
    AppLogger.i('🔧 BlocProvider\'lar oluşturuluyor');

    return [
      // Auth Cubit - ServiceLocator'dan
      BlocProvider<AuthCubit>(
        create: (context) {
          AppLogger.i('🏗️ AuthCubit ServiceLocator\'dan oluşturuluyor');
          try {
            final authCubit = AuthCubit();
            AppLogger.i('✅ AuthCubit başarıyla oluşturuldu');
            return authCubit;
          } catch (e, stackTrace) {
            AppLogger.e('❌ AuthCubit oluşturma hatası', e, stackTrace);
            // Hata durumunda da AuthCubit döndür (fallback mekanizması devreye girecek)
            return AuthCubit();
          }
        },
        lazy: false, // Hemen başlat
      ),

      // Payment Cubit - ServiceLocator'dan singleton instance
      BlocProvider<PaymentCubit>(
        create: (context) {
          AppLogger.i('🏗️ PaymentCubit ServiceLocator\'dan alınıyor');
          try {
            final paymentCubit = Services.paymentCubit;
            AppLogger.i('✅ PaymentCubit singleton instance başarıyla alındı');
            return paymentCubit;
          } catch (e, stackTrace) {
            AppLogger.e(
                '❌ PaymentCubit ServiceLocator\'dan alınamadı', e, stackTrace);
            // Fallback: Yeni instance oluştur
            return PaymentCubit();
          }
        },
        lazy: false, // Hemen başlat
      ),

      // Plant Analysis Cubit - ServiceLocator'dan
      BlocProvider<PlantAnalysisCubitDirect>(
        create: (context) {
          AppLogger.i(
              '🏗️ PlantAnalysisCubit ServiceLocator\'dan oluşturuluyor');
          try {
            // ServiceLocator'dan PlantAnalysisCubitDirect'i al
            final plantAnalysisCubit = Services.plantAnalysisCubitDirect;
            AppLogger.i(
                '✅ PlantAnalysisCubitDirect ServiceLocator\'dan alındı');
            return plantAnalysisCubit;
          } catch (e, stackTrace) {
            AppLogger.e('❌ ServiceLocator PlantAnalysisCubitDirect hatası', e,
                stackTrace);
            AppLogger.w(
                '⚠️ Fallback PlantAnalysisCubitDirect oluşturuluyor...');

            // Fallback: Minimal cubit döndür
            try {
              return PlantAnalysisCubitDirect(
                geminiService: Services.geminiService as GeminiServiceInterface,
                repository: Services.plantAnalysisRepository,
              );
            } catch (fallbackError) {
              AppLogger.e(
                  '❌ Fallback PlantAnalysisCubitDirect de oluşturulamadı',
                  fallbackError);
              // Son çare: Empty state cubit oluştur
              throw Exception(
                  'PlantAnalysisCubitDirect oluşturulamadı: $fallbackError');
            }
          }
        },
        lazy: true, // Gerektiğinde başlat
      ),
    ];
  }
}
