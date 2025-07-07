import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/home/views/home_tab_content.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/navbar/widgets/app_bottom_navigation_bar.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/analysis/analysis_screen.dart';
import 'package:tatarai/features/settings/views/settings_screen.dart';

/// Ana ekran widget'ı - TabBar içeren ana sayfa
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // App lifecycle observer ekle
    WidgetsBinding.instance.addObserver(this);

    // NavigationManager örneğini başlat
    if (NavigationManager.instance == null) {
      NavigationManager.initialize(initialIndex: 0);
    }

    // // İsteğe bağlı güncelleme kontrolü
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkForOptionalUpdate();
    // });
  }

  @override
  void dispose() {
    // App lifecycle observer'ı kaldır
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLogger.i('📱 HomeScreen - App lifecycle değişti: $state');

    if (state == AppLifecycleState.resumed) {
      // Kullanıcı settings'den geri döndü, state'i refresh et
      AppLogger.i('🔄 HomeScreen resumed - refreshing state');
      _handleAppResume();
    }
  }

  /// App resume olduğunda çalışacak handler
  void _handleAppResume() {
    if (!mounted) return;

    try {
      // State'i refresh et
      setState(() {
        // UI'ı force update et
      });

      AppLogger.i('✅ HomeScreen resume handling tamamlandı');
    } catch (e) {
      AppLogger.e('❌ HomeScreen resume handling hatası: $e');
    }
  }

  // /// İsteğe bağlı güncelleme kontrolü yapar
  // Future<void> _checkForOptionalUpdate() async {
  //   try {
  //     await UpdateDialog.showUpdateDialogIfNeeded(context);
  //   } catch (e) {
  //     AppLogger.e('Güncelleme kontrolü sırasında hata oluştu', e);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🏠 HomeScreen build() çağrıldı');

    final navManager = NavigationManager.instance;
    if (navManager == null) {
      AppLogger.e('NavigationManager null, yeniden başlatılıyor');
      NavigationManager.initialize(initialIndex: 0);

      // NavigationManager olmadan basit bir home ekranı göster
      return Scaffold(
        appBar: AppBar(
          title: Text('app_title'.locale(context)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 64,
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                'TatarAI Yükleniyor...',
                style: AppTextTheme.headline2,
              ),
              SizedBox(height: 16),
              CupertinoActivityIndicator(),
              SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  // NavigationManager'ı tekrar başlatmayı dene
                  NavigationManager.initialize(initialIndex: 0);
                  setState(() {});
                },
                child: Text('refresh'.locale(context)),
              ),
            ],
          ),
        ),
      );
    }

    // NavigationManager'ı ChangeNotifierProvider ile sarmalayarak alt widget'lara sağla
    return ChangeNotifierProvider.value(
      value: navManager,
      child: Consumer<NavigationManager>(
        builder: (context, navManager, _) {
          return Scaffold(
            body: CupertinoTabScaffold(
              tabBar: AppBottomNavigationBar(
                currentIndex: navManager.currentIndex,
                onTabSelected: (index) {
                  AppLogger.i('Tab seçildi: $index');
                  navManager.switchToTab(index);
                },
                items: NavigationItems.getAllTabs(context),
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  // Navigator hatalarını önlemek için onGenerateRoute ekleyelim
                  onGenerateRoute: (settings) {
                    // Varsayılan rota için tab içeriğini döndür
                    if (settings.name == '/') {
                      return CupertinoPageRoute(
                        settings: settings,
                        builder: (context) =>
                            _buildScreenWrapper(index, navManager),
                      );
                    }
                    return null;
                  },
                  builder: (context) {
                    return _buildScreenWrapper(index, navManager);
                  },
                  // Navigator hatalarını önlemek için bu konfigürasyonu ekleyelim
                  navigatorObservers: [
                    _NavigatorObserver(index),
                  ],
                );
              },
              controller: navManager.tabController,
            ),
          );
        },
      ),
    );
  }

  /// Tab içeriğini hazırla
  Widget _buildScreenWrapper(int index, NavigationManager navManager) {
    switch (index) {
      case 0:
        return const HomeTabContent();
      case 1:
        return const AnalysisScreen();
      case 2:
        return const SettingsScreen();
      default:
        return Center(child: Text('page_not_found'.locale(context)));
    }
  }
}

/// Özel Navigator gözlemcisi
class _NavigatorObserver extends NavigatorObserver {
  final int tabIndex;

  _NavigatorObserver(this.tabIndex);

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    // Navigator geçmişi boşaldıysa loglayalım
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator?.canPop() == false) {
        AppLogger.i(
            'Tab $tabIndex için navigator geçmişi boşaldı, güvenlik önlemi devrede');
        // Burada herhangi bir işlem yapılabilir, şu anda sadece loglama yapıyoruz
      }
    });
  }
}
