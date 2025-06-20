import 'package:flutter/cupertino.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/home/views/home_tab_content.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/analysis/analysis_screen.dart';
import 'package:tatarai/features/settings/views/settings_screen.dart';

/// Navigasyon öğeleri için varsayılan ikonlar ve başlıklar
class NavigationItems {
  /// Home tab itemları oluştur
  static BottomNavigationBarItem homeTab(BuildContext context) =>
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.house),
        activeIcon: const Icon(CupertinoIcons.house_fill),
        label: 'nav_home'.locale(context),
      );

  /// Analysis tab itemları oluştur
  static BottomNavigationBarItem analysisTab(BuildContext context) =>
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.camera),
        activeIcon: const Icon(CupertinoIcons.camera_fill),
        label: 'nav_analysis'.locale(context),
      );

  /// Settings tab itemları oluştur
  static BottomNavigationBarItem settingsTab(BuildContext context) =>
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.gear_alt),
        activeIcon: const Icon(CupertinoIcons.gear_alt_fill),
        label: 'nav_settings'.locale(context),
      );

  /// Tüm tab itemlarını içeren liste oluştur (localize)
  static List<BottomNavigationBarItem> getAllTabs(BuildContext context) => [
        homeTab(context),
        analysisTab(context),
        settingsTab(context),
      ];
}

/// Navigasyon yöneticisi sınıfı
/// Tab değişimlerini ve ekran yüklemelerini yönetir
class NavigationManager with ChangeNotifier {
  // Singleton instance
  static NavigationManager? _instance;

  /// Singleton instance getter
  static NavigationManager? get instance => _instance;

  /// Singleton instance oluşturucu
  static NavigationManager? initialize({int initialIndex = 0}) {
    try {
      if (_instance == null) {
        AppLogger.i('NavigationManager başlatılıyor (index: $initialIndex)');
        _instance = NavigationManager._internal(initialIndex: initialIndex);
        AppLogger.i('NavigationManager başarıyla başlatıldı');
      } else {
        // Eğer zaten instance varsa, sadece index'i güncelle
        AppLogger.i('NavigationManager zaten başlatılmış, index güncelleniyor');
        _instance!._tabController.index = initialIndex;
        _instance!._currentIndex = initialIndex;
        _instance!.notifyListeners();
      }
      return _instance;
    } catch (e, stack) {
      AppLogger.e('NavigationManager başlatma hatası', e, stack);
      return null;
    }
  }

  int _currentIndex = 0;
  late List<Widget> _screens;
  late final CupertinoTabController _tabController;

  /// Geçerli sekme indeksi
  int get currentIndex => _currentIndex;

  /// Tab controller
  CupertinoTabController get tabController => _tabController;

  /// Ekran listesi
  List<Widget> get screens => _screens;

  /// Private constructor for singleton pattern
  NavigationManager._internal({int initialIndex = 0}) {
    _currentIndex = initialIndex;
    _tabController = CupertinoTabController(initialIndex: initialIndex);
    _tabController.addListener(_handleTabChange);
    _initScreens();
  }

  /// Ekranları başlat
  void _initScreens() {
    try {
      _screens = [
        const HomeTabContent(),
        const AnalysisScreen(),
        const SettingsScreen(),
      ];
    } catch (e, stack) {
      AppLogger.e('Ekranları yüklerken hata', e, stack);
      _screens = [
        const SizedBox.shrink(),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ];
    }
  }

  /// Tab değişikliğini dinle
  void _handleTabChange() {
    if (_currentIndex != _tabController.index) {
      _currentIndex = _tabController.index;
      AppLogger.i('Tab değişikliği tespit edildi: $_currentIndex');
      notifyListeners();
    }
  }

  /// Belirli bir tab'a geçiş yap
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      AppLogger.i('switchToTab çağrıldı: $index (şu anki: $_currentIndex)');

      // Önce controller'ı güncelle
      _tabController.index = index;

      // Sonra current index'i güncelle
      if (_currentIndex != index) {
        _currentIndex = index;
        AppLogger.i('Tab değiştirildi: $index');
        notifyListeners();
      }
    } else {
      AppLogger.w('Geçersiz sekme indeksi: $index');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _instance = null;
    super.dispose();
  }
}
