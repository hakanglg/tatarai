import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/init/localization/language_manager.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/init/store_config.dart' as store;
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/routing/app_router.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/core/services/remote_config_service.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/features/home/cubits/home_cubit.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';
import 'package:tatarai/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:tatarai/core/utils/network_util.dart';
import 'package:tatarai/core/utils/firebase_test_utils.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tatarai/core/utils/version_util.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Uygulama başlangıç noktası
Future<void> main() async {
  // Hata yakalama
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Debug özellikleri kapatılıyor
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugPaintPointersEnabled = false;

    // Network bağlantı izlemeyi başlat (Firebase'den önce)
    NetworkUtil().startMonitoring();

    // Çevre değişkenlerini yükle (Firebase'den önce)
    try {
      await dotenv.load(fileName: ".env");
      AppLogger.i('Çevre değişkenleri yüklendi');
    } catch (e) {
      AppLogger.e('Çevre değişkenleri yükleme hatası: $e');

      // .env dosyası yoksa veya yüklenemezse kullanıcıyı bilgilendir
      if (kDebugMode) {
        print('-------------------------------------------------------');
        print('⚠️ .env DOSYASI BULUNAMADI VEYA YÜKLENEMEDİ! ⚠️');
        print(
            'Ödeme işlemleri çalışmayacak. .env dosyasını oluşturup aşağıdaki değeri eklediğinizden emin olun:');
        print('REVENUECAT_IOS_API_KEY=your_api_key_here');
        print('-------------------------------------------------------');
      }
    }

    // Localization Manager'ı başlat
    await LocalizationManager.init();
    AppLogger.i('Localization Manager başlatıldı');

    // Firebase başlatma - daha sağlam hata yakalama ile
    bool firebaseInitialized = false;
    int retryCount = 0;
    const int maxRetries = 3;

    while (!firebaseInitialized && retryCount < maxRetries) {
      try {
        retryCount++;
        AppLogger.i('Firebase başlatma denemesi $retryCount/$maxRetries');

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        AppLogger.i('Firebase Core başarıyla başlatıldı');

        // Crashlytics'i başlat
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);

        // Yakalanmayan Flutter hatalarını Crashlytics'e yönlendir
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

        // Async hataları için Firebase Crashlytics entegrasyonu
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        AppLogger.i('Crashlytics başarıyla yapılandırıldı');

        // Remote Config'i başlat (Main'de Bir Kez)
        try {
          AppLogger.i('Main: Remote Config başlatılıyor...');
          await RemoteConfigService().initialize();
          AppLogger.i('Main: Remote Config başarıyla başlatıldı');
        } catch (rcError) {
          AppLogger.e(
              'Main: Remote Config başlatma hatası (yoksayılıyor)', rcError);
          // Hata olsa bile devam ediyoruz
        }

        // Firebase testlerini çalıştır
        try {
          final testResults =
              await FirebaseTestUtils.testAllFirebaseConnections();
          if (testResults['success']) {
            AppLogger.i('Firebase bağlantı testleri başarılı: $testResults');
          } else {
            AppLogger.w(
                'Firebase bağlantı testlerinde sorunlar tespit edildi: $testResults');

            if (!testResults['firestore_tatar-ai'] &&
                testResults['firestore_default']) {
              AppLogger.w(
                  "'tatar-ai' veritabanına erişilemedi ancak varsayılan veritabanı çalışıyor. Uygulamaya devam ediliyor.");
            }
          }
        } catch (testError) {
          AppLogger.e('Firebase test hatası', testError);
        }

        firebaseInitialized = true;

        // Firestore veritabanı bilgilerini kontrol et
        try {
          // "tatarai" veritabanı testi
          final tatarDbSuccess =
              await FirebaseTestUtils.testFirestoreConnection('tatarai');
          if (tatarDbSuccess) {
            AppLogger.i("'tatarai' veritabanı bağlantısı başarılı");
          } else {
            AppLogger.w(
                "'tatarai' veritabanına bağlanılamadı, varsayılan veritabanı kullanılacak");

            // Varsayılan veritabanını dene
            final defaultDbSuccess =
                await FirebaseTestUtils.testFirestoreConnection('');
            if (defaultDbSuccess) {
              AppLogger.i("Varsayılan veritabanı bağlantısı başarılı");
            } else {
              AppLogger.e("Hiçbir Firestore veritabanına bağlanılamadı!");
            }
          }
        } catch (dbTestError) {
          AppLogger.e('Veritabanı test hatası', dbTestError);
        }

        // Firebase yöneticisini başlat
        final firebaseManager = FirebaseManager();
        // Başlatılırken hataları yakala
        await firebaseManager.initialize().catchError((e) {
          AppLogger.e('FirebaseManager başlatma hatası', e);
        });

        // Kullanıcının kimlik doğrulama durumunu kontrol et
        final _ = firebaseManager.auth;
      } catch (e, stackTrace) {
        AppLogger.e(
            'Firebase Core başlatma hatası (deneme $retryCount/$maxRetries)',
            e,
            stackTrace);

        if (retryCount >= maxRetries) {
          // Maksimum yeniden deneme sayısına ulaşıldı, devam et
          AppLogger.w(
              'Firebase başlatılamadı, uygulama sınırlı modda çalışacak');
        } else {
          // Kısa bir bekleme süresi sonra tekrar dene
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }

    // Sistem ayarları
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Hata ayıklama modunda performans optimizasyonları
    if (kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          AppLogger.d(message);
        }
      };
    }

    // RevenueCat'i başlat
    await initRevenueCat();

    // Uygulamayı başlat
    runApp(const TatarAI());
  }, (error, stack) {
    AppLogger.e('Yakalanmamış hata', error, stack);

    // Crashlytics'e yakalanmamış hataları bildir
    try {
      FirebaseCrashlytics.instance.recordError(error, stack,
          reason: 'Yakalanmamış uygulama hatası', fatal: true);
    } catch (e) {
      // Firebase başlatılamamış olabilir, sessizce geç
      AppLogger.e('Crashlytics\'e hata bildirilemedi', e);
    }
  });
}

