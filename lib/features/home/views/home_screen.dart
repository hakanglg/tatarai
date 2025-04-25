import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/home/views/home_tab_content.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/plant_analysis/views/analysis_screen.dart';
import 'package:tatarai/features/profile/views/profile_screen.dart';

/// Ana ekran widget'ı - TabBar içeren ana sayfa
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Tab controller
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Tab değişikliklerini dinle
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (!mounted) return;
        final navManager = NavigationManager.instance;
        if (navManager != null) {
          navManager.switchToTab(_tabController.index);
          AppLogger.i('Tab değişti: ${_tabController.index}');
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tab'ı belirtilen indekse geçirir
  void switchToTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
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
      child: Builder(
        builder: (context) {
          final navManager = Provider.of<NavigationManager>(context);

          // Kaydırılabilir tablar için Material Widget kullan
          return Scaffold(
            body: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                const HomeTabContent(),
                const AnalysisScreen(),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: CupertinoColors.systemGrey,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3.0, color: AppColors.primary),
                  insets: const EdgeInsets.symmetric(horizontal: 30.0),
                ),
                tabs: const [
                  Tab(icon: Icon(CupertinoIcons.home), text: 'Ana Sayfa'),
                  Tab(icon: Icon(CupertinoIcons.camera), text: 'Analiz'),
                  Tab(icon: Icon(CupertinoIcons.person), text: 'Profil'),
                ],
              ),
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
        return const ProfileScreen();
      default:
        return const Center(child: Text('Sayfa bulunamadı'));
    }
  }
}
