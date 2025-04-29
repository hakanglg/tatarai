import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tatarai/core/utils/logger.dart';

/// Network bağlantısı ve durumunu yöneten yardımcı sınıf
class NetworkUtil {
  static final NetworkUtil _instance = NetworkUtil._internal();
  factory NetworkUtil() => _instance;
  NetworkUtil._internal();

  /// Mevcut ağ bağlantı durumu
  bool _isConnected = true;

  /// Ağ bağlantı durumu stream'i
  final _connectionStatusController = StreamController<bool>.broadcast();

  /// Connectivity servisi değişikliklerini dinleyen subscription
  StreamSubscription? _connectivitySubscription;

  /// Network bağlantı durumu stream'i
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  /// Mevcut ağ bağlantı durumu
  bool get isConnected => _isConnected;

  /// Network bağlantısını izlemeye başlar
  void startMonitoring() {
    if (_connectivitySubscription != null) return;

    AppLogger.i('Network bağlantı izleme başlatıldı');

    // İlk bağlantı durumunu kontrol et
    checkConnectivity().then((connected) {
      _isConnected = connected;
      _connectionStatusController.add(connected);

      if (!connected) {
        AppLogger.w('Network bağlantısı yok');
      }
    });

    // Bağlantı değişikliklerini dinle
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      // Eğer birden fazla sonuç varsa (Liste olarak döndüyse), ilk sonucu al
      ConnectivityResult connectivityResult;
      connectivityResult =
          result.isNotEmpty ? result.first : ConnectivityResult.none;

      final connected = connectivityResult != ConnectivityResult.none;

      // Bağlantı durumu değiştiyse
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectionStatusController.add(connected);

        if (connected) {
          AppLogger.i('Network bağlantısı kuruldu');
        } else {
          AppLogger.w('Network bağlantısı kesildi');
        }
      }
    });
  }

  /// Network bağlantı durumunu kontrol eder
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      // Eğer sonuç liste ise, herhangi biri bağlantı varsa true döndür
      return connectivityResult
          .any((result) => result != ConnectivityResult.none);

      // Tekil sonuç durumunda
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      AppLogger.e('Bağlantı kontrolü sırasında hata oluştu', e);
      return false; // Hata durumunda bağlantı yok olarak kabul et
    }
  }

  /// İzlemeyi durdurur ve kaynakları serbest bırakır
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _connectionStatusController.close();
    AppLogger.i('Network bağlantı izleme sonlandırıldı');
  }
}