/// RevenueCat yapılandırmasını başlatır
Future<bool> initRevenueCat() async {
  try {
    AppLogger.i('RevenueCat başlatılıyor...');

    // Log seviyesini ayarla (Debug için faydalı)
    await Purchases.setLogLevel(LogLevel.debug);
    AppLogger.i('RevenueCat: Log seviyesi ayarlandı');

    // API anahtarını al ve kontrol et
    String apiKey = '';

    if (Platform.isIOS) {
      apiKey = AppConstants.revenueiOSApiKey;
      if (apiKey.isEmpty) {
        AppLogger.e(
            'RevenueCat: iOS API anahtarı boş! .env dosyasında REVENUECAT_IOS_API_KEY tanımlanmamış.');
        _showDevelopmentModeMissingKeyMessage('iOS');
        return false;
      }
    } else if (Platform.isAndroid) {
      // Şu an için iOS anahtarını kullanıyoruz, daha sonra Android için ayrı anahtar eklenebilir
      apiKey = AppConstants.revenueiOSApiKey;
      if (apiKey.isEmpty) {
        AppLogger.e(
            'RevenueCat: Android API anahtarı boş! .env dosyasında REVENUECAT_IOS_API_KEY tanımlanmamış.');
        _showDevelopmentModeMissingKeyMessage('Android');
        return false;
      }
    } else {
      AppLogger.e(
          'RevenueCat: Desteklenmeyen platform! (${Platform.operatingSystem})');
      return false;
    }

    // RevenueCat'i yapılandır
    PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
    AppLogger.i('RevenueCat: Yapılandırma başarılı');

    // Oturum açmış kullanıcı varsa RevenueCat'e bildir
    _syncUserWithRevenueCat();

    return true;
  } catch (e) {
    AppLogger.e('RevenueCat başlatma hatası: $e');
    return false;
  }
}

/// Kullanıcıyı RevenueCat ile senkronize eder
Future<void> _syncUserWithRevenueCat() async {
  try {
    final auth = FirebaseManager().auth;
    final currentUser = auth?.currentUser;

    if (currentUser != null) {
      final uid = currentUser.uid;
      AppLogger.i(
          'RevenueCat: Kullanıcı senkronizasyonu başlatılıyor (uid: $uid)');

      try {
        await Purchases.logIn(uid);
        AppLogger.i('RevenueCat: Kullanıcı senkronizasyonu başarılı');
      } catch (e) {
        AppLogger.e('RevenueCat: Kullanıcı senkronizasyonu hatası: $e');
      }
    } else {
      AppLogger.i(
          'RevenueCat: Oturum açmış kullanıcı bulunmadığı için senkronizasyon atlanıyor');
    }
  } catch (e) {
    AppLogger.w('RevenueCat: Kullanıcı kontrolü sırasında hata: $e');
  }
}

