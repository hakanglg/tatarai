import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/home/views/home_tab_content.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/navbar/widgets/app_bottom_navigation_bar.dart';
import 'package:tatarai/features/plant_analysis/views/analysis_screen.dart';
import 'package:tatarai/features/profile/views/profile_screen.dart';

/// Ana ekran widget'ı - TabBar içeren ana sayfa
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // NavigationManager örneğini başlat
    if (NavigationManager.instance == null) {
      NavigationManager.initialize(initialIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NavigationManager örneğini doğrudan statik instance'dan al
    var navManager = NavigationManager.instance;

    // NavigationManager örneği yoksa oluştur
    if (navManager == null) {
      NavigationManager.initialize(initialIndex: 0);
      navManager = NavigationManager.instance;

      // Hala null ise, bir hata meydana gelmiş demektir
      if (navManager == null) {
        AppLogger.e('NavigationManager oluşturulamadı');
        return const Scaffold(
          body: Center(
            child: Text(
              'NavigationManager başlatılamadı. Uygulamayı yeniden başlatın.',
            ),
          ),
        );
      }
    }

    // NavigationManager'ı ChangeNotifierProvider ile sarmalayarak alt widget'lara sağla
    return ChangeNotifierProvider.value(
      value: navManager,
      child: Consumer<NavigationManager>(
        builder: (context, navManager, _) {
          return CupertinoTabScaffold(
            tabBar: AppBottomNavigationBar(
              currentIndex: navManager.currentIndex,
              onTabSelected: (index) {
                AppLogger.i('Tab seçildi: $index');
                navManager.switchToTab(index);
              },
              items: NavigationItems.allTabs,
            ),
            tabBuilder: (context, index) {
              return CupertinoTabView(
                builder: (context) {
                  return _buildScreenWrapper(index, navManager);
                },
              );
            },
            controller: navManager.tabController,
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
        return const ProfileScreen();
      default:
        return const Center(child: Text('Sayfa bulunamadı'));
    }
  }
}
