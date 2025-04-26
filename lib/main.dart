import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';
import 'package:tatarai/core/routing/app_router.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/repositories/user_repository.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';
import 'package:tatarai/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Uygulama başlangıç noktası
void main() async {
  // Tüm hataları yakalayacak bir wrapper oluştur
  runZonedGuarded(
    () async {
      // Widget ağacı başlatılmadan önce Flutter bağlamını başlat
      WidgetsFlutterBinding.ensureInitialized();

      // Ana thread'de hata yakalama
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.e(
          'Flutter hatası: ${details.exception}',
          details.exception,
          details.stack,
        );
      };

      // PlatformDispatcher hatalarını yakala
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.e('Platform hatası: $error', error, stack);
        return true;
      };

      // Bellek ayarlamaları ve performans iyileştirmesi
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
        ),
      );

      // Firebase async olarak başlat, ama bekletme (splash ekranında başlatılacak)
      _initializeFirebase().then((initialized) {
        runApp(TatarAI(firebaseInitialized: initialized));
      }).catchError((error, stack) {
        AppLogger.e('Firebase başlatma hatası', error, stack);
        // Firebase hatası olsa bile uygulamayı aç
        runApp(const TatarAI(firebaseInitialized: false));
      });
    },
    (error, stackTrace) {
      // Zone dışındaki hataları yakala
      AppLogger.e('Yakalanmamış hata: $error', error, stackTrace);
    },
  );
}

/// Firebase'i arkaplanda başlatır
Future<bool> _initializeFirebase() async {
  try {
    // Emülatör olup olmadığını kontrol et
    bool isEmulator = false;
    if (Platform.isAndroid) {
      isEmulator = await _isAndroidEmulator();
      AppLogger.i('Emülatör tespiti: $isEmulator');
    }

    // Firebase başlatma
    try {
      // Firebase 11.10.0 için güncellenmiş başlatma
      if (isEmulator) {
        await Firebase.initializeApp();
        AppLogger.i('Firebase emülatör modunda başlatıldı');
        return true;
      } else {
        // Firebase options bilgilerini logla
        AppLogger.i(
            'Firebase Options - Project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');
        AppLogger.i(
            'Firebase Options - Storage Bucket: ${DefaultFirebaseOptions.currentPlatform.storageBucket}');

        // Yeni sürüm için options'ı doğru şekilde yapılandır
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Firestore'u kontrol et
        try {
          // Özel veritabanı adı ile Firestore'u başlat
          final firestore = FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'tatarai',
          );
          AppLogger.i('Firestore başlatıldı - App Name: ${firestore.app.name}');
          AppLogger.i(
              'Firestore Project ID: ${firestore.app.options.projectId}');
          AppLogger.i('Firestore Database ID: tatarai');

          // Firestore ayarlarını kontrol et ve logla
          final settings = firestore.settings;
          AppLogger.i(
              'Firestore Settings - Host: ${settings.host}, SSL: ${settings.sslEnabled}');

          // Firestore bağlantısını test et
          try {
            AppLogger.i('Firestore test koleksiyonuna erişim deneniyor...');
            final testDoc = await firestore
                .collection('_test_connection')
                .doc('test')
                .get();
            AppLogger.i(
                'Firestore erişim testi: ${testDoc.exists ? "Belge var" : "Belge yok"}');

            // Yeni bir belge eklemeyi dene
            AppLogger.i('Firestore test belge yazma deneniyor...');
            await firestore
                .collection('_test_connection')
                .doc('test_write')
                .set({
              'timestamp': FieldValue.serverTimestamp(),
              'test': true,
              'message': 'Test bağlantısı başarılı'
            });
            AppLogger.i('Firestore test belgesi başarıyla yazıldı');
          } catch (writeError) {
            AppLogger.e('Firestore yazma hatası: $writeError', writeError);
            if (writeError.toString().contains('permission-denied')) {
              AppLogger.e(
                  'Firestore izin hatası - Güvenlik kurallarını kontrol edin',
                  writeError);
            } else if (writeError.toString().contains('unavailable')) {
              AppLogger.e(
                  'Firestore servis kullanılamıyor - Veritabanının oluşturulduğundan ve bölgenin doğru olduğundan emin olun',
                  writeError);
            }
          }
        } catch (firestoreError) {
          AppLogger.e('Firestore erişim hatası', firestoreError);
        }

        // Storage ve Auth servislerini yapılandır
        AppLogger.i('Firebase başlatıldı');
        return true;
      }
    } catch (e) {
      // Firebase başlatma hatası - detaylı loglama
      AppLogger.e('Firebase başlatma ilk denemede başarısız: $e', e);

      try {
        // Alternatif başlatma yöntemi
        await Firebase.initializeApp();
        AppLogger.i('Firebase fallback modunda başlatıldı');
        return true;
      } catch (e2) {
        AppLogger.e('Firebase fallback başlatma denemesi başarısız: $e2', e2);
        return false;
      }
    }
  } catch (e) {
    AppLogger.e('Firebase başlatma hatası: $e', e);
    return false;
  }
}

/// Android cihazın emülatör olup olmadığını kontrol et
Future<bool> _isAndroidEmulator() async {
  if (!Platform.isAndroid) {
    return false;
  }

  try {
    // Emülatör olduğunu varsayalım (device_info_plus kütüphanesi eklenebilir)
    return true; // Her zaman emülatör olarak kabul et - geliştirme amacıyla
  } catch (e) {
    AppLogger.e('Emülatör tespiti sırasında hata: $e', e);
    return true; // Hata durumunda emülatör kabul et
  }
}

/// TatarAI uygulama kök widget'ı
class TatarAI extends StatelessWidget {
  final bool firebaseInitialized;

  const TatarAI({super.key, this.firebaseInitialized = false});

  @override
  Widget build(BuildContext context) {
    // Bağımlılıklar
    final authService = AuthService();
    final userRepository = UserRepository(authService: authService);

    // Gemini servisi
    final geminiService = GeminiService();

    // Bitki analiz servisi
    final plantAnalysisService = PlantAnalysisService(
      geminiService: geminiService,
    );

    final plantAnalysisRepository = PlantAnalysisRepository(
      geminiService: geminiService,
      plantAnalysisService: plantAnalysisService,
      authService: authService,
    );

    // Auth Cubit'i
    final authCubit = AuthCubit(
      userRepository: userRepository,
      authService: authService,
    );

    // App Router
    final appRouter = AppRouter(authCubit: authCubit);

    return MultiBlocProvider(
      providers: [
        // Auth Cubit'i
        BlocProvider<AuthCubit>(create: (context) => authCubit),
        // Bitki analizi Cubit'i
        BlocProvider<PlantAnalysisCubit>(
          create: (context) =>
              PlantAnalysisCubit(repository: plantAnalysisRepository),
        ),
        // Profil Cubit'i
        BlocProvider<ProfileCubit>(
          create: (context) => ProfileCubit(
            userRepository: userRepository,
            authCubit: authCubit,
          ),
        ),
        // Diğer Cubit'ler eklenecek (payment, vb.)
      ],
      child: CupertinoApp.router(
        title: AppConstants.appName,
        theme: AppTheme.cupertinoTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.router,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}