/// Geliştirme modunda RevenueCat API anahtarı eksikliği için mesaj gösterir
void _showDevelopmentModeMissingKeyMessage(String platform) {
  if (kDebugMode) {
    print('-------------------------------------------------------');
    print('⚠️ REVENUECAT API ANAHTARI BULUNAMADI! ⚠️');
    print('$platform için RevenueCat API anahtarı bulunamadı veya boş.');
    print(
        'Ödeme işlemleri çalışmayacak. .env dosyasını oluşturup aşağıdaki değeri eklediğinizden emin olun:');
    print('REVENUECAT_IOS_API_KEY=your_api_key_here');
    print('-------------------------------------------------------');
  }
}

/// TatarAI uygulaması
class TatarAI extends StatefulWidget {
  /// Constructor
  const TatarAI({Key? key}) : super(key: key);

  @override
  State<TatarAI> createState() => _TatarAIState();
}

class _TatarAIState extends State<TatarAI> {
  final FirebaseManager _firebaseManager = FirebaseManager();
  String? _firebaseError;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseManager();
  }

  Future<void> _initializeFirebaseManager() async {
    try {
      await _firebaseManager.initialize();
    } catch (e) {
      setState(() {
        _firebaseError = e.toString();
      });
      AppLogger.e('Firebase Manager başlatma hatası', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationManager.instance.currentLocaleNotifier,
      builder: (context, locale, child) {
        // Normal Firebase başlatılmış durum için uygulama UI'ı
        // Bağımlılıklar - State içindeki _firebaseManager referansını kullan
        final authService = AuthService(firebaseManager: _firebaseManager);
        final userRepository = UserRepository(authService: authService);

        // Gemini servisi
        final geminiService = GeminiService();

        // Bitki analiz servisi
        final plantAnalysisService = PlantAnalysisService(
          geminiService: geminiService,
          firestore: _firebaseManager.firestore,
          storage: _firebaseManager.storage,
          authService: authService,
        );

        final plantAnalysisRepository = PlantAnalysisRepository(
          geminiService: geminiService,
          plantAnalysisService: plantAnalysisService,
          authService: authService,
        );

        // Önce AppLocalizations'ı yükleyip oluşturalım
        final appLocalizations = AppLocalizations(locale);

        return FutureBuilder<bool>(
          // AppLocalizations yüklenmesini bekleyelim
          future: appLocalizations.load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Yüklenirken gösterilecek ekran
              return const Material(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>(
                  create: (context) => AuthCubit(
                    userRepository: userRepository,
                    authService: authService,
                  ),
                ),
                BlocProvider<PlantAnalysisCubit>(
                  create: (context) => PlantAnalysisCubit(
                    repository: plantAnalysisRepository,
                    authCubit: BlocProvider.of<AuthCubit>(context),
                    userRepository: userRepository,
                  ),
                ),
                BlocProvider<ProfileCubit>(
                  create: (context) => ProfileCubit(
                    userRepository: userRepository,
                    authCubit: BlocProvider.of<AuthCubit>(context),
                  ),
                ),
                BlocProvider<HomeCubit>(
                  create: (context) => HomeCubit(
                    userRepository: userRepository,
                    plantAnalysisRepository: plantAnalysisRepository,
                  ),
                ),
              ],
              child: Builder(builder: (context) {
                // Buradan artık BlocProvider üzerinden AuthCubit'e erişebiliriz
                return MaterialApp.router(
                  title: AppConstants.appName,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.materialTheme,
                  darkTheme: AppTheme.materialTheme.copyWith(
                    colorScheme: AppTheme.darkColorScheme,
                    brightness: Brightness.dark,
                  ),
                  themeMode: ThemeMode.light,
                  routerConfig: AppRouter(
                    authCubit: BlocProvider.of<AuthCubit>(context),
                  ).router,
                  // Localization desteği ekle
                  locale: locale,
                  supportedLocales: LocaleConstants.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    // Cihaz dilini kontrol et
                    for (var locale in supportedLocales) {
                      if (locale.languageCode == deviceLocale?.languageCode) {
                        return locale;
                      }
                    }
                    // Desteklenmeyen dil ise varsayılan dil
                    return LocaleConstants.fallbackLocale;
                  },
                );
              }),
            );
          },
        );
      },
    );
  }
}

// Premium ekranını açmak için kullanılabilecek yardımcı fonksiyon
Future<PaywallResult?> openPremiumPaywall(BuildContext context) async {
  try {
    final paywallResult =
        await RevenueCatUI.presentPaywallIfNeeded(AppConstants.entitlementId);
    return paywallResult;
  } catch (e) {
    AppLogger.e('Premium ekranı açılırken hata oluştu: $e');
    return null;
  }
}
