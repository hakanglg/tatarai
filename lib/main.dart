import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/routing/app_router.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
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
      AppLogger.e('Çevre değişkenleri yükleme hatası', e);
    }

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
    runApp(TatarAI(firebaseInitialized: firebaseInitialized));
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

/// TatarAI uygulama kök widget'ı
class TatarAI extends StatefulWidget {
  final bool firebaseInitialized;

  const TatarAI({super.key, this.firebaseInitialized = false});

  @override
  State<TatarAI> createState() => _TatarAIState();
}

class _TatarAIState extends State<TatarAI> {
  bool _firebaseManagerInitialized = false;
  String? _firebaseError;

  // FirebaseManager'i State içinde referans tutuyoruz
  final FirebaseManager _firebaseManager = FirebaseManager();

  @override
  void initState() {
    super.initState();
    _initializeFirebaseManager();
  }

  Future<void> _initializeFirebaseManager() async {
    if (!widget.firebaseInitialized) {
      setState(() {
        _firebaseError = 'Firebase başlatılamadı';
        _firebaseManagerInitialized = false;
      });
      return;
    }

    try {
      // Firebase Manager'ı arka planda başlat
      await _firebaseManager.initialize();

      // Eğer başarılıysa, UI'ı güncelle
      if (mounted) {
        setState(() {
          _firebaseManagerInitialized = true;
          _firebaseError = null;
        });
      }

      AppLogger.i('FirebaseManager başarıyla başlatıldı');
    } catch (e, stack) {
      AppLogger.e('FirebaseManager başlatma hatası', e, stack);

      if (mounted) {
        setState(() {
          _firebaseError = 'Firebase servisleri başlatılamadı: ${e.toString()}';
          _firebaseManagerInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hata varsa veya Firebase henüz başlatılmamışsa kullanılacak widget
    if (!widget.firebaseInitialized || _firebaseError != null) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_firebaseError ?? 'Uygulama başlatılıyor...'),
                if (_firebaseError != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _initializeFirebaseManager,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

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
            authCubit: context.read<AuthCubit>(),
            userRepository: userRepository,
          ),
        ),
        BlocProvider<ProfileCubit>(
          create: (context) => ProfileCubit(
            userRepository: userRepository,
            authCubit: context.read<AuthCubit>(),
          ),
        ),
        BlocProvider<HomeCubit>(
          create: (context) => HomeCubit(
            userRepository: userRepository,
            plantAnalysisRepository: plantAnalysisRepository,
          ),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.materialTheme,
          darkTheme: AppTheme.materialTheme.copyWith(
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter(
            authCubit: context.read<AuthCubit>(),
          ).router,
        ),
      ),
    );
  }
}

// RevenueCat'i başlat
Future<void> initRevenueCat() async {
  try {
    // .env dosyasından API anahtarını alabilirsek kullan, yoksa sabit değeri kullan
    // Paketlerin doğru yüklenmesi için doğru API anahtarı eklenmeli
    final revenueApiKey = AppConstants.revenueApiKey;

    // Debug modda daha fazla log göster
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(revenueApiKey));

    // Eğer kullanıcı giriş yapmışsa, RevenueCat'te de tanımla
    if (FirebaseManager().auth?.currentUser != null) {
      final uid = FirebaseManager().auth!.currentUser!.uid;
      await Purchases.logIn(uid);
      AppLogger.i('RevenueCat kullanıcı girişi yapıldı: $uid');
    }

    AppLogger.i('RevenueCat başarıyla yapılandırıldı');
  } catch (e) {
    AppLogger.e('RevenueCat yapılandırma hatası: $e');
  }
}
